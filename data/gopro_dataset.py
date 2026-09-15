"""
Paired blurred/sharp dataset loader for training the DeblurGAN generator.
Training-only code: never imported by inference.py or api/app.py.

DeblurGAN (Kupyn et al., CVPR 2018) trains and evaluates on the GoPro
dataset introduced by Nah et al., "Deep Multi-scale Convolutional Neural
Network for Dynamic Scene Deblurring" (CVPR 2017). The standard public
release of that dataset (GOPRO_Large, what scripts/download_dataset.py
fetches) is laid out as:

    <root>/train/<scene_name>/blur/*.png
    <root>/train/<scene_name>/sharp/*.png
    <root>/test/<scene_name>/blur/*.png
    <root>/test/<scene_name>/sharp/*.png

with matching filenames between each scene's blur/ and sharp/ folders.
This loader tries that nested layout first, and falls back to a simpler
flat layout (<root>/blur/*.png + <root>/sharp/*.png, or
<root>/<split>/blur + <root>/<split>/sharp) for anyone pointing it at a
custom paired dataset that isn't organized by scene.
"""

import os
import random
from glob import glob
from typing import List, Tuple

import torch
from PIL import Image
from torch.utils.data import Dataset

from utils.image_utils import pil_to_tensor

_IMAGE_EXTENSIONS = (".png", ".jpg", ".jpeg", ".PNG", ".JPG", ".JPEG")


def _list_images(directory: str) -> List[str]:
    files = set()
    for ext in _IMAGE_EXTENSIONS:
        files.update(glob(os.path.join(directory, f"*{ext}")))
    return sorted(files)


def _pair_up(blur_dir: str, sharp_dir: str) -> Tuple[List[Tuple[str, str]], List[str]]:
    """Pair every blurred image in `blur_dir` with the identically-named
    file in `sharp_dir`. Returns (pairs, unmatched_blur_paths).
    """
    pairs: List[Tuple[str, str]] = []
    unmatched: List[str] = []

    for blur_path in _list_images(blur_dir):
        filename = os.path.basename(blur_path)
        sharp_path = os.path.join(sharp_dir, filename)
        if os.path.isfile(sharp_path):
            pairs.append((blur_path, sharp_path))
        else:
            unmatched.append(blur_path)

    return pairs, unmatched


def _find_pairs(root_dir: str, split: str) -> List[Tuple[str, str]]:
    """Find (blur_path, sharp_path) pairs, trying the standard GOPRO_Large
    nested-scene layout first, then falling back to a flat layout.

    Raises FileNotFoundError if no recognizable layout is found at all, or
    RuntimeError (listing the first few offending files) if blur/sharp
    filenames don't line up -- callers should not silently train on a
    partially-mismatched dataset.
    """
    split_dir = os.path.join(root_dir, split)

    # 1. Standard GOPRO_Large layout: <root>/<split>/<scene>/blur, .../sharp
    scene_dirs = sorted(
        d
        for d in glob(os.path.join(split_dir, "*"))
        if os.path.isdir(os.path.join(d, "blur")) and os.path.isdir(os.path.join(d, "sharp"))
    )

    pairs: List[Tuple[str, str]] = []
    unmatched: List[str] = []

    if scene_dirs:
        for scene_dir in scene_dirs:
            scene_pairs, scene_unmatched = _pair_up(
                os.path.join(scene_dir, "blur"), os.path.join(scene_dir, "sharp")
            )
            pairs.extend(scene_pairs)
            unmatched.extend(scene_unmatched)
    else:
        # 2. Fallback flat layout: <root>/<split>/blur + <root>/<split>/sharp,
        #    or (if that doesn't exist either) <root>/blur + <root>/sharp.
        if os.path.isdir(os.path.join(split_dir, "blur")) and os.path.isdir(os.path.join(split_dir, "sharp")):
            flat_root = split_dir
        else:
            flat_root = root_dir

        blur_dir = os.path.join(flat_root, "blur")
        sharp_dir = os.path.join(flat_root, "sharp")

        if not (os.path.isdir(blur_dir) and os.path.isdir(sharp_dir)):
            raise FileNotFoundError(
                f"Could not find a paired dataset at {root_dir!r} for split {split!r}. "
                f"Expected either the standard GOPRO_Large layout "
                f"({split_dir}/<scene>/blur + <scene>/sharp), or a flat layout "
                f"({blur_dir} + {sharp_dir}). "
                "See scripts/download_dataset.py and README.md for how to fetch/place the dataset."
            )

        pairs, unmatched = _pair_up(blur_dir, sharp_dir)

    if not pairs and not unmatched:
        raise RuntimeError(
            f"No blurred images found under {root_dir!r} for split {split!r}."
        )

    if unmatched:
        preview = ", ".join(unmatched[:5])
        raise RuntimeError(
            f"{len(unmatched)} blurred image(s) under {root_dir!r} (split={split!r}) have no "
            f"matching file with the same name under the sibling 'sharp' folder -- refusing to "
            f"silently drop them. First few: {preview}"
        )

    return pairs


class GoProDataset(Dataset):
    """Paired (blurred, sharp) image dataset for training the generator.

    Args:
        root_dir: dataset root (e.g. "data/GOPRO_Large").
        split: "train" or "test" (or any other subfolder name present under
            `root_dir`) -- selects which split to read.
        crop_size: for split == "train", a random `crop_size x crop_size`
            crop is taken from the pair (the same offset for both the blur
            and sharp image, so they stay aligned). Must be a multiple of 4
            (the generator's downsampling requirement). For any other
            split, the image is center-cropped down to the nearest
            multiple of 4 instead (deterministic, no augmentation, for
            repeatable evaluation).
        augment: for split == "train", additionally apply a random
            horizontal flip -- the same flip to both images in the pair.

    Returns from `__getitem__`: `(blur_tensor, sharp_tensor)`, each a
    `3xHxW` float tensor normalized to [-1, 1] via
    `utils.image_utils.pil_to_tensor` (the same normalization convention
    used at inference time).
    """

    def __init__(self, root_dir: str, split: str = "train", crop_size: int = 256, augment: bool = True):
        if crop_size <= 0 or crop_size % 4 != 0:
            raise ValueError(f"crop_size must be a positive multiple of 4, got {crop_size}")

        self.root_dir = root_dir
        self.split = split
        self.crop_size = crop_size
        self.augment = augment
        self.pairs = _find_pairs(root_dir, split)

    def __len__(self) -> int:
        return len(self.pairs)

    def __getitem__(self, index: int) -> Tuple[torch.Tensor, torch.Tensor]:
        blur_path, sharp_path = self.pairs[index]
        blur_image = Image.open(blur_path).convert("RGB")
        sharp_image = Image.open(sharp_path).convert("RGB")

        if blur_image.size != sharp_image.size:
            raise ValueError(
                f"Size mismatch between paired images: {blur_path} is {blur_image.size} "
                f"but {sharp_path} is {sharp_image.size}."
            )

        if self.split == "train":
            blur_image, sharp_image = self._random_crop_pair(blur_image, sharp_image, self.crop_size)
            if self.augment and random.random() < 0.5:
                blur_image = blur_image.transpose(Image.FLIP_LEFT_RIGHT)
                sharp_image = sharp_image.transpose(Image.FLIP_LEFT_RIGHT)
        else:
            blur_image = self._center_crop_to_multiple_of_4(blur_image)
            sharp_image = self._center_crop_to_multiple_of_4(sharp_image)

        blur_tensor = pil_to_tensor(blur_image)
        sharp_tensor = pil_to_tensor(sharp_image)
        return blur_tensor, sharp_tensor

    @staticmethod
    def _random_crop_pair(
        blur_image: Image.Image, sharp_image: Image.Image, crop_size: int
    ) -> Tuple[Image.Image, Image.Image]:
        width, height = blur_image.size

        if width < crop_size or height < crop_size:
            # Rare (an image smaller than the crop size): upscale both
            # images together up to at least crop_size before cropping,
            # rather than failing outright.
            scale = max(crop_size / width, crop_size / height)
            new_size = (max(crop_size, round(width * scale)), max(crop_size, round(height * scale)))
            blur_image = blur_image.resize(new_size, Image.BICUBIC)
            sharp_image = sharp_image.resize(new_size, Image.BICUBIC)
            width, height = blur_image.size

        max_x = width - crop_size
        max_y = height - crop_size
        # Use the SAME random offset for both images so the pair stays aligned.
        x = random.randint(0, max_x)
        y = random.randint(0, max_y)

        box = (x, y, x + crop_size, y + crop_size)
        return blur_image.crop(box), sharp_image.crop(box)

    @staticmethod
    def _center_crop_to_multiple_of_4(image: Image.Image) -> Image.Image:
        width, height = image.size
        new_width = (width // 4) * 4
        new_height = (height // 4) * 4
        if new_width == 0 or new_height == 0 or (new_width == width and new_height == height):
            return image
        left = (width - new_width) // 2
        top = (height - new_height) // 2
        return image.crop((left, top, left + new_width, top + new_height))
