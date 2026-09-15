"""
VGG19-based perceptual (content) loss -- training-only, never imported by
inference.py or api/app.py.

Per the paper (Kupyn et al., CVPR 2018), Eq. 7 defines the content loss as
an L2 distance between VGG19 feature activations of the generated and
target sharp image, evaluated at a particular VGG layer denoted
`VGG_{3,3}` -- i.e. the activation produced by the 3rd convolution in the
3rd block, after its ReLU (conv3_3 -> relu3_3). In torchvision's
`vgg19(...).features` Sequential, that is exactly layer indices 0-15
inclusive (`features[:16]`):

    0 Conv(3,64)    1 ReLU
    2 Conv(64,64)   3 ReLU
    4 MaxPool
    5 Conv(64,128)  6 ReLU
    7 Conv(128,128) 8 ReLU
    9 MaxPool
    10 Conv(128,256) 11 ReLU   (conv3_1, relu3_1)
    12 Conv(256,256) 13 ReLU   (conv3_2, relu3_2)
    14 Conv(256,256) 15 ReLU   (conv3_3, relu3_3)  <-- features[:16] stops here
"""

import torch
import torch.nn as nn
from torchvision.models import vgg19, VGG19_Weights

# ImageNet normalization stats that the pretrained VGG19 was trained with.
_IMAGENET_MEAN = torch.tensor([0.485, 0.456, 0.406]).view(1, 3, 1, 1)
_IMAGENET_STD = torch.tensor([0.229, 0.224, 0.225]).view(1, 3, 1, 1)


class PerceptualLoss(nn.Module):
    """VGG19 relu3_3 feature-space MSE loss (DeblurGAN paper Eq. 7, "VGG_{3,3}").

    Inputs are expected in this project's [-1, 1] tensor convention (the
    same convention `utils/image_utils.py` and the `Generator` use); this
    module internally converts to [0, 1] and then to ImageNet
    mean/std-normalized statistics before feeding VGG19, since that is the
    convention the pretrained VGG19 weights expect.

    The VGG19 backbone is frozen (`requires_grad_(False)`) and kept in
    eval mode -- it is only ever used as a fixed feature extractor, never
    trained itself.
    """

    def __init__(self):
        super().__init__()
        vgg_features = vgg19(weights=VGG19_Weights.DEFAULT).features[:16]
        vgg_features.requires_grad_(False)
        vgg_features.eval()

        self.vgg = vgg_features
        self.criterion = nn.MSELoss()
        self.register_buffer("mean", _IMAGENET_MEAN)
        self.register_buffer("std", _IMAGENET_STD)

    def train(self, mode: bool = True) -> "PerceptualLoss":
        # Always keep the frozen VGG backbone in eval mode, regardless of
        # whether the surrounding training loop calls .train()/.eval() on
        # this module (e.g. if it's naively swept up in a
        # `model.train()`-everything call). It has no parameters that
        # should ever be updated, and no BatchNorm/Dropout state that
        # should ever track running stats.
        return super().train(False)

    def _to_vgg_input(self, x: torch.Tensor) -> torch.Tensor:
        # [-1, 1] -> [0, 1] -> ImageNet-normalized.
        x = (x + 1.0) / 2.0
        return (x - self.mean) / self.std

    def forward(self, generated: torch.Tensor, target: torch.Tensor) -> torch.Tensor:
        generated_features = self.vgg(self._to_vgg_input(generated))
        with torch.no_grad():
            target_features = self.vgg(self._to_vgg_input(target))
        return self.criterion(generated_features, target_features)
