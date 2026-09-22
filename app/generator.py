"""
ResNet-based generator from DeblurGAN (Kupyn et al., 2018).
Reproduced standalone (no dependency on the original repo's argparse-based
options system) so it can be imported directly by the inference/API code.

Architecture matches models/networks.py::ResnetGenerator in
https://github.com/KupynOrest/DeblurGAN exactly, so the official
`latest_net_G.pth` checkpoint loads into it with no key mismatches.
"""
import functools

import torch
import torch.nn as nn


class ResnetBlock(nn.Module):
    def __init__(self, dim, padding_type, norm_layer, use_dropout, use_bias):
        super().__init__()

        pad_and_conv = {
            "reflect": [nn.ReflectionPad2d(1), nn.Conv2d(dim, dim, kernel_size=3, bias=use_bias)],
            "replicate": [nn.ReplicationPad2d(1), nn.Conv2d(dim, dim, kernel_size=3, bias=use_bias)],
            "zero": [nn.Conv2d(dim, dim, kernel_size=3, padding=1, bias=use_bias)],
        }
        if padding_type not in pad_and_conv:
            raise NotImplementedError(f"padding [{padding_type}] is not implemented")

        blocks = pad_and_conv[padding_type] + [norm_layer(dim), nn.ReLU(True)]
        if use_dropout:
            blocks += [nn.Dropout(0.5)]
        blocks += pad_and_conv[padding_type] + [norm_layer(dim)]

        self.conv_block = nn.Sequential(*blocks)

    def forward(self, x):
        return x + self.conv_block(x)


class ResnetGenerator(nn.Module):
    """9-residual-block generator, 2 downsampling + 2 upsampling stages."""

    def __init__(
        self,
        input_nc=3,
        output_nc=3,
        ngf=64,
        norm_layer=None,
        use_dropout=True,
        n_blocks=9,
        learn_residual=True,
        padding_type="reflect",
    ):
        super().__init__()
        assert n_blocks >= 0
        norm_layer = norm_layer or functools.partial(nn.InstanceNorm2d, affine=False, track_running_stats=True)
        self.learn_residual = learn_residual

        use_bias = (
            norm_layer.func == nn.InstanceNorm2d
            if isinstance(norm_layer, functools.partial)
            else norm_layer == nn.InstanceNorm2d
        )

        model = [
            nn.ReflectionPad2d(3),
            nn.Conv2d(input_nc, ngf, kernel_size=7, padding=0, bias=use_bias),
            norm_layer(ngf),
            nn.ReLU(True),
            nn.Conv2d(64, 128, kernel_size=3, stride=2, padding=1, bias=use_bias),
            norm_layer(128),
            nn.ReLU(True),
            nn.Conv2d(128, 256, kernel_size=3, stride=2, padding=1, bias=use_bias),
            norm_layer(256),
            nn.ReLU(True),
        ]

        for _ in range(n_blocks):
            model += [ResnetBlock(256, padding_type, norm_layer, use_dropout, use_bias)]

        model += [
            nn.ConvTranspose2d(256, 128, kernel_size=3, stride=2, padding=1, output_padding=1, bias=use_bias),
            norm_layer(128),
            nn.ReLU(True),
            nn.ConvTranspose2d(128, 64, kernel_size=3, stride=2, padding=1, output_padding=1, bias=use_bias),
            norm_layer(64),
            nn.ReLU(True),
            nn.ReflectionPad2d(3),
            nn.Conv2d(64, output_nc, kernel_size=7, padding=0),
            nn.Tanh(),
        ]

        self.model = nn.Sequential(*model)

    def forward(self, x):
        out = self.model(x)
        if self.learn_residual:
            out = torch.clamp(x + out, min=-1, max=1)
        return out
