# AI-Powered Image Deblurring App using GAN (DeblurGAN)

B.Tech CSE (Data Science) final-year project — Project ID `27_CS_DS_4B_13`,
Pranveer Singh Institute of Technology.

Restores motion-blurred photos using a DeblurGAN generator (Kupyn et al.,
CVPR 2018), served through a Spring Boot backend to a Flutter mobile app.

```
┌─────────────────┐        ┌──────────────────┐        ┌───────────────────────┐
│  Flutter App     │  REST  │  Spring Boot      │  REST  │  DeblurGAN API        │
│  (frontend/)     │ ─────► │  (backend/)       │ ─────► │  (app/, deployed at   │
│  image picker,   │  JSON  │  orchestration,   │  image │  deblurgan-api        │
│  before/after UI │ ◄───── │  validation       │ ◄───── │  .onrender.com)       │
└─────────────────┘        └──────────────────┘        └───────────────────────┘
```

This mirrors the client-server architecture in the project synopsis (Fig. 1).

## Folder structure

| Folder | Stack | Purpose |
|---|---|---|
| [`app/`](app/README.md) | Python + PyTorch + FastAPI | DeblurGAN generator + inference API, deployed at `https://deblurgan-api.onrender.com` |
| [`backend/`](backend/README.md) | Spring Boot (Java) | REST API, request validation, orchestrates the call to `app/`'s deployed API |
| [`frontend/`](frontend/README.md) | Flutter (Dart) | Upload a blurred photo, show the deblurred result |

Each folder is self-contained with its own README, dependencies, and run
instructions. The fixed contract between them is in
[`docs/API_CONTRACT.md`](docs/API_CONTRACT.md) — read that first if you're
integrating two parts together.

## Running the whole system

```
1. app/ is already deployed at https://deblurgan-api.onrender.com — nothing to run
   locally unless you want to develop against a local copy (see app/README.md).
2. cd backend  && (see backend/README.md)   # starts on :8080, calls the deployed API by default
3. cd frontend && (see frontend/README.md)  # run on emulator/device, pointed at the backend
```

## Reference

- O. Kupyn et al., "DeblurGAN: Blind Motion Deblurring Using Conditional
  Adversarial Networks," CVPR 2018.
- Project synopsis: *AI-Powered Image Deblurring App Using GAN (DeblurGAN)*.
