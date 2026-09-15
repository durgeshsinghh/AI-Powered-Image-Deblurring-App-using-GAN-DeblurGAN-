<#
.SYNOPSIS
    Sets up a local Python virtual environment for ml-model, and (by
    default) downloads the GoPro training dataset.

.DESCRIPTION
    Creates .venv, installs requirements.txt + requirements-dev.txt into
    it, and runs scripts/download_dataset.py (skip with -SkipDataset).
    Safe to run start-to-finish unattended (no prompts).

    This script does NOT run training itself -- see the "Training
    DeblurGAN" section of README.md. Actually running train.py on a GPU-
    less laptop is impractically slow; this script exists so local
    inference/tests can still be set up here, and so there's a Windows-
    native counterpart to scripts/setup_local.sh / the Colab notebook.

.PARAMETER SkipDataset
    Skip downloading the GOPRO_Large dataset (several GB). Use this if you
    only want the Python environment (e.g. to run inference.py / the API
    / pytest), or plan to fetch the dataset separately / on another
    machine (e.g. directly on Colab).

.EXAMPLE
    .\scripts\setup_local.ps1

.EXAMPLE
    .\scripts\setup_local.ps1 -SkipDataset
#>

param(
    [switch]$SkipDataset
)

$ErrorActionPreference = "Stop"

# Always operate relative to the ml-model root, regardless of the caller's
# current directory.
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

Write-Host "==> Creating virtual environment at .venv" -ForegroundColor Cyan
python -m venv .venv

$VenvPython = Join-Path $RepoRoot ".venv\Scripts\python.exe"
if (-not (Test-Path $VenvPython)) {
    throw "Virtual environment creation appears to have failed: $VenvPython not found."
}

Write-Host "==> Upgrading pip" -ForegroundColor Cyan
# Invoked as a module (not '.venv\Scripts\pip.exe install --upgrade pip')
# because pip cannot reliably replace its own running executable on
# Windows -- that form fails with "To modify pip, please run ... -m pip".
& $VenvPython -m pip install --upgrade pip

Write-Host "==> Installing requirements.txt + requirements-dev.txt" -ForegroundColor Cyan
& $VenvPython -m pip install -r requirements.txt -r requirements-dev.txt

if (-not $SkipDataset) {
    Write-Host "==> Downloading GOPRO_Large dataset (several GB -- this can take a while)" -ForegroundColor Cyan
    & $VenvPython scripts\download_dataset.py
} else {
    Write-Host "==> Skipping dataset download (-SkipDataset)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==> Setup complete." -ForegroundColor Green
Write-Host "Activate the environment with:"
Write-Host "    .venv\Scripts\Activate.ps1"
Write-Host ""
Write-Host "Then start training with, e.g.:"
Write-Host "    python train.py --data-dir data\GOPRO_Large --epochs 300 --batch-size 1 --checkpoint-dir checkpoints"
Write-Host ""
Write-Host "NOTE: training is impractically slow without a GPU. This laptop is not the intended place to run" -ForegroundColor Yellow
Write-Host "full training -- see notebooks\train_on_colab.ipynb / README.md for Colab or a cloud GPU VM instead." -ForegroundColor Yellow
