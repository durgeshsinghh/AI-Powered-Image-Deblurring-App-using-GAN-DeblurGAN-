"""
Pre/post-processing helpers for feeding images through the DeblurGAN
generator.

The generator (model/generator.py) downsamples twice with stride-2
convolutions, so it only round-trips cleanly on inputs whose height and
width are divisible by 4. These helpers pad an arbitrary-sized image up to
the next multiple of 4 before inference and crop the result back down to
the original size afterwards, so the model itself never has to know about
odd input sizes.

`pil_to_tensor`/`array_to_tensor` are also imported by
`data/gopro_dataset.py` during training, so the exact same [-1, 1]
normalization convention is used for both inference and training data --
there is only one place this arithmetic is written.
"""

from typing import Tuple

import numpy as np
import torch
from PIL import Image

Size = Tuple[int, int]  # (width, height), matching PIL's Image.size convention


def _next_multiple_of_4(value: int) -> int:
    remainder = value % 4
    return value if remainder == 0 else value + (4 - remainder)


def array_to_tensor(arr: np.ndarray) -> torch.Tensor:
    """Normalize an HxWx3 array with values in [0, 255] to a CxHxW float
    tensor with values in [-1, 1]. No batch dimension is added.
    """
    arr = arr.astype(np.float32)
    arr = (arr / 127.5) - 1.0  # -> [-1, 1]
    return torch.from_numpy(arr).permute(2, 0, 1).contiguous().float()


def tensor_to_array(tensor: torch.Tensor) -> np.ndarray:
    """Undo `array_to_tensor`: a CxHxW float tensor with values in [-1, 1]
    back to an HxWx3 uint8 array with values in [0, 255].
    """
    arr = tensor.detach().cpu().permute(1, 2, 0).numpy()
    arr = (arr + 1.0) * 127.5
    return np.clip(arr, 0, 255).astype(np.uint8)


def pil_to_tensor(image: Image.Image) -> torch.Tensor:
    """Convert an RGB PIL image directly to a CxHxW tensor in [-1, 1],
    with no padding or cropping applied (the caller is expected to have
    already sized the image, e.g. via a training crop). This is the shared
    normalization helper used both by `preprocess` below (for inference)
    and by `data/gopro_dataset.py` (for training pairs), so both paths
    agree on the exact same input convention the model was designed for.
    """
    return array_to_tensor(np.asarray(image.convert("RGB")))


def preprocess(pil_image: Image.Image) -> Tuple[torch.Tensor, Size, Size]:
    """Convert a PIL image into a normalized model input tensor.

    Steps:
      1. Convert to RGB (drops alpha / handles grayscale input).
      2. Reflect-pad width and height up to the next multiple of 4.
      3. Normalize pixel values from [0, 255] to [-1, 1].
      4. Return a 1x3xHxW float tensor, plus the original and padded sizes
         (both as (width, height)) so the padding can be undone later.

    Args:
        pil_image: input image, any mode, any size.

    Returns:
        (tensor, original_size, padded_size)
    """
    image = pil_image.convert("RGB")
    width, height = image.size
    original_size: Size = (width, height)

    padded_width = _next_multiple_of_4(width)
    padded_height = _next_multiple_of_4(height)
    padded_size: Size = (padded_width, padded_height)

    pad_right = padded_width - width
    pad_bottom = padded_height - height

    arr = np.asarray(image).astype(np.float32)  # H x W x 3

    if pad_right > 0 or pad_bottom > 0:
        # np.pad's reflect mode requires the pad width to be smaller than
        # the corresponding dimension; that always holds here since we're
        # padding by at most 3 pixels.
        arr = np.pad(
            arr,
            pad_width=((0, pad_bottom), (0, pad_right), (0, 0)),
            mode="reflect",
        )

    tensor = array_to_tensor(arr).unsqueeze(0)
    return tensor, original_size, padded_size


def postprocess(tensor: torch.Tensor, original_size: Size) -> Image.Image:
    """Convert a model output tensor back into a PIL image.

    Steps:
      1. Undo normalization: (x + 1) * 127.5.
      2. Clip to [0, 255] and cast to uint8.
      3. Crop back to `original_size` (undoes the padding added in
         `preprocess`).
      4. Return a PIL Image.

    Args:
        tensor: model output, shape 1x3xHxW or 3xHxW, values in [-1, 1].
        original_size: (width, height) to crop back to, as returned by
            `preprocess`.

    Returns:
        A PIL.Image.Image in RGB mode.
    """
    if tensor.dim() == 4:
        if tensor.size(0) != 1:
            raise ValueError(f"Expected batch size 1, got {tensor.size(0)}")
        tensor = tensor[0]

    arr = tensor_to_array(tensor)

    width, height = original_size
    arr = arr[:height, :width, :]

    return Image.fromarray(arr, mode="RGB")
