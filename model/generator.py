"""
DeblurGAN generator network.

Implements the Johnson-style ResNet generator used by DeblurGAN
(O. Kupyn et al., "DeblurGAN: Blind Motion Deblurring Using Conditional
Adversarial Networks," CVPR 2018 — see Figure 3 and Section 3.2 of the paper).

This module is inference-only: no discriminator, no loss functions, no
training loop. Just the generator architecture, defined precisely as
described in the paper:

  1. c7s1-64   : Conv2d(3, 64, k=7, s=1, p=3) -> InstanceNorm2d(64) -> ReLU
  2. Downsample: Conv2d(64, 128, k=3, s=2, p=1) -> InstanceNorm2d(128) -> ReLU
  3. Downsample: Conv2d(128, 256, k=3, s=2, p=1) -> InstanceNorm2d(256) -> ReLU
  4. 9x ResidualBlock(256) with dropout
  5. Upsample   : ConvTranspose2d(256, 128, k=3, s=2, p=1, op=1) -> IN(128) -> ReLU
  6. Upsample   : ConvTranspose2d(128, 64, k=3, s=2, p=1, op=1) -> IN(64) -> ReLU
  7. c7s1-3     : Conv2d(64, 3, k=7, s=1, p=3) -> Tanh
  8. Global ("ResOut") skip connection: output = clamp(input + residual, -1, 1)

The network is fully convolutional. Downsampling happens twice with
stride-2 convolutions, so any input whose height and width are divisible
by 4 will round-trip to the same spatial size. Padding an arbitrary input
up to a multiple of 4 (and cropping back afterwards) is handled in
utils/image_utils.py, not in this module.
"""

import torch
import torch.nn as nn


class ResidualBlock(nn.Module):
    """A single residual block used in the 9-block bottleneck.

    Conv(3x3) -> InstanceNorm -> ReLU -> Dropout(0.5) -> Conv(3x3) -> InstanceNorm
    with the block's input added back (skip connection) before returning.
    """

    def __init__(self, channels: int = 256, dropout_p: float = 0.5):
        super().__init__()
        self.block = nn.Sequential(
            nn.Conv2d(channels, channels, kernel_size=3, stride=1, padding=1),
            nn.InstanceNorm2d(channels),
            nn.ReLU(inplace=True),
            nn.Dropout(dropout_p),
            nn.Conv2d(channels, channels, kernel_size=3, stride=1, padding=1),
            nn.InstanceNorm2d(channels),
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return x + self.block(x)


class Generator(nn.Module):
    """DeblurGAN Johnson-style ResNet generator with a global residual skip.

    Args:
        n_residual_blocks: number of residual blocks in the bottleneck
            (DeblurGAN paper uses 9).
        dropout_p: dropout probability inside each residual block.
    """

    def __init__(self, n_residual_blocks: int = 9, dropout_p: float = 0.5):
        super().__init__()

        # 1. Initial block: c7s1-64
        self.initial = nn.Sequential(
            nn.Conv2d(3, 64, kernel_size=7, stride=1, padding=3),
            nn.InstanceNorm2d(64),
            nn.ReLU(inplace=True),
        )

        # 2-3. Downsampling blocks
        self.down = nn.Sequential(
            nn.Conv2d(64, 128, kernel_size=3, stride=2, padding=1),
            nn.InstanceNorm2d(128),
            nn.ReLU(inplace=True),
            nn.Conv2d(128, 256, kernel_size=3, stride=2, padding=1),
            nn.InstanceNorm2d(256),
            nn.ReLU(inplace=True),
        )

        # 4. Residual blocks
        self.res_blocks = nn.Sequential(
            *[ResidualBlock(256, dropout_p) for _ in range(n_residual_blocks)]
        )

        # 5-6. Upsampling blocks
        self.up = nn.Sequential(
            nn.ConvTranspose2d(
                256, 128, kernel_size=3, stride=2, padding=1, output_padding=1
            ),
            nn.InstanceNorm2d(128),
            nn.ReLU(inplace=True),
            nn.ConvTranspose2d(
                128, 64, kernel_size=3, stride=2, padding=1, output_padding=1
            ),
            nn.InstanceNorm2d(64),
            nn.ReLU(inplace=True),
        )

        # 7. Final block: c7s1-3
        self.final = nn.Sequential(
            nn.Conv2d(64, 3, kernel_size=7, stride=1, padding=3),
            nn.Tanh(),
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        # x is expected to be normalized to [-1, 1], shape (N, 3, H, W),
        # with H and W divisible by 4.
        features = self.initial(x)
        features = self.down(features)
        features = self.res_blocks(features)
        features = self.up(features)
        residual = self.final(features)

        # 8. Global skip connection ("ResOut"): the network predicts a
        # residual correction on top of the blurred input rather than the
        # sharp image directly.
        out = x + residual
        out = torch.clamp(out, -1.0, 1.0)
        return out
