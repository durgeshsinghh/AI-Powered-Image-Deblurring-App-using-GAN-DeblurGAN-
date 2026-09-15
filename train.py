"""
Training script for the DeblurGAN generator (Kupyn et al., "DeblurGAN:
Blind Motion Deblurring Using Conditional Adversarial Networks," CVPR
2018), Section 3.1 (loss) and Section 5 (training details).

This is meant to run on a GPU -- Google Colab or a cloud GPU VM, not
necessarily this laptop (see notebooks/train_on_colab.ipynb and
scripts/setup_local.ps1 / scripts/setup_local.sh). The paper reports ~6
days of training on a single Nvidia Titan X GPU for the full 300-epoch
run; CPU training would be wildly impractical for anything beyond a tiny
smoke test.

Loss (paper Eq. 5): L = adversarial_loss + content_loss_weight * perceptual_loss
  - adversarial_loss: WGAN-GP (Gulrajani et al. 2017), with the critic
    (model/discriminator.py) updated `--n-critic` steps per generator step
    (see losses/wgan_gp.py for the critic/generator loss formulas and the
    gradient penalty, paper Eq. 3/4/6).
  - perceptual_loss: VGG19 relu3_3 feature MSE (paper Eq. 7, "VGG_{3,3}"),
    see losses/perceptual_loss.py, weighted by `--content-loss-weight`
    (the paper's lambda in Eq. 5, default 100).

Optimizer: Adam (Kingma & Ba, "Adam: A Method for Stochastic
Optimization," ICLR 2015) for both the generator and the critic.

LR schedule (paper Section 5: 150 epochs at a constant LR, then 150
epochs of linear decay to 0, for 300 total): generalized here to a
constant LR for the first half of `--epochs`, then linear decay to 0 over
the second half.

Checkpointing: every `--save-every` epochs (and always after the final
epoch), this script saves:
  <checkpoint-dir>/generator_epoch<N>.pth  -- generator state_dict() only.
      This is exactly the checkpoint format inference.py / api/app.py
      already expect -- copy this file to weights/generator.pth to use it.
  <checkpoint-dir>/generator_latest.pth    -- always overwritten with the
      most recent generator weights (same format as above).
  <checkpoint-dir>/train_state_latest.pth  -- generator + discriminator +
      both optimizers + epoch number, for `--resume`.
"""

import argparse
import os
import sys

import torch
from torch import optim
from torch.utils.data import DataLoader

from data import GoProDataset
from losses import PerceptualLoss, critic_loss, generator_adversarial_loss, gradient_penalty
from model import Generator
from model.discriminator import Discriminator

try:
    from tqdm import tqdm

    _HAS_TQDM = True
except ImportError:  # pragma: no cover - tqdm is an optional convenience only
    _HAS_TQDM = False

    def tqdm(iterable, **_kwargs):
        return iterable


def _log(message: str, iterator) -> None:
    """Print `message` as a discrete line, using tqdm.write() (so it
    doesn't get clobbered by an active progress bar) when tqdm is in use,
    and plain print() otherwise.
    """
    write = getattr(iterator, "write", None)
    if callable(write):
        write(message)
    else:
        print(message)


def parse_args(argv=None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Train the DeblurGAN generator (WGAN-GP adversarial loss + VGG perceptual loss)."
    )
    parser.add_argument(
        "--data-dir",
        default=os.path.join("data", "GOPRO_Large"),
        help="Dataset root: either the standard GOPRO_Large layout, or a flat blur/sharp "
        "layout (see data/gopro_dataset.py). Default: data/GOPRO_Large.",
    )
    parser.add_argument("--epochs", type=int, default=300, help="Total training epochs (paper: 300).")
    parser.add_argument(
        "--batch-size",
        type=int,
        default=1,
        help="Paper found batch size 1 worked best; a Colab/cloud GPU can usually go higher.",
    )
    parser.add_argument("--lr", type=float, default=1e-4, help="Initial Adam learning rate (paper: 1e-4).")
    parser.add_argument(
        "--n-critic", type=int, default=5, help="Critic (discriminator) update steps per generator step."
    )
    parser.add_argument(
        "--gp-lambda",
        type=float,
        default=10.0,
        help="WGAN-GP gradient penalty coefficient (standard value from Gulrajani et al. 2017; "
        "the DeblurGAN paper does not restate this explicitly).",
    )
    parser.add_argument(
        "--content-loss-weight",
        type=float,
        default=100.0,
        help="Weight on the perceptual/content loss term (paper's lambda in Eq. 5).",
    )
    parser.add_argument("--crop-size", type=int, default=256, help="Random training crop size (must be a multiple of 4).")
    parser.add_argument("--checkpoint-dir", default="checkpoints", help="Where to write checkpoints.")
    parser.add_argument(
        "--resume", default=None, help="Path to a train_state_latest.pth-style checkpoint to resume from."
    )
    parser.add_argument("--save-every", type=int, default=10, help="Save a checkpoint every N epochs.")
    parser.add_argument("--num-workers", type=int, default=4, help="DataLoader worker processes.")
    parser.add_argument("--log-every", type=int, default=50, help="Print training stats every N generator steps.")
    return parser.parse_args(argv)


def make_lr_lambda(total_epochs: int):
    """Constant LR for the first half of training, then linear decay to 0
    over the second half (paper: 150 constant + 150 decay, for 300 total
    -- generalized here to epochs // 2 each).
    """
    constant_epochs = total_epochs // 2

    def lr_lambda(epoch: int) -> float:
        if epoch < constant_epochs:
            return 1.0
        decay_epochs = max(total_epochs - constant_epochs, 1)
        progress = (epoch - constant_epochs) / decay_epochs
        return max(0.0, 1.0 - progress)

    return lr_lambda


def save_checkpoint(checkpoint_dir, epoch, generator, discriminator, opt_g, opt_d) -> None:
    os.makedirs(checkpoint_dir, exist_ok=True)

    generator_state = generator.state_dict()
    # Plain generator state_dict -- exactly what inference.py / api/app.py load.
    torch.save(generator_state, os.path.join(checkpoint_dir, f"generator_epoch{epoch}.pth"))
    torch.save(generator_state, os.path.join(checkpoint_dir, "generator_latest.pth"))

    # Combined checkpoint for --resume: generator + discriminator + both optimizers + epoch.
    torch.save(
        {
            "epoch": epoch,
            "generator": generator_state,
            "discriminator": discriminator.state_dict(),
            "optimizer_g": opt_g.state_dict(),
            "optimizer_d": opt_d.state_dict(),
        },
        os.path.join(checkpoint_dir, "train_state_latest.pth"),
    )
    print(f"[checkpoint] saved epoch {epoch} -> {checkpoint_dir}")


def main(argv=None) -> int:
    args = parse_args(argv)

    if args.crop_size <= 0 or args.crop_size % 4 != 0:
        raise ValueError(f"--crop-size must be a positive multiple of 4, got {args.crop_size}")

    if torch.cuda.is_available():
        device = torch.device("cuda")
        print(f"Using GPU: {torch.cuda.get_device_name(0)}")
    else:
        device = torch.device("cpu")
        print(
            "WARNING: no CUDA GPU detected -- training on CPU will be "
            "impractically slow (the paper reports ~6 days on a single "
            "Titan X GPU for the full 300-epoch run). Strongly recommended: "
            "run this on Google Colab or a cloud GPU VM instead -- see "
            "notebooks/train_on_colab.ipynb and README.md.",
            file=sys.stderr,
        )

    dataset = GoProDataset(args.data_dir, split="train", crop_size=args.crop_size, augment=True)
    print(f"Loaded {len(dataset)} training pairs from {args.data_dir}")
    dataloader = DataLoader(
        dataset,
        batch_size=args.batch_size,
        shuffle=True,
        num_workers=args.num_workers,
        drop_last=True,
    )

    generator = Generator().to(device)
    discriminator = Discriminator().to(device)
    perceptual_loss_fn = PerceptualLoss().to(device)

    # Adam (Kingma & Ba, 2015); betas=(0.5, 0.999) is the standard GAN-training
    # choice (lower beta1 than Adam's usual 0.9, for adversarial training stability).
    opt_g = optim.Adam(generator.parameters(), lr=args.lr, betas=(0.5, 0.999))
    opt_d = optim.Adam(discriminator.parameters(), lr=args.lr, betas=(0.5, 0.999))

    start_epoch = 0
    if args.resume:
        if not os.path.isfile(args.resume):
            raise FileNotFoundError(f"--resume checkpoint not found: {args.resume}")
        state = torch.load(args.resume, map_location=device)
        generator.load_state_dict(state["generator"])
        discriminator.load_state_dict(state["discriminator"])
        opt_g.load_state_dict(state["optimizer_g"])
        opt_d.load_state_dict(state["optimizer_d"])
        start_epoch = state.get("epoch", 0)
        print(f"Resumed from {args.resume} at epoch {start_epoch}")

    lr_lambda = make_lr_lambda(args.epochs)
    scheduler_g = optim.lr_scheduler.LambdaLR(opt_g, lr_lambda)
    scheduler_d = optim.lr_scheduler.LambdaLR(opt_d, lr_lambda)
    # Fast-forward the (stateless, epoch-indexed) LR schedule to match a
    # resumed epoch, rather than trying to persist/restore scheduler state.
    for _ in range(start_epoch):
        scheduler_g.step()
        scheduler_d.step()

    global_step = 0
    for epoch in range(start_epoch, args.epochs):
        generator.train()
        discriminator.train()

        epoch_iter = tqdm(dataloader, desc=f"epoch {epoch + 1}/{args.epochs}") if _HAS_TQDM else dataloader

        for blur, sharp in epoch_iter:
            blur = blur.to(device)
            sharp = sharp.to(device)

            # --- critic (discriminator) update(s): n_critic steps per generator step ---
            with torch.no_grad():
                fake = generator(blur)

            last_critic_loss = None
            for _step in range(args.n_critic):
                opt_d.zero_grad(set_to_none=True)
                critic_real = discriminator(sharp)
                critic_fake = discriminator(fake)
                gp = gradient_penalty(discriminator, sharp, fake, device)
                d_loss = critic_loss(critic_real, critic_fake, gp, args.gp_lambda)
                d_loss.backward()
                opt_d.step()
                last_critic_loss = d_loss.item()

            # --- generator update ---
            opt_g.zero_grad(set_to_none=True)
            fake = generator(blur)
            critic_fake = discriminator(fake)
            adv_loss = generator_adversarial_loss(critic_fake)
            perceptual = perceptual_loss_fn(fake, sharp)
            g_loss = adv_loss + args.content_loss_weight * perceptual
            g_loss.backward()
            opt_g.step()

            global_step += 1
            if global_step % args.log_every == 0:
                message = (
                    f"epoch {epoch + 1}/{args.epochs} step {global_step} "
                    f"critic_loss={last_critic_loss:.4f} "
                    f"generator_loss={g_loss.item():.4f} "
                    f"adv_loss={adv_loss.item():.4f} "
                    f"perceptual_loss={perceptual.item():.4f}"
                )
                _log(message, epoch_iter)

        scheduler_g.step()
        scheduler_d.step()

        completed_epoch = epoch + 1
        if completed_epoch % args.save_every == 0 or completed_epoch == args.epochs:
            save_checkpoint(args.checkpoint_dir, completed_epoch, generator, discriminator, opt_g, opt_d)

    print("Training complete.")
    print(
        f"Copy {os.path.join(args.checkpoint_dir, 'generator_latest.pth')} to "
        "weights/generator.pth to use it for inference (see README.md)."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
