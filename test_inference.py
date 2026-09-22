"""Quick sanity check: loads the model and deblurs the repo's own sample image."""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(__file__))

from PIL import Image
from app.inference import DeblurModel

WEIGHTS = os.path.join(os.path.dirname(__file__), "checkpoints", "official", "latest_net_G.pth")
SAMPLE = os.path.join(os.path.dirname(__file__), "..", "DeblurGAN_src", "images", "test1_blur.jpg")
OUT = os.path.join(os.path.dirname(__file__), "test_output.png")

if __name__ == "__main__":
    print(f"Loading weights from {WEIGHTS} ...")
    t0 = time.time()
    model = DeblurModel(WEIGHTS, device="cpu")
    print(f"Model loaded in {time.time() - t0:.2f}s")

    print(f"Running inference on {SAMPLE} ...")
    img = Image.open(SAMPLE)
    print(f"Input size: {img.size}")
    t0 = time.time()
    result = model.deblur(img)
    print(f"Inference took {time.time() - t0:.2f}s")

    result.save(OUT)
    print(f"Saved deblurred output to {OUT}")
