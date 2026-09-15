"""
Training script for the DeblurGAN generator
(Kupyn et al., "DeblurGAN: Blind Motion Deblurring Using
Conditional Adversarial Networks," CVPR 2018).

This version includes:
- WGAN-GP adversarial loss
- VGG19 perceptual loss
- Automatic checkpointing every epoch
- Automatic Google Drive checkpoint backup
- Resume training from the latest checkpoint
"""

import argparse
import os
import sys
import shutil

import torch
from torch import optim
from torch.utils.data import DataLoader

from data import GoProDataset
from losses import (
    PerceptualLoss,
    critic_loss,
    generator_adversarial_loss,
    gradient_penalty,
)
from model import Generator
from model.discriminator import Discriminator


# ============================================================
# TQDM
# ============================================================

try:
    from tqdm import tqdm

    _HAS_TQDM = True

except ImportError:
    _HAS_TQDM = False

    def tqdm(iterable, **_kwargs):
        return iterable


# ============================================================
# LOGGING
# ============================================================

def _log(message: str, iterator) -> None:
    """
    Print a message safely when tqdm is being used.
    """

    write = getattr(iterator, "write", None)

    if callable(write):
        write(message)
    else:
        print(message)


# ============================================================
# ARGUMENTS
# ============================================================

def parse_args(argv=None) -> argparse.Namespace:

    parser = argparse.ArgumentParser(
        description=(
            "Train the DeblurGAN generator "
            "(WGAN-GP adversarial loss + VGG perceptual loss)."
        )
    )

    parser.add_argument(
        "--data-dir",
        default=os.path.join("data", "GOPRO_Large"),
        help=(
            "Dataset root. Default: data/GOPRO_Large"
        ),
    )

    parser.add_argument(
        "--epochs",
        type=int,
        default=300,
        help="Total training epochs. Paper: 300.",
    )

    parser.add_argument(
        "--batch-size",
        type=int,
        default=1,
        help="Training batch size. Default: 1.",
    )

    parser.add_argument(
        "--lr",
        type=float,
        default=1e-4,
        help="Initial Adam learning rate. Default: 1e-4.",
    )

    parser.add_argument(
        "--n-critic",
        type=int,
        default=5,
        help="Critic update steps per generator update.",
    )

    parser.add_argument(
        "--gp-lambda",
        type=float,
        default=10.0,
        help="WGAN-GP gradient penalty coefficient.",
    )

    parser.add_argument(
        "--content-loss-weight",
        type=float,
        default=100.0,
        help="Weight of the perceptual/content loss.",
    )

    parser.add_argument(
        "--crop-size",
        type=int,
        default=256,
        help="Random training crop size.",
    )

    parser.add_argument(
        "--checkpoint-dir",
        default="checkpoints",
        help="Local directory where checkpoints are saved.",
    )

    parser.add_argument(
        "--resume",
        default=None,
        help="Path to train_state_latest.pth checkpoint.",
    )

    # IMPORTANT:
    # Save after every epoch
    parser.add_argument(
        "--save-every",
        type=int,
        default=1,
        help="Save a checkpoint every N epochs. Default: 1.",
    )

    parser.add_argument(
        "--num-workers",
        type=int,
        default=4,
        help="DataLoader worker processes.",
    )

    parser.add_argument(
        "--log-every",
        type=int,
        default=50,
        help="Print training statistics every N steps.",
    )

    return parser.parse_args(argv)


# ============================================================
# LEARNING RATE SCHEDULE
# ============================================================

def make_lr_lambda(total_epochs: int):

    """
    Keep learning rate constant for first half
    and linearly decay during second half.
    """

    constant_epochs = total_epochs // 2

    def lr_lambda(epoch: int) -> float:

        if epoch < constant_epochs:
            return 1.0

        decay_epochs = max(
            total_epochs - constant_epochs,
            1,
        )

        progress = (
            epoch - constant_epochs
        ) / decay_epochs

        return max(
            0.0,
            1.0 - progress,
        )

    return lr_lambda


# ============================================================
# CHECKPOINT SAVING
# ============================================================

def save_checkpoint(
    checkpoint_dir,
    epoch,
    generator,
    discriminator,
    opt_g,
    opt_d,
) -> None:

    # Create local checkpoint directory
    os.makedirs(
        checkpoint_dir,
        exist_ok=True,
    )

    # --------------------------------------------------------
    # Generator state
    # --------------------------------------------------------

    generator_state = generator.state_dict()

    # Epoch-specific generator checkpoint
    torch.save(
        generator_state,
        os.path.join(
            checkpoint_dir,
            f"generator_epoch{epoch}.pth",
        ),
    )

    # Latest generator checkpoint
    torch.save(
        generator_state,
        os.path.join(
            checkpoint_dir,
            "generator_latest.pth",
        ),
    )

    # --------------------------------------------------------
    # Complete training state
    # --------------------------------------------------------

    torch.save(
        {
            "epoch": epoch,

            "generator": generator_state,

            "discriminator":
                discriminator.state_dict(),

            "optimizer_g":
                opt_g.state_dict(),

            "optimizer_d":
                opt_d.state_dict(),
        },
        os.path.join(
            checkpoint_dir,
            "train_state_latest.pth",
        ),
    )

    print(
        f"[checkpoint] saved epoch {epoch} "
        f"-> {checkpoint_dir}"
    )

    # ========================================================
    # GOOGLE DRIVE BACKUP
    # ========================================================

    drive_dir = (
        "/content/drive/"
        "MyDrive/"
        "DeblurGAN_checkpoints"
    )

    # Check whether Google Drive is mounted
    if os.path.isdir("/content/drive"):

        os.makedirs(
            drive_dir,
            exist_ok=True,
        )

        # ----------------------------------------------------
        # Copy latest generator
        # ----------------------------------------------------

        shutil.copy2(
            os.path.join(
                checkpoint_dir,
                "generator_latest.pth",
            ),
            os.path.join(
                drive_dir,
                "generator_latest.pth",
            ),
        )

        # ----------------------------------------------------
        # Copy complete training state
        # ----------------------------------------------------

        shutil.copy2(
            os.path.join(
                checkpoint_dir,
                "train_state_latest.pth",
            ),
            os.path.join(
                drive_dir,
                "train_state_latest.pth",
            ),
        )

        # ----------------------------------------------------
        # Copy epoch-specific checkpoint
        # ----------------------------------------------------

        shutil.copy2(
            os.path.join(
                checkpoint_dir,
                f"generator_epoch{epoch}.pth",
            ),
            os.path.join(
                drive_dir,
                f"generator_epoch{epoch}.pth",
            ),
        )

        print(
            f"[Drive backup] epoch {epoch} saved "
            f"-> {drive_dir}"
        )

    else:

        print(
            "[Drive backup] Google Drive is not mounted. "
            "Local checkpoint is still saved."
        )


# ============================================================
# MAIN
# ============================================================

def main(argv=None) -> int:

    args = parse_args(argv)

    # --------------------------------------------------------
    # Validate crop size
    # --------------------------------------------------------

    if (
        args.crop_size <= 0
        or args.crop_size % 4 != 0
    ):

        raise ValueError(
            "--crop-size must be a positive "
            f"multiple of 4, got {args.crop_size}"
        )

    # ========================================================
    # DEVICE
    # ========================================================

    if torch.cuda.is_available():

        device = torch.device("cuda")

        print(
            "Using GPU:",
            torch.cuda.get_device_name(0),
        )

    else:

        device = torch.device("cpu")

        print(
            "WARNING: CUDA GPU not detected. "
            "Training on CPU will be extremely slow.",
            file=sys.stderr,
        )

    # ========================================================
    # DATASET
    # ========================================================

    dataset = GoProDataset(
        args.data_dir,
        split="train",
        crop_size=args.crop_size,
        augment=True,
    )

    print(
        f"Loaded {len(dataset)} training pairs "
        f"from {args.data_dir}"
    )

    # ========================================================
    # DATALOADER
    # ========================================================

    dataloader = DataLoader(
        dataset,
        batch_size=args.batch_size,
        shuffle=True,
        num_workers=args.num_workers,
        drop_last=True,
    )

    # ========================================================
    # MODELS
    # ========================================================

    generator = Generator().to(device)

    discriminator = Discriminator().to(device)

    perceptual_loss_fn = (
        PerceptualLoss().to(device)
    )

    # ========================================================
    # OPTIMIZERS
    # ========================================================

    opt_g = optim.Adam(
        generator.parameters(),
        lr=args.lr,
        betas=(0.5, 0.999),
    )

    opt_d = optim.Adam(
        discriminator.parameters(),
        lr=args.lr,
        betas=(0.5, 0.999),
    )

    # ========================================================
    # RESUME TRAINING
    # ========================================================

    start_epoch = 0

    if args.resume:

        if not os.path.isfile(args.resume):

            raise FileNotFoundError(
                "Resume checkpoint not found: "
                f"{args.resume}"
            )

        state = torch.load(
            args.resume,
            map_location=device,
        )

        generator.load_state_dict(
            state["generator"]
        )

        discriminator.load_state_dict(
            state["discriminator"]
        )

        opt_g.load_state_dict(
            state["optimizer_g"]
        )

        opt_d.load_state_dict(
            state["optimizer_d"]
        )

        start_epoch = state.get(
            "epoch",
            0,
        )

        print(
            f"Resumed from {args.resume} "
            f"at epoch {start_epoch}"
        )

    # ========================================================
    # LEARNING RATE SCHEDULERS
    # ========================================================

    lr_lambda = make_lr_lambda(
        args.epochs
    )

    scheduler_g = (
        optim.lr_scheduler.LambdaLR(
            opt_g,
            lr_lambda,
        )
    )

    scheduler_d = (
        optim.lr_scheduler.LambdaLR(
            opt_d,
            lr_lambda,
        )
    )

    # Fast-forward scheduler when resuming
    for _ in range(start_epoch):

        scheduler_g.step()

        scheduler_d.step()

    # ========================================================
    # TRAINING LOOP
    # ========================================================

    global_step = 0

    for epoch in range(
        start_epoch,
        args.epochs,
    ):

        generator.train()

        discriminator.train()

        epoch_iter = (
            tqdm(
                dataloader,
                desc=(
                    f"epoch "
                    f"{epoch + 1}/"
                    f"{args.epochs}"
                ),
            )
            if _HAS_TQDM
            else dataloader
        )

        # ====================================================
        # BATCH LOOP
        # ====================================================

        for blur, sharp in epoch_iter:

            blur = blur.to(device)

            sharp = sharp.to(device)

            # ------------------------------------------------
            # Critic update
            # ------------------------------------------------

            with torch.no_grad():

                fake = generator(blur)

            last_critic_loss = None

            for _step in range(
                args.n_critic
            ):

                opt_d.zero_grad(
                    set_to_none=True
                )

                critic_real = (
                    discriminator(sharp)
                )

                critic_fake = (
                    discriminator(fake)
                )

                gp = gradient_penalty(
                    discriminator,
                    sharp,
                    fake,
                    device,
                )

                d_loss = critic_loss(
                    critic_real,
                    critic_fake,
                    gp,
                    args.gp_lambda,
                )

                d_loss.backward()

                opt_d.step()

                last_critic_loss = (
                    d_loss.item()
                )

            # ------------------------------------------------
            # Generator update
            # ------------------------------------------------

            opt_g.zero_grad(
                set_to_none=True
            )

            fake = generator(blur)

            critic_fake = (
                discriminator(fake)
            )

            adv_loss = (
                generator_adversarial_loss(
                    critic_fake
                )
            )

            perceptual = (
                perceptual_loss_fn(
                    fake,
                    sharp,
                )
            )

            g_loss = (
                adv_loss
                + args.content_loss_weight
                * perceptual
            )

            g_loss.backward()

            opt_g.step()

            # ------------------------------------------------
            # Step counter
            # ------------------------------------------------

            global_step += 1

            # ------------------------------------------------
            # Logging
            # ------------------------------------------------

            if (
                global_step
                % args.log_every
                == 0
            ):

                message = (

                    f"epoch "
                    f"{epoch + 1}/"
                    f"{args.epochs} "

                    f"step "
                    f"{global_step} "

                    f"critic_loss="
                    f"{last_critic_loss:.4f} "

                    f"generator_loss="
                    f"{g_loss.item():.4f} "

                    f"adv_loss="
                    f"{adv_loss.item():.4f} "

                    f"perceptual_loss="
                    f"{perceptual.item():.4f}"
                )

                _log(
                    message,
                    epoch_iter,
                )

        # ====================================================
        # UPDATE LEARNING RATE
        # ====================================================

        scheduler_g.step()

        scheduler_d.step()

        # ====================================================
        # SAVE CHECKPOINT
        # ====================================================

        completed_epoch = epoch + 1

        if (
            completed_epoch
            % args.save_every
            == 0
            or completed_epoch
            == args.epochs
        ):

            save_checkpoint(
                args.checkpoint_dir,
                completed_epoch,
                generator,
                discriminator,
                opt_g,
                opt_d,
            )

    # ========================================================
    # TRAINING COMPLETE
    # ========================================================

    print(
        "Training complete."
    )

    print(
        f"Copy "
        f"{os.path.join(args.checkpoint_dir, 'generator_latest.pth')} "
        "to weights/generator.pth "
        "to use it for inference."
    )

    return 0


# ============================================================
# ENTRY POINT
# ============================================================

if __name__ == "__main__":

    raise SystemExit(
        main()
    )