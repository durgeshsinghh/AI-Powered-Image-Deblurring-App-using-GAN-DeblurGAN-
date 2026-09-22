"""
FastAPI service exposing the DeblurGAN generator for the
"AI-Powered Image Deblurring App" project (27_CS_DS_4B_13).

Run with:
    uvicorn app.main:app --host 0.0.0.0 --port 8000

Endpoints:
    GET  /health          -> liveness/readiness check
    POST /deblur           -> multipart image upload, returns deblurred PNG
    POST /deblur/base64    -> JSON {"image_base64": "..."} -> JSON {"image_base64": "..."}
"""
import base64
import io
import os
import time

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.responses import Response
from pydantic import BaseModel

from .inference import DeblurModel

WEIGHTS_PATH = os.environ.get(
    "DEBLURGAN_WEIGHTS",
    os.path.join(os.path.dirname(__file__), "..", "checkpoints", "official", "latest_net_G.pth"),
)
# Caps input resolution to bound peak RAM (generator memory scales ~H*W).
# Default 0 = no cap, for local/unconstrained use. Set via env on memory-limited hosts.
MAX_DIM = int(os.environ.get("DEBLURGAN_MAX_DIM", "0"))

app = FastAPI(
    title="DeblurGAN API",
    description="AI-powered image deblurring using DeblurGAN (Kupyn et al., 2018)",
    version="1.0.0",
)

_model: DeblurModel | None = None


def get_model() -> DeblurModel:
    global _model
    if _model is None:
        if not os.path.exists(WEIGHTS_PATH):
            raise HTTPException(status_code=503, detail=f"Model weights not found at {WEIGHTS_PATH}")
        _model = DeblurModel(WEIGHTS_PATH, device="cpu", max_dim=MAX_DIM)
    return _model


@app.on_event("startup")
def load_model_on_startup():
    get_model()


@app.get("/health")
def health():
    return {"status": "ok", "model_loaded": _model is not None, "weights_path": WEIGHTS_PATH}


@app.post("/deblur")
async def deblur(file: UploadFile = File(...)):
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Uploaded file must be an image")

    data = await file.read()
    model = get_model()

    start = time.time()
    try:
        result_bytes = model.deblur_bytes(data, fmt="PNG")
    except Exception as exc:
        raise HTTPException(status_code=422, detail=f"Could not process image: {exc}") from exc
    elapsed_ms = round((time.time() - start) * 1000, 1)

    return Response(
        content=result_bytes,
        media_type="image/png",
        headers={"X-Inference-Time-Ms": str(elapsed_ms)},
    )


class Base64Request(BaseModel):
    image_base64: str


class Base64Response(BaseModel):
    image_base64: str
    inference_time_ms: float


@app.post("/deblur/base64", response_model=Base64Response)
def deblur_base64(req: Base64Request):
    model = get_model()
    try:
        data = base64.b64decode(req.image_base64)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Invalid base64 image: {exc}") from exc

    start = time.time()
    try:
        result_bytes = model.deblur_bytes(data, fmt="PNG")
    except Exception as exc:
        raise HTTPException(status_code=422, detail=f"Could not process image: {exc}") from exc
    elapsed_ms = round((time.time() - start) * 1000, 1)

    return Base64Response(
        image_base64=base64.b64encode(result_bytes).decode("utf-8"),
        inference_time_ms=elapsed_ms,
    )
