# ml-model — DeblurGAN Inference Service + Training Pipeline

Python + PyTorch component of the *AI-Powered Image Deblurring App using
GAN (DeblurGAN)* final-year project. It owns no other part of the system —
see the root [`README.md`](../README.md) for the overall architecture and
[`../docs/API_CONTRACT.md`](../docs/API_CONTRACT.md) for the exact HTTP
contract this service implements.

This folder has two parts:

- **Serving (inference-only)** — `model/generator.py`, `utils/image_utils.py`,
  `inference.py`, `api/app.py`. This is what the backend actually talks to
  in production: load a trained generator checkpoint, deblur an image. It
  does not know or care how the checkpoint was produced.
- **Training** — `model/discriminator.py`, `losses/`, `data/`, `train.py`,
  plus `scripts/` and `notebooks/train_on_colab.ipynb`. A real, runnable
  pipeline for producing that checkpoint, meant to be run on Colab or a
  cloud GPU VM rather than a laptop (see **Training DeblurGAN**, below).
  Nothing under "Serving" imports anything from this half.

## What is DeblurGAN?

DeblurGAN (O. Kupyn, V. Budzan, M. Mykhailych, D. Mishkin, J. Matas,
"DeblurGAN: Blind Motion Deblurring Using Conditional Adversarial
Networks," CVPR 2018) is a conditional GAN for blind motion deblurring: a
generator network is trained to map a blurred image directly to a sharp
one, trained adversarially against a discriminator with a combination of
adversarial and perceptual (VGG feature) loss. At inference time only the
generator is needed — a single forward pass turns a blurred photo into a
deblurred one, with no knowledge of the blur kernel required.

## Generator architecture (`model/generator.py`)

A Johnson-style ResNet generator, per the paper's Figure 3 / Section 3.2:

1. **c7s1-64** — `Conv2d(3, 64, k=7, s=1, p=3)` → `InstanceNorm2d` → `ReLU`
2. **Downsample** — `Conv2d(64, 128, k=3, s=2, p=1)` → `InstanceNorm2d` → `ReLU`
3. **Downsample** — `Conv2d(128, 256, k=3, s=2, p=1)` → `InstanceNorm2d` → `ReLU`
4. **9× residual blocks** (256 channels): `Conv → IN → ReLU → Dropout(0.5) → Conv → IN`, plus a skip connection around each block
5. **Upsample** — `ConvTranspose2d(256, 128, k=3, s=2, p=1, op=1)` → `InstanceNorm2d` → `ReLU`
6. **Upsample** — `ConvTranspose2d(128, 64, k=3, s=2, p=1, op=1)` → `InstanceNorm2d` → `ReLU`
7. **c7s1-3** — `Conv2d(64, 3, k=7, s=1, p=3)` → `Tanh`
8. **Global skip ("ResOut")** — the network predicts a residual correction on the blurred input: `output = clamp(input + residual, -1, 1)`

The network is fully convolutional and works on any input whose height and
width are divisible by 4 (two stride-2 downsamples). `utils/image_utils.py`
reflect-pads arbitrary input sizes up to a multiple of 4 before inference
and crops back to the original size afterwards, so the model itself never
has to special-case input size.

The **serving path** (`inference.py`, `api/app.py`) only ever touches this
`Generator` class — it has no idea a discriminator or loss functions exist.
That separation is deliberate: the API/CLI stay small and fast to run
anywhere, while training (below) is free to depend on heavier things
(`torchvision`'s VGG19, a critic network) without dragging that weight into
serving.

## Project layout

```
ml-model/
├── model/
│   ├── generator.py         # Generator nn.Module (architecture above) — used by serving + training
│   ├── discriminator.py     # PatchGAN critic (WGAN-GP) — training only
│   └── __init__.py
├── utils/
│   ├── image_utils.py       # preprocess()/postprocess()/pil_to_tensor() — shared by serving + training
│   └── __init__.py
├── api/
│   ├── app.py                # FastAPI service (GET /health, POST /infer) — serving only
│   └── __init__.py
├── inference.py               # CLI: run the generator on a single image — serving only
├── losses/
│   ├── perceptual_loss.py    # VGG19 relu3_3 feature MSE (paper Eq. 7) — training only
│   ├── wgan_gp.py            # WGAN-GP critic/generator losses (paper Eq. 3/4/6) — training only
│   └── __init__.py
├── data/
│   ├── gopro_dataset.py      # paired blur/sharp dataset loader — training only
│   └── __init__.py
├── train.py                   # full training loop — training only
├── scripts/
│   ├── download_dataset.py   # fetches + extracts GOPRO_Large
│   ├── setup_local.ps1       # Windows: venv + deps + (optionally) dataset
│   └── setup_local.sh        # same, for Git Bash / WSL / Linux / macOS
├── notebooks/
│   └── train_on_colab.ipynb  # end-to-end training notebook for Google Colab
├── weights/
│   ├── README.md              # where to get/put a generator.pth checkpoint
│   └── generator.pth          # (not committed — see .gitignore)
├── data/GOPRO_Large/           # (not committed — fetched by scripts/download_dataset.py)
├── checkpoints/                 # (not committed — written by train.py)
├── tests/
│   └── test_generator.py      # shape/sanity test, no checkpoint needed
├── requirements.txt            # runtime deps (torch, fastapi, tqdm, ...)
├── requirements-dev.txt        # + pytest, for running the test suite
├── pytest.ini                  # makes `model`/`utils`/`data`/`losses` importable from tests/
├── Dockerfile                   # serving image only — does not include training code's extra weight
└── .gitignore
```

## Setup

This works the same on your own laptop, a fresh VM, or a Colab/cloud GPU
notebook — clone or copy this `ml-model/` folder, then either run the setup
script or do it by hand.

**Scripted (Windows PowerShell):**

```powershell
.\scripts\setup_local.ps1            # venv + deps + downloads the dataset
.\scripts\setup_local.ps1 -SkipDataset   # venv + deps only (no dataset download)
```

**Scripted (Git Bash / WSL / Linux / macOS):**

```bash
./scripts/setup_local.sh             # venv + deps + downloads the dataset
./scripts/setup_local.sh --skip-dataset  # venv + deps only
```

**By hand:**

```bash
cd ml-model
python -m venv .venv
# Windows (Git Bash):
. .venv/Scripts/activate
# Windows (PowerShell):
# .venv\Scripts\Activate.ps1
# macOS/Linux:
# source .venv/bin/activate

pip install -r requirements.txt
# add pytest if you also want to run the test suite:
pip install -r requirements-dev.txt
```

On Colab specifically, skip the venv (Colab's runtime is already an
isolated environment per-notebook) — see `notebooks/train_on_colab.ipynb`,
which does this for you (`!pip install -r requirements.txt`) after
uploading/mounting this folder.

`torch>=2.2` installs a CPU-only-capable build by default; the **serving**
code (`inference.py`, `api/app.py`) always runs on CPU
(`torch.load(..., map_location="cpu")`, no `.cuda()` calls anywhere), which
is enough to serve inference and matches the CPU-only `Dockerfile`. A GPU
is not required to run inference — only to train at a reasonable speed
(`train.py` does use `cuda` automatically when available; see **Training
DeblurGAN**, below).

## Running the API

```bash
uvicorn api.app:app --reload --port 8000
```

The service starts on `http://localhost:8000` and implements the contract
in [`../docs/API_CONTRACT.md`](../docs/API_CONTRACT.md):

- `GET /health` → `{"status": "ok", "model_loaded": true|false}`
- `POST /infer` → `multipart/form-data` field `image` (jpg/jpeg/png, ≤10MB) → `200` raw PNG bytes, `400` for a bad/missing file, `500` for an inference failure

The model is loaded once at startup and reused across requests. The
checkpoint path is read from the `MODEL_CHECKPOINT_PATH` environment
variable, defaulting to `weights/generator.pth`. If no checkpoint file is
present, the service still starts and serves requests — with randomly
initialized weights (`model_loaded: false`) — rather than failing to boot.

Example:

```bash
curl http://localhost:8000/health

curl -X POST http://localhost:8000/infer \
  -F "image=@path/to/blurred.jpg" \
  --output result.png
```

## Running CLI inference

```bash
python inference.py --input path/to/blurred.jpg --output path/to/result.png \
  --checkpoint weights/generator.pth
```

If `--checkpoint` doesn't exist, it prints a warning and still runs with
random weights so the pipeline is demonstrably runnable end-to-end.

## Running tests

```bash
pip install -r requirements-dev.txt   # adds pytest on top of requirements.txt
pytest
```

`tests/test_generator.py` builds a `Generator` with random weights, runs a
`1x3x256x256` tensor through it in eval mode, and checks the output shape
matches the input and contains no NaN/Inf — a fast architecture sanity
check that needs no checkpoint or GPU. `pytest.ini` sets `pythonpath = .`
so `model`/`utils`/`data`/`losses` import correctly as top-level packages
no matter how pytest is invoked (bare `pytest`, `python -m pytest`, an IDE
runner, or CI) — run it from inside `ml-model/`.

## Docker

```bash
docker build -t deblurgan-ml-model .
docker run -p 8000:8000 -v "$(pwd)/weights:/app/weights" deblurgan-ml-model
```

The Dockerfile only copies the serving code (`model/`, `utils/`, `api/`,
`inference.py`, `weights/`) — it does not include `train.py`, `data/`,
`losses/`, or `model/discriminator.py`, since a serving container has no
business training anything.

## Weights

See [`weights/README.md`](weights/README.md) for where a trained
`generator.pth` checkpoint goes and where to source one.

## Training DeblurGAN

This is a real, runnable training pipeline — not just documentation — but
it is **not meant to be run on this laptop**. The paper reports ~6 days of
training on a single Nvidia Titan X GPU for the full 300-epoch run, and the
dataset itself is several gigabytes; both the compute and the download are
sized for a Colab session or a cloud GPU VM, not a local machine with a
slow/metered connection and no GPU. `train.py` will run on CPU if that's
all that's available (it prints a loud warning), but only as a correctness
smoke test on a handful of images — not for anything resembling a real
training run.

**Loss (paper Eq. 5):** `loss = adversarial_loss + content_loss_weight * perceptual_loss`

- **Adversarial loss**: WGAN-GP (Gulrajani et al., "Improved Training of
  Wasserstein GANs," NeurIPS 2017), referenced by the DeblurGAN paper's
  Eq. 3/4/6. The critic (`model/discriminator.py`, a PatchGAN per paper
  Section 3.2) is updated `--n-critic` steps (default 5) per generator
  step. Loss formulas are in `losses/wgan_gp.py`.
- **Perceptual (content) loss**: MSE between VGG19 `relu3_3` feature
  activations of the generated and target sharp image (paper Eq. 7,
  "`VGG_{3,3}`"), weighted by `--content-loss-weight` (the paper's λ,
  default **100**). Implemented in `losses/perceptual_loss.py`.
- **Optimizer**: Adam (Kingma & Ba, ICLR 2015) for both the generator and
  the critic, initial learning rate `--lr` (default **1e-4**).
- **LR schedule**: constant for the first half of `--epochs`, then linear
  decay to 0 over the second half (paper: 150 epochs constant + 150 epochs
  decay, at 300 total — generalized to `epochs / 2` each so `--epochs` can
  be changed).
- **Batch size**: the paper found batch size **1** worked best; `--batch-size`
  defaults to that but a Colab/cloud GPU can usually go higher (8+ on a T4).
- **Dataset**: the GoPro dataset (Nah et al., CVPR 2017) of paired
  (blurred, sharp) images, laid out as
  `data/GOPRO_Large/<train|test>/<scene>/<blur|sharp>/*.png`
  (`data/gopro_dataset.py`'s `GoProDataset` also accepts a simpler flat
  `<root>/blur/*.png` + `<root>/sharp/*.png` layout for a custom dataset).

### Running training

**1. Get the dependencies and dataset** — either `scripts/setup_local.ps1`
/ `scripts/setup_local.sh` (see **Setup**, above), or by hand:

```bash
pip install -r requirements.txt
python scripts/download_dataset.py
```

`scripts/download_dataset.py` downloads and extracts the GOPRO_Large
dataset (several GB) from a Hugging Face mirror
(`https://huggingface.co/datasets/snah/GOPRO_Large/resolve/main/GOPRO_Large.zip`)
into `data/GOPRO_Large/`, and sanity-checks that `train/` and `test/` exist
afterward. If that source has moved or the download fails, it prints
fallback links — the official Google Drive listing
(`https://drive.google.com/file/d/1y4wvPdOG3mojpFCHTqLgriexhbjoWVkK/view`)
and the dataset homepage (`https://seungjunnah.github.io/Datasets/gopro.html`)
— download manually and unzip into `data/GOPRO_Large/` yourself if needed.

**2. Train:**

```bash
python train.py \
  --data-dir data/GOPRO_Large \
  --epochs 300 \
  --batch-size 1 \
  --checkpoint-dir checkpoints
```

Key flags (all optional, see `python train.py --help` for the full list):
`--lr`, `--n-critic`, `--gp-lambda` (WGAN-GP coefficient, default 10.0 —
the standard value from Gulrajani et al.; the DeblurGAN paper doesn't
restate it), `--content-loss-weight`, `--crop-size` (default 256, must be
a multiple of 4), `--save-every` (checkpoint frequency in epochs),
`--resume <path>` (resume from `checkpoints/train_state_latest.pth`),
`--num-workers`, `--log-every`.

Every `--save-every` epochs (and always at the end), `train.py` writes:

- `checkpoints/generator_epoch<N>.pth` — generator `state_dict()` only,
  exactly the format `inference.py` / `api/app.py` already expect.
- `checkpoints/generator_latest.pth` — always overwritten with the latest.
- `checkpoints/train_state_latest.pth` — generator + discriminator + both
  optimizers + epoch number, so `--resume` can pick back up.

**3. Use the trained weights for inference** — copy the result into place:

```bash
cp checkpoints/generator_latest.pth weights/generator.pth
```

`inference.py` and the FastAPI service then pick it up automatically (the
API needs a restart to reload it, since it loads the checkpoint once at
startup).

### Running on Google Colab

Open `notebooks/train_on_colab.ipynb` in Colab (`Runtime > Change runtime
type > GPU` first), upload or mount this `ml-model/` folder, and run the
cells top to bottom: install deps, mount Drive (for checkpoints that
survive a runtime reset), download the dataset, then run `train.py`
pointed at a Drive checkpoint directory, e.g.:

```bash
!python train.py --data-dir data/GOPRO_Large --epochs 300 --batch-size 8 \
    --checkpoint-dir /content/drive/MyDrive/deblurgan_checkpoints
```

The notebook's last cell shows how to copy the resulting
`generator_latest.pth` back into `weights/generator.pth`.

## See also

- [`../docs/API_CONTRACT.md`](../docs/API_CONTRACT.md) — the fixed HTTP contract this service implements.
- [`../README.md`](../README.md) — overall system architecture.
