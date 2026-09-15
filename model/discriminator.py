"""
DeblurGAN critic (discriminator) network -- training-only, never imported
by inference.py or api/app.py.

Per the paper (Kupyn et al., CVPR 2018, Section 3.2): "the architecture of
critic network is identical to the [PatchGAN] one used in [Isola et al.,
pix2pix] ... All convolutional layers except the first and last are
followed by InstanceNorm and LeakyReLU(0.2, inplace=True)."

This is a 5-layer 70x70-receptive-field PatchGAN critic (same structure as
the pix2pix/CycleGAN discriminator): it outputs a spatial map of raw,
unbounded per-patch scores rather than a single real/fake probability --
appropriate for a WGAN-style critic (no sigmoid; see losses/wgan_gp.py),
which classifies overlapping local patches of the image as real/fake
rather than the image as a whole.
"""

import torch
import torch.nn as nn


class Discriminator(nn.Module):
    """PatchGAN-style critic used for WGAN-GP adversarial training.

    Architecture (paper Section 3.2):
        Conv2d(3,   64, k=4, s=2, p=1)                          -> LeakyReLU(0.2)
        Conv2d(64,  128, k=4, s=2, p=1) -> InstanceNorm2d(128)  -> LeakyReLU(0.2)
        Conv2d(128, 256, k=4, s=2, p=1) -> InstanceNorm2d(256)  -> LeakyReLU(0.2)
        Conv2d(256, 512, k=4, s=1, p=1) -> InstanceNorm2d(512)  -> LeakyReLU(0.2)
        Conv2d(512,   1, k=4, s=1, p=1)                          (raw score map)

    No InstanceNorm on the first layer (standard PatchGAN convention -- the
    first layer sees raw pixel statistics), and no norm/activation on the
    last layer: WGAN critics output an unbounded real-valued score, not a
    bounded real/fake probability, so there is no final sigmoid.

    For a 256x256 input this produces a 30x30x1 map of overlapping-patch
    scores (each entry's receptive field covers roughly a 70x70 patch of
    the input); the WGAN-GP losses in losses/wgan_gp.py just average over
    every entry in the map.
    """

    def __init__(self):
        super().__init__()
        self.model = nn.Sequential(
            nn.Conv2d(3, 64, kernel_size=4, stride=2, padding=1),
            nn.LeakyReLU(0.2, inplace=True),
            nn.Conv2d(64, 128, kernel_size=4, stride=2, padding=1),
            nn.InstanceNorm2d(128),
            nn.LeakyReLU(0.2, inplace=True),
            nn.Conv2d(128, 256, kernel_size=4, stride=2, padding=1),
            nn.InstanceNorm2d(256),
            nn.LeakyReLU(0.2, inplace=True),
            nn.Conv2d(256, 512, kernel_size=4, stride=1, padding=1),
            nn.InstanceNorm2d(512),
            nn.LeakyReLU(0.2, inplace=True),
            nn.Conv2d(512, 1, kernel_size=4, stride=1, padding=1),
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.model(x)
