# API Contract

This is the fixed contract between the three services. All three folders were built
against this document — if you change an endpoint, update this file first and tell
the other two owners.

```
Flutter app  --HTTP-->  Spring Boot backend  --HTTP-->  DeblurGAN inference API
(frontend/)              (backend/, :8080)              (deblurgan-api.onrender.com)
```

The ML service (`app/` in this repo) is deployed at
`https://deblurgan-api.onrender.com`, and the backend calls that deployed
instance by default — section 1 below documents its contract.

## 1. ML Inference API — `app/`, deployed at `https://deblurgan-api.onrender.com`

Owned by: the ML team. Source lives in [`../app/`](../app/README.md) in this
same repo; in production the backend calls the already-deployed instance
over the public internet rather than running it locally, though you can run
`app/` locally too (see its README) and point the backend at that instead
during development.

Hosted on Render's **free tier**: it spins down after 15 minutes idle, and
the first request after that can take 30-60s just to wake the container,
on top of actual inference time. CPU-only inference; images are
auto-downscaled to a max of 384px to stay within the free tier's 512MB RAM
limit.

### `GET /health`
200 response:
```json
{ "status": "ok", "model_loaded": true, "weights_path": "..." }
```

### `POST /deblur/base64` — what this backend actually calls
- `application/json` body: `{ "image_base64": "<base64-encoded image>" }`
- Success `200`:
```json
{ "image_base64": "<base64-encoded PNG>", "inference_time_ms": 842.0 }
```
- Error `400`: invalid base64 input.
- Error `422`: the request was well-formed but the model failed to process
  this particular image.

### `POST /deblur` — multipart alternative (not used by this backend)
- `multipart/form-data`, field named `file` (**not** `image`).
- Success `200`: raw bytes, `Content-Type: image/png`, with an
  `X-Inference-Time-Ms` response header.
- Errors: `400` not an image, `422` processing failed, `503` model weights
  not loaded.

No auth, no state. It is a pure image-in/image-out API.

## 2. Backend (Spring Boot) — default port `8080`

Owned by: Backend person. Calls the ML API over HTTPS using `ML_SERVICE_URL`
(env var, defaults to `https://deblurgan-api.onrender.com`). Never talks to
the frontend's storage; the frontend only ever talks to the backend.

### `GET /api/v1/health`
200 response:
```json
{ "status": "UP", "mlServiceStatus": "UP" }
```
`mlServiceStatus` is `"DOWN"` (still HTTP 200 from the backend) if the ML service's
`/health` doesn't respond — lets the app show "AI engine offline" without a hard crash.

### `POST /api/v1/deblur`
- `multipart/form-data`, single field named `image` (jpg/jpeg/png, ≤ 10 MB).
- Success `200`:
```json
{
  "success": true,
  "originalFilename": "photo.jpg",
  "processingTimeMs": 842,
  "deblurredImageBase64": "iVBORw0KGgoAAAANSUhEUgAA..."
}
```
- Error `400`:
```json
{ "success": false, "error": "Unsupported file type. Use JPG or PNG." }
```
- Error `413`: file exceeded 10 MB (Spring's own multipart limit response).
- Error `422`:
```json
{ "success": false, "error": "The AI engine could not process this image. Try a different photo." }
```
- Error `502`:
```json
{ "success": false, "error": "Deblurring engine is unavailable. Try again shortly." }
```
(the `502` message is dynamic — when the backend detects the failure was a
timeout, it instead returns something like *"The deblurring engine is
waking up from being idle (this can take up to a minute on a free-tier
host). Please try again shortly."*, since that's overwhelmingly the actual
cause with the ML API's free-tier hosting.)

The backend base64-decodes/re-encodes as needed so the mobile app always
gets a single JSON response instead of juggling multipart responses or
knowing anything about the upstream ML API's own contract.

## 3. Frontend (Flutter)

Owned by: Frontend person. Only ever calls the backend's `/api/v1/*` routes above,
never the ML service directly.

Base URL lives in `frontend/lib/config/api_config.dart` — defaults to
`http://10.0.2.2:8080` (Android emulator's alias for the host machine's
`localhost`). Change it to your machine's LAN IP when testing on a real device, or
to `http://localhost:8080` when running on desktop/web.

## Local end-to-end run order

1. `backend`: start Spring Boot on `:8080` — by default it talks straight to
   the already-deployed `https://deblurgan-api.onrender.com`, so nothing
   else needs to run first. Point `ML_SERVICE_URL` at a locally-running
   `app/` instead if you want to develop against a local model.
2. `frontend`: run the Flutter app pointed at the backend — `:8080` on your
   dev machine, or the backend's own deployed Render URL once that's live
   (see `backend/README.md` → "Deploying to Render").

See each folder's own README for exact run commands.
