"""
Download and extract the GOPRO_Large dataset (Nah et al., CVPR 2017; the
dataset DeblurGAN, Kupyn et al. CVPR 2018, trains and evaluates on) into
data/GOPRO_Large/.

This is a multi-gigabyte download. It is meant to be run on Colab or a
cloud GPU VM (see notebooks/train_on_colab.ipynb, scripts/setup_local.ps1
/ scripts/setup_local.sh) where you actually intend to train -- not
casually on a laptop with a slow or metered connection.

Primary source (as of writing): a Hugging Face Datasets mirror hosting a
single zip of the full dataset:
    https://huggingface.co/datasets/snah/GOPRO_Large/resolve/main/GOPRO_Large.zip

If that link has moved or the download fails for any reason, download
manually from one of these instead, and unzip the result into
data/GOPRO_Large/ yourself:
    - Google Drive (official): https://drive.google.com/file/d/1y4wvPdOG3mojpFCHTqLgriexhbjoWVkK/view
    - Dataset homepage:        https://seungjunnah.github.io/Datasets/gopro.html

Either way, you should end up with:
    data/GOPRO_Large/train/<scene>/blur/*.png, sharp/*.png
    data/GOPRO_Large/test/<scene>/blur/*.png,  sharp/*.png

Usage:
    python scripts/download_dataset.py
    python scripts/download_dataset.py --output-dir data/GOPRO_Large --url <alternate-zip-url>

Uses only the standard library (urllib, zipfile) -- no extra dependency
needed just to fetch the dataset.
"""

import argparse
import os
import shutil
import sys
import tempfile
import urllib.error
import urllib.request
import zipfile

DEFAULT_URL = "https://huggingface.co/datasets/snah/GOPRO_Large/resolve/main/GOPRO_Large.zip"

# ml-model/ root, regardless of the current working directory this script is invoked from.
_ML_MODEL_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_OUTPUT_DIR = os.path.join(_ML_MODEL_ROOT, "data", "GOPRO_Large")

FALLBACK_NOTE = """
If the automatic download failed (source link moved, network blocked, etc.), download manually:
  - Google Drive (official GOPRO_Large): https://drive.google.com/file/d/1y4wvPdOG3mojpFCHTqLgriexhbjoWVkK/view
  - Dataset homepage: https://seungjunnah.github.io/Datasets/gopro.html
and unzip the result into: {output_dir}
so that {output_dir}/train and {output_dir}/test both exist.
"""


def _download_with_progress(url: str, dest_path: str) -> None:
    def _report(block_num, block_size, total_size):
        if total_size <= 0:
            return
        downloaded = block_num * block_size
        pct = min(100, downloaded * 100 // total_size)
        downloaded_mb = downloaded / (1024 * 1024)
        total_mb = total_size / (1024 * 1024)
        sys.stdout.write(f"\rDownloading: {pct:3d}% ({downloaded_mb:.0f} MB / {total_mb:.0f} MB)")
        sys.stdout.flush()

    print(f"Downloading GOPRO_Large dataset from {url}")
    print("This is several GB and may take a while depending on your connection.")
    urllib.request.urlretrieve(url, dest_path, reporthook=_report)
    print()  # newline after the in-place progress line


def _extract_zip(zip_path: str, output_dir: str) -> None:
    print(f"Extracting {zip_path} -> {output_dir}")
    os.makedirs(output_dir, exist_ok=True)
    with zipfile.ZipFile(zip_path) as zf:
        zf.extractall(output_dir)


def _find_train_test_dirs(output_dir: str):
    """The zip's top-level layout can vary across mirrors/releases (some
    nest an extra 'GOPRO_Large/' folder inside the zip). Look for train/
    and test/ either directly under output_dir or one level down.
    """
    candidates = [output_dir]
    if os.path.isdir(output_dir):
        candidates += [
            os.path.join(output_dir, name)
            for name in os.listdir(output_dir)
            if os.path.isdir(os.path.join(output_dir, name))
        ]

    for candidate in candidates:
        train_dir = os.path.join(candidate, "train")
        test_dir = os.path.join(candidate, "test")
        if os.path.isdir(train_dir) and os.path.isdir(test_dir):
            return candidate, train_dir, test_dir

    return None, None, None


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Download and extract the GOPRO_Large dataset.")
    parser.add_argument(
        "--output-dir",
        default=DEFAULT_OUTPUT_DIR,
        help="Where to extract the dataset (default: data/GOPRO_Large under the ml-model root).",
    )
    parser.add_argument("--url", default=DEFAULT_URL, help="Zip URL to download from.")
    parser.add_argument(
        "--keep-zip", action="store_true", help="Also keep a copy of the downloaded zip in --output-dir."
    )
    args = parser.parse_args(argv)

    output_dir = os.path.abspath(args.output_dir)
    os.makedirs(output_dir, exist_ok=True)

    with tempfile.TemporaryDirectory() as tmp_dir:
        zip_path = os.path.join(tmp_dir, "GOPRO_Large.zip")

        try:
            _download_with_progress(args.url, zip_path)
        except (urllib.error.URLError, OSError) as exc:
            print(f"\nERROR: download failed: {exc}", file=sys.stderr)
            print(FALLBACK_NOTE.format(output_dir=output_dir), file=sys.stderr)
            return 1

        try:
            _extract_zip(zip_path, output_dir)
        except (zipfile.BadZipFile, OSError) as exc:
            print(f"ERROR: extraction failed: {exc}", file=sys.stderr)
            print(FALLBACK_NOTE.format(output_dir=output_dir), file=sys.stderr)
            return 1

        if args.keep_zip:
            kept_path = os.path.join(output_dir, "GOPRO_Large.zip")
            shutil.copy(zip_path, kept_path)
            print(f"Kept downloaded zip at {kept_path}")

    found_root, train_dir, test_dir = _find_train_test_dirs(output_dir)
    if found_root is None:
        print(
            f"ERROR: extracted the archive but could not find both 'train' and 'test' "
            f"subfolders under {output_dir} (checked one level of nesting too).",
            file=sys.stderr,
        )
        print(FALLBACK_NOTE.format(output_dir=output_dir), file=sys.stderr)
        return 1

    if found_root != output_dir:
        print(
            f"Note: dataset extracted one level deeper than expected, at {found_root}. "
            f"Pass --data-dir {found_root} to train.py, or move its contents up into {output_dir}."
        )

    print(f"OK: found {train_dir} and {test_dir}")
    print("Dataset ready.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
