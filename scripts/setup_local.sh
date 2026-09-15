#!/usr/bin/env bash
# Sets up a local Python virtual environment for ml-model, and (by
# default) downloads the GoPro training dataset. Works in Git Bash on
# Windows, WSL, Linux, and macOS -- and its steps double as the basis for
# the Colab notebook's shell cells (notebooks/train_on_colab.ipynb).
#
# This script does NOT run training itself -- see the "Training
# DeblurGAN" section of README.md. Actually running train.py without a
# GPU is impractically slow; this script exists so local inference/tests
# can still be set up here, and so there's a POSIX counterpart to
# scripts/setup_local.ps1 / the Colab notebook.
#
# Usage:
#   ./scripts/setup_local.sh              # full setup incl. dataset download
#   ./scripts/setup_local.sh --skip-dataset

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$REPO_ROOT"

SKIP_DATASET=0
for arg in "$@"; do
    case "$arg" in
        --skip-dataset)
            SKIP_DATASET=1
            ;;
        *)
            echo "Unknown argument: $arg" >&2
            echo "Usage: $0 [--skip-dataset]" >&2
            exit 1
            ;;
    esac
done

PYTHON_BIN="${PYTHON_BIN:-python}"
if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
    PYTHON_BIN=python3
fi

echo "==> Creating virtual environment at .venv"
"$PYTHON_BIN" -m venv .venv

if [ -f ".venv/Scripts/python.exe" ]; then
    VENV_PYTHON=".venv/Scripts/python.exe"   # Windows venv layout (Git Bash)
else
    VENV_PYTHON=".venv/bin/python"           # POSIX venv layout
fi

echo "==> Upgrading pip"
# Invoked as a module, not the pip executable directly -- pip cannot
# reliably replace its own running executable on Windows that way.
"$VENV_PYTHON" -m pip install --upgrade pip

echo "==> Installing requirements.txt + requirements-dev.txt"
"$VENV_PYTHON" -m pip install -r requirements.txt -r requirements-dev.txt

if [ "$SKIP_DATASET" -eq 0 ]; then
    echo "==> Downloading GOPRO_Large dataset (several GB -- this can take a while)"
    "$VENV_PYTHON" scripts/download_dataset.py
else
    echo "==> Skipping dataset download (--skip-dataset)"
fi

echo
echo "==> Setup complete."
echo "Activate the environment with:"
echo "    . .venv/Scripts/activate   # Git Bash on Windows"
echo "    source .venv/bin/activate  # Linux / macOS / WSL"
echo
echo "Then start training with, e.g.:"
echo "    python train.py --data-dir data/GOPRO_Large --epochs 300 --batch-size 1 --checkpoint-dir checkpoints"
echo
echo "NOTE: training is impractically slow without a GPU. This machine may not be the intended place to run"
echo "full training -- see notebooks/train_on_colab.ipynb / README.md for Colab or a cloud GPU VM instead."
