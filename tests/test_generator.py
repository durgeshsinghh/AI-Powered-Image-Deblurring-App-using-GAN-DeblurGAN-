"""
Fast sanity test for the Generator architecture: no checkpoint required,
random initialization is fine since we're only checking output shape and
numerical sanity (no NaN/Inf), not visual quality.
"""

import torch

from model import Generator


def test_generator_output_shape_and_sanity():
    model = Generator()
    model.eval()

    input_tensor = torch.randn(1, 3, 256, 256)

    with torch.no_grad():
        output_tensor = model(input_tensor)

    assert output_tensor.shape == input_tensor.shape
    assert torch.isfinite(output_tensor).all(), "Output contains NaN or Inf values"
    assert output_tensor.min() >= -1.0 - 1e-5
    assert output_tensor.max() <= 1.0 + 1e-5
