"""
CLI entry point for running the DeblurGAN generator on a single image.

Usage:
    python inference.py --input path/to/blurred.jpg --output path/to/result.png \
        --checkpoint weights/generator.pth

If the checkpoint file does not exist, the model runs with randomly
initialized weights and prints a warning -- this keeps the pipeline
demonstrably runnable end-to-end even before real weights are trained or
downloaded (see weights/README.md).
"""

import argparse
import os
import sys

import torch
from PIL import Image

from model import Generator
from utils import preprocess, postprocess


def load_generator(checkpoint_path: str) -> tuple[Generator, bool]:
    """Build the Generator and try to load a checkpoint into it.

    Returns (model, checkpoint_loaded) where checkpoint_loaded is False if
    the checkpoint file was missing (model still returned, with random
    weights).
    """
    model = Generator()

    if os.path.isfile(checkpoint_path):
        state_dict = torch.load(checkpoint_path, map_location="cpu")
        # Support both a raw state_dict and a dict that wraps it, e.g.
        # {"state_dict": ..., "epoch": ...}, which is a common checkpoint
        # format for GAN training scripts.
        if isinstance(state_dict, dict) and "state_dict" in state_dict:
            state_dict = state_dict["state_dict"]
        model.load_state_dict(state_dict)
        checkpoint_loaded = True
    else:
        print(
            f"WARNING: no checkpoint found at {checkpoint_path} — running "
            "with randomly-initialized weights, output will be meaningless. "
            "See weights/README.md.",
            file=sys.stderr,
        )
        checkpoint_loaded = False

    model.eval()
    return model, checkpoint_loaded


def run_inference(model: Generator, image: Image.Image) -> Image.Image:
    """Run the generator on a single PIL image and return the deblurred PIL image."""
    tensor, original_size, _padded_size = preprocess(image)
    with torch.no_grad():
        output_tensor = model(tensor)
    return postprocess(output_tensor, original_size)


def parse_args(argv=None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run the DeblurGAN generator on a single image."
    )
    parser.add_argument(
        "--input", required=True, help="Path to the input (blurred) image."
    )
    parser.add_argument(
        "--output", required=True, help="Path to write the deblurred output image."
    )
    parser.add_argument(
        "--checkpoint",
        default=os.path.join("weights", "generator.pth"),
        help="Path to a generator checkpoint (PyTorch state_dict). "
        "Defaults to weights/generator.pth.",
    )
    return parser.parse_args(argv)


def main(argv=None) -> int:
    args = parse_args(argv)

    model, _checkpoint_loaded = load_generator(args.checkpoint)

    input_image = Image.open(args.input)
    output_image = run_inference(model, input_image)

    output_dir = os.path.dirname(os.path.abspath(args.output))
    if output_dir:
        os.makedirs(output_dir, exist_ok=True)
    output_image.save(args.output)

    print(f"Saved deblurred image to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
