"""
WGAN-GP adversarial loss helpers -- training-only, never imported by
inference.py or api/app.py.

The DeblurGAN paper (Kupyn et al., CVPR 2018) trains the critic with a
Wasserstein GAN + gradient penalty objective (paper Eq. 3/4), citing
Gulrajani et al., "Improved Training of Wasserstein GANs" (NeurIPS 2017)
for the gradient-penalty formulation itself -- the DeblurGAN paper does not
restate the gradient-penalty coefficient explicitly, so `train.py` exposes
it as a CLI flag (`--gp-lambda`, default 10.0) using the standard value
from the original WGAN-GP paper.
"""

import torch


def gradient_penalty(critic, real: torch.Tensor, fake: torch.Tensor, device) -> torch.Tensor:
    """WGAN-GP gradient penalty (Gulrajani et al. 2017).

    Interpolates between `real` and `fake` at a random point per sample
    (`epsilon ~ U(0, 1)`, one scalar per batch element broadcast across
    channels/height/width), runs the critic on the interpolated batch, and
    penalizes the critic for having a gradient norm (w.r.t. its input)
    that deviates from 1. This is what (approximately) enforces the
    1-Lipschitz constraint WGAN theory requires, in place of the original
    WGAN's weight clipping.

    Args:
        critic: the Discriminator (critic) module.
        real: real (sharp) images, shape (B, C, H, W).
        fake: generated (deblurred) images, shape (B, C, H, W), same shape
            as `real`.
        device: torch device to create `epsilon` on.

    Returns:
        A scalar tensor: `((||grad||_2 - 1) ** 2).mean()`.
    """
    batch_size = real.size(0)

    # One random interpolation weight per sample, broadcast over (C, H, W).
    epsilon = torch.rand(batch_size, 1, 1, 1, device=device, dtype=real.dtype)
    epsilon = epsilon.expand_as(real)

    interpolated = (epsilon * real + (1.0 - epsilon) * fake).requires_grad_(True)
    critic_interpolated = critic(interpolated)

    gradients = torch.autograd.grad(
        outputs=critic_interpolated,
        inputs=interpolated,
        grad_outputs=torch.ones_like(critic_interpolated),
        create_graph=True,
        retain_graph=True,
        only_inputs=True,
    )[0]

    gradients = gradients.reshape(batch_size, -1)
    gradient_norm = gradients.norm(2, dim=1)
    penalty = ((gradient_norm - 1.0) ** 2).mean()
    return penalty


def critic_loss(
    critic_real: torch.Tensor,
    critic_fake: torch.Tensor,
    gp: torch.Tensor,
    gp_lambda: float,
) -> torch.Tensor:
    """WGAN-GP critic loss (DeblurGAN Eq. 3/4).

    The critic wants to maximize `D(real) - D(fake)` (the Wasserstein
    distance estimate), so we minimize its negation, plus the gradient
    penalty term:

        loss = mean(D(fake)) - mean(D(real)) + gp_lambda * gradient_penalty
    """
    return critic_fake.mean() - critic_real.mean() + gp_lambda * gp


def generator_adversarial_loss(critic_fake: torch.Tensor) -> torch.Tensor:
    """WGAN generator adversarial loss (DeblurGAN Eq. 6).

    The generator wants to maximize the critic's score on its generated
    (fake) images, i.e. minimize `-mean(D(fake))`.
    """
    return -critic_fake.mean()
