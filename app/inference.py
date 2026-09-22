"""
Inference wrapper around the DeblurGAN generator.

Loads the official pretrained generator weights and exposes a single
`deblur(image: PIL.Image) -> PIL.Image` call. Handles arbitrary input
resolutions by padding to a multiple of 4 (required by the network's two
stride-2 down/up-sampling stages) and cropping back afterwards, instead of
the original repo's test-time behaviour of resizing + random-cropping to
256x256.
"""
import io

import numpy as np
import torch
from PIL import Image

from .generator import ResnetGenerator

MEAN = 0.5
STD = 0.5


class DeblurModel:
    def __init__(self, weights_path: str, device: str = "cpu", max_dim: int = 0):
        """max_dim: if > 0, downscale the longer side of any input image to at
        most this many pixels before running inference. The generator's peak
        RAM scales roughly with H*W, so this bounds memory use on
        memory-constrained hosts (e.g. Render's free 512MB tier)."""
        self.device = torch.device(device)
        self.max_dim = max_dim
        self.net = ResnetGenerator(learn_residual=True)
        state_dict = torch.load(weights_path, map_location=self.device)
        self.net.load_state_dict(state_dict)
        self.net.to(self.device)
        self.net.eval()

    @staticmethod
    def _pad_to_multiple(arr: np.ndarray, multiple: int = 4):
        h, w = arr.shape[:2]
        pad_h = (-h) % multiple
        pad_w = (-w) % multiple
        if pad_h or pad_w:
            arr = np.pad(arr, ((0, pad_h), (0, pad_w), (0, 0)), mode="reflect")
        return arr, h, w

    def _to_tensor(self, image: Image.Image) -> torch.Tensor:
        arr = np.asarray(image.convert("RGB"), dtype=np.float32) / 255.0
        arr, orig_h, orig_w = self._pad_to_multiple(arr)
        arr = (arr - MEAN) / STD  # -> [-1, 1]
        tensor = torch.from_numpy(arr.transpose(2, 0, 1)).unsqueeze(0).float()
        return tensor.to(self.device), orig_h, orig_w

    @staticmethod
    def _to_image(tensor: torch.Tensor, orig_h: int, orig_w: int) -> Image.Image:
        arr = tensor[0].detach().cpu().numpy()
        arr = (np.transpose(arr, (1, 2, 0)) + 1) / 2.0 * 255.0
        arr = np.clip(arr, 0, 255).astype(np.uint8)
        arr = arr[:orig_h, :orig_w]  # crop off the reflect-padding
        return Image.fromarray(arr)

    def _cap_size(self, image: Image.Image) -> Image.Image:
        if not self.max_dim:
            return image
        w, h = image.size
        longest = max(w, h)
        if longest <= self.max_dim:
            return image
        scale = self.max_dim / longest
        return image.resize((max(1, int(w * scale)), max(1, int(h * scale))), Image.BICUBIC)

    @torch.no_grad()
    def deblur(self, image: Image.Image) -> Image.Image:
        image = self._cap_size(image)
        tensor, orig_h, orig_w = self._to_tensor(image)
        output = self.net(tensor)
        return self._to_image(output, orig_h, orig_w)

    def deblur_bytes(self, data: bytes, fmt: str = "PNG") -> bytes:
        image = Image.open(io.BytesIO(data))
        result = self.deblur(image)
        buf = io.BytesIO()
        result.save(buf, format=fmt)
        return buf.getvalue()
