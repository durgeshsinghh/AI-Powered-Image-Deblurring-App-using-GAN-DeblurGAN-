# DeblurGAN FastAPI Service

Wraps the official [DeblurGAN](https://github.com/KupynOrest/DeblurGAN) (Kupyn et al., CVPR 2018)
generator — matching the architecture in this project's synopsis (27_CS_DS_4B_13) — in a FastAPI
service so it can be called from a mobile/web frontend.

This is the ML inference part of the full project; `../backend/` (Spring Boot) and
`../frontend/` (Flutter) are the other two parts — see the [root README](../README.md)
for how the three fit together, and [`../docs/API_CONTRACT.md`](../docs/API_CONTRACT.md)
for the exact contract the backend calls here.

## What's here

```
app/
  generator.py     # ResNet-9-block generator (standalone copy of the official architecture)
  inference.py      # DeblurModel: load weights, preprocess, run, postprocess
  main.py             # FastAPI app: /health, /deblur, /deblur/base64
checkpoints/official/latest_net_G.pth   # pretrained generator weights (~45 MB)
requirements.txt
test_inference.py    # standalone sanity check, no server needed
```

## Model weights

The official weights link in the DeblurGAN README points to a Google Drive file that
no longer resolves ("file does not exist"). The identical checkpoint is available checked
directly into a fork's repo, so that's what's downloaded here:
`senegrom/DeblurGAN` → `checkpoints/official/latest_net_G.pth`.

This is a plain PyTorch `state_dict` (`.pth`) — the native, correct format for a GAN generator.
(Not `.joblib`: joblib/pickle is the idiomatic format for scikit-learn estimators, not PyTorch
`nn.Module` weights — using it here would just be a pickle wrapper around the same tensors with
no benefit.)

## Run it

From the repository root:

```bash
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Swagger UI: http://localhost:8000/docs

## Sanity check without the server

```bash
python test_inference.py
```

## API

### `POST /deblur` — multipart file upload → PNG image back

```bash
curl -X POST http://localhost:8000/deblur \
  -F "file=@blurry_photo.jpg" \
  -o deblurred.png
```

### `POST /deblur/base64` — JSON in, JSON out (handy for Flutter/mobile apps)

Request:
```json
{ "image_base64": "<base64-encoded image bytes>" }
```

Response:
```json
{ "image_base64": "<base64-encoded PNG bytes>", "inference_time_ms": 812.4 }
```

## Integrating into the app (matches the synopsis's client-server architecture)

Per the synopsis's Figure 1 (Flutter client → Spring Boot backend → Python/PyTorch ML engine),
`../backend/` is that Spring Boot layer: its `MlInferenceClient` calls this service's
`POST /deblur/base64` (JSON in, JSON out — simpler for a mobile HTTP client than juggling
multipart), and `../frontend/` is the Flutter app that talks to the backend, never to this
service directly. See [`../docs/API_CONTRACT.md`](../docs/API_CONTRACT.md) for the exact
wire format at every hop.

## Deploy for free (no card required) — Render

This repo includes a `Dockerfile` and `render.yaml` blueprint pre-configured for Render's
free tier (no credit card needed to sign up). `DEBLURGAN_MAX_DIM=384` is already set to keep
peak memory under Render free tier's 512MB cap (measured ~440MB peak locally, vs. ~1.5GB
uncapped — see the git history / commit for the measurements this was based on).

1. Push this folder to a new GitHub repo:
   ```bash
   git remote add origin https://github.com/<your-username>/<repo-name>.git
   git push -u origin master
   ```
2. Go to [render.com](https://render.com) → sign up free (GitHub login is easiest, no card needed).
3. Click **New +** → **Blueprint**, connect the repo you just pushed. Render reads `render.yaml`
   automatically and configures everything (Docker build, free plan, health check, env var).
4. Click **Apply** / **Deploy**. First build takes ~5-10 min (installing the CPU torch wheel).
5. You'll get a URL like `https://deblurgan-api.onrender.com`. Test it:
   ```bash
   curl -X POST https://deblurgan-api.onrender.com/deblur -F "file=@photo.jpg" -o out.png
   ```

Notes on the free tier:
- The service sleeps after 15 minutes with no traffic; the first request after sleeping takes
  ~30-60s to wake up (cold start), after which responses are normal (~1-3s per image at the
  384px cap).
- Input images are automatically downscaled (longest side capped at 384px) to fit the 512MB
  RAM limit. For higher-resolution output, run this yourself with `DEBLURGAN_MAX_DIM=0`
  (uncapped) on a machine/host with more RAM — see "Run it" above.

## Notes / limitations

- CPU inference only in this setup (no NVIDIA GPU here); a 720p image takes a few seconds on CPU.
  On a CUDA machine, pass `device="cuda"` to `DeblurModel(...)` in `app/main.py` for realtime-ish
  performance.
- The original repo's `test.py` resizes+random-crops every input to 256x256. This service instead
  runs the full image at its native resolution (padded to a multiple of 4 and cropped back), so
  output dimensions match input dimensions — more useful for a production app.
- The model was trained for **motion blur** (GoPro dataset). It won't do much for out-of-focus
  blur or heavy noise.
