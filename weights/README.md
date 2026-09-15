# weights/

This folder is where a trained DeblurGAN generator checkpoint goes:

```
weights/generator.pth
```

The checkpoint must be a PyTorch `state_dict` (or a dict containing one
under a `"state_dict"` key) whose keys/shapes match the `Generator` class
defined in `model/generator.py`.

## Running without a checkpoint

The API (`api/app.py`) and CLI (`inference.py`) both run without this file
present — they fall back to a randomly-initialized `Generator`, print a
clear warning, and still produce an image of the correct shape. This keeps
the pipeline demonstrably runnable end-to-end (and lets the backend/frontend
integrate against it) before anyone has trained or downloaded real weights.
Output from random weights is meaningless noise, not a deblurred image —
`GET /health` reports `model_loaded: false` in this case so callers can
detect it.

## Getting real weights

The API/CLI (`api/app.py`, `inference.py`) are inference-only and don't
know how to train anything — but this project does now include a real
training pipeline (`train.py`, `model/discriminator.py`, `losses/`,
`data/`), it's just kept separate from the serving code and meant to be
run on Colab/a cloud GPU rather than here. To get a real `generator.pth`:

- **Train your own**, matching this exact `Generator` architecture:
  ```bash
  python scripts/download_dataset.py      # fetches the GoPro dataset
  python train.py --data-dir data/GOPRO_Large --epochs 300 --checkpoint-dir checkpoints
  cp checkpoints/generator_latest.pth weights/generator.pth
  ```
  See the "Training DeblurGAN" section of [`../README.md`](../README.md)
  for the full rundown (dataset, loss, optimizer schedule, `--resume`) and
  `notebooks/train_on_colab.ipynb` for an end-to-end Colab notebook — this
  is a multi-GB dataset and a multi-day GPU training run, so it's meant
  for Colab/a cloud GPU VM, not a laptop.
- Or use pretrained weights from the official paper repository:
  https://github.com/KupynOrest/DeblurGAN
  (convert/rename their generator weights to a plain `state_dict` matching
  `model/generator.py` if the key names differ).

Once you have a file, drop it at `weights/generator.pth`, or point
`MODEL_CHECKPOINT_PATH` at wherever you put it.
