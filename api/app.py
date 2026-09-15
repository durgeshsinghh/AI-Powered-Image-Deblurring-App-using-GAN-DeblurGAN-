"""
FastAPI service exposing the DeblurGAN generator, per the ML Inference
Service section of ../docs/API_CONTRACT.md:

    GET  /health -> {"status": "ok", "model_loaded": true|false}
    POST /infer  -> multipart/form-data field "image" (jpg/jpeg/png, <=10MB)
                    -> 200 raw PNG bytes (image/png)
                    -> 400 {"detail": "..."} for a bad/missing file
                    -> 500 {"detail": "..."} for an inference failure

The model is loaded once at startup and reused across requests.
"""

import io
import logging
import os
from contextlib import asynccontextmanager

import torch
from fastapi import FastAPI, UploadFile, File
from fastapi.responses import Response, JSONResponse
from PIL import Image, UnidentifiedImageError

from model import Generator
from utils import preprocess, postprocess

logger = logging.getLogger("ml-model.api")

ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/jpg", "image/png"}
MAX_FILE_SIZE_BYTES = 10 * 1024 * 1024  # 10 MB

DEFAULT_CHECKPOINT_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "weights",
    "generator.pth",
)


def _resolve_checkpoint_path() -> str:
    return os.environ.get("MODEL_CHECKPOINT_PATH", DEFAULT_CHECKPOINT_PATH)


def _load_model(checkpoint_path: str) -> tuple[Generator, bool]:
    """Build the Generator and load a checkpoint if one exists.

    Returns (model, model_loaded) where model_loaded is True only if a real
    checkpoint file was found and successfully loaded into the model.
    """
    model = Generator()
    model_loaded = False

    if os.path.isfile(checkpoint_path):
        try:
            state_dict = torch.load(checkpoint_path, map_location="cpu")
            if isinstance(state_dict, dict) and "state_dict" in state_dict:
                state_dict = state_dict["state_dict"]
            model.load_state_dict(state_dict)
            model_loaded = True
            logger.info("Loaded generator checkpoint from %s", checkpoint_path)
        except Exception:
            logger.exception(
                "Failed to load checkpoint at %s; running with random weights",
                checkpoint_path,
            )
    else:
        logger.warning(
            "No checkpoint found at %s — running with randomly-initialized "
            "weights, output will be meaningless. See weights/README.md.",
            checkpoint_path,
        )

    model.eval()
    return model, model_loaded


@asynccontextmanager
async def lifespan(app: FastAPI):
    checkpoint_path = _resolve_checkpoint_path()
    model, model_loaded = _load_model(checkpoint_path)
    app.state.model = model
    app.state.model_loaded = model_loaded
    app.state.checkpoint_path = checkpoint_path
    yield
    # Nothing to clean up — the model holds no external resources.


app = FastAPI(title="DeblurGAN Inference Service", lifespan=lifespan)


@app.get("/health")
async def health():
    return {"status": "ok", "model_loaded": bool(getattr(app.state, "model_loaded", False))}


@app.post("/infer")
async def infer(image: UploadFile = File(...)):
    if image.content_type not in ALLOWED_CONTENT_TYPES:
        return JSONResponse(
            status_code=400,
            content={"detail": "Unsupported file type. Use JPG or PNG."},
        )

    raw_bytes = await image.read()

    if len(raw_bytes) == 0:
        return JSONResponse(
            status_code=400,
            content={"detail": "Uploaded file is empty."},
        )

    if len(raw_bytes) > MAX_FILE_SIZE_BYTES:
        return JSONResponse(
            status_code=400,
            content={"detail": "File too large. Maximum size is 10MB."},
        )

    try:
        pil_image = Image.open(io.BytesIO(raw_bytes))
        pil_image.load()
    except UnidentifiedImageError:
        return JSONResponse(
            status_code=400,
            content={"detail": "Uploaded file is not a valid image."},
        )

    try:
        model: Generator = app.state.model
        tensor, original_size, _padded_size = preprocess(pil_image)
        with torch.no_grad():
            output_tensor = model(tensor)
        result_image = postprocess(output_tensor, original_size)

        buffer = io.BytesIO()
        result_image.save(buffer, format="PNG")
        png_bytes = buffer.getvalue()

        return Response(content=png_bytes, media_type="image/png")
    except Exception:
        logger.exception("Inference failed")
        return JSONResponse(
            status_code=500,
            content={"detail": "Inference failed. Please try again."},
        )
