# Backend — DeblurGAN Orchestration API

Spring Boot REST API for the *AI-Powered Image Deblurring App Using GAN
(DeblurGAN)* final-year project. This service sits between the Flutter
mobile app (`../frontend/`) and the deployed DeblurGAN inference API
([durgeshsinghh/AI-Powered-Image-Deblurring-App-using-GAN-DeblurGAN-](https://github.com/durgeshsinghh/AI-Powered-Image-Deblurring-App-using-GAN-DeblurGAN-),
live at `https://deblurgan-api.onrender.com`):

```
Flutter app  --HTTP-->  Spring Boot backend  --HTTP-->  DeblurGAN inference API
(frontend/)              (backend/, :8080)              (deblurgan-api.onrender.com)
```

It does **no image processing itself** — it validates the upload, forwards
the image bytes (base64-encoded) to the ML service's `POST /deblur/base64`
endpoint, and returns a single JSON response combining the decoded result
image with the round-trip time, so the mobile app never has to juggle
multipart responses or talk to the ML service directly.

`../app/` in this same repo is that ML service's own source — see
[`../app/README.md`](../app/README.md) for how it's built and how to run a
local copy if you want to develop against something other than the
deployed instance.

The fixed contract this service implements (exact endpoints, field names,
and status codes) lives at [`../docs/API_CONTRACT.md`](../docs/API_CONTRACT.md)
— read that first if you're integrating against this service.

## Tech stack

- Java 17
- Spring Boot 3.3.4
- `spring-boot-starter-web` — REST controllers
- `spring-boot-starter-webflux` — used **only** for its `WebClient` bean to
  call the ML service; this is not a reactive app. Controllers are plain
  blocking `@RestController`s that call `WebClient` and `.block()`.
- `spring-boot-starter-validation`
- `spring-boot-starter-test` (JUnit 5, MockMvc, Mockito) for tests

## Project layout

```
src/main/java/com/deblurgan/backend/
  BackendApplication.java        entry point
  controller/DeblurController.java   POST /api/v1/deblur, GET /api/v1/health
  service/DeblurService.java         validation + orchestration + timing
  client/MlInferenceClient.java      WebClient wrapper around the ML service
  dto/DeblurResponse.java, HealthResponse.java
  exception/                         custom exceptions + @RestControllerAdvice
  config/WebClientConfig.java, CorsConfig.java
src/main/resources/application.yml
src/test/java/...                  smoke test + controller slice tests
```

## Running it

### Option A — Maven Wrapper (recommended, no local Maven install needed)

This repo includes a real Maven Wrapper (`mvnw` / `mvnw.cmd` / `.mvn/`), so
you don't need Maven installed system-wide — it downloads the right Maven
version for you on first run.

From `backend/`, on Windows:

```powershell
.\mvnw.cmd spring-boot:run
```

On macOS/Linux:

```bash
./mvnw spring-boot:run
```

To just build a jar:

```powershell
.\mvnw.cmd clean package
java -jar target\backend-0.0.1-SNAPSHOT.jar
```

To run tests:

```powershell
.\mvnw.cmd test
```

### Option B — system Maven or an IDE

If you have Maven on your `PATH` already, the equivalent plain commands work
the same way (`mvn spring-boot:run`, `mvn clean package`, `mvn test`).

Otherwise, open the `backend/` folder as a Maven project in IntelliJ IDEA,
Eclipse, or VS Code with the Java/Maven extensions — all of these bundle
their own Maven and will resolve `pom.xml` automatically. Run
`BackendApplication.main()` directly, or use the IDE's Maven
`spring-boot:run` target.

The service starts on **port 8080**.

## Configuration

| Property | Env var | Default | Purpose |
|---|---|---|---|
| `ml.service.url` | `ML_SERVICE_URL` | `https://deblurgan-api.onrender.com` | Base URL of the DeblurGAN inference API |
| `server.port` | — | `8080` | Port this backend listens on (Render overrides via `$PORT`, see `Dockerfile`) |

Point the backend at a different ML service instance (e.g. a locally-run
copy of the model for offline dev, or a teammate's machine) without touching
code:

```powershell
$env:ML_SERVICE_URL = "http://localhost:8000"
.\mvnw.cmd spring-boot:run
```

```bash
ML_SERVICE_URL=http://localhost:8000 ./mvnw spring-boot:run
```

**The default ML service is hosted on Render's free tier**, which spins
down after 15 minutes idle — the first request after a while can take up to
a minute just to wake it, before any actual inference happens. The
`WebClient` in `config/WebClientConfig.java` is configured with a 100s
response timeout to accommodate this, and `MlInferenceClient` surfaces a
specific "waking up, try again shortly" message when it detects a
cold-start timeout rather than a generic failure. `/api/v1/health` reports
`mlServiceStatus: "DOWN"` if the ML service is unreachable, without
crashing the backend itself.

## API

Full details, exact JSON shapes, and error cases: see
[`../docs/API_CONTRACT.md`](../docs/API_CONTRACT.md). Summary:

- `GET /api/v1/health` → `{ "status": "UP", "mlServiceStatus": "UP" | "DOWN" }`
- `POST /api/v1/deblur` — `multipart/form-data`, field `image` (JPG/PNG, ≤10MB)
  → `{ "success": true, "originalFilename": "...", "processingTimeMs": 842, "deblurredImageBase64": "..." }`
  on success, or `{ "success": false, "error": "..." }` with `400`/`413`/`422`/`502`
  on failure (`422` specifically means the ML engine was reached but couldn't
  process that particular image — a different picture may still work).

### Try it with curl

```bash
curl -F "image=@photo.jpg" http://localhost:8080/api/v1/deblur
```

```bash
curl http://localhost:8080/api/v1/health
```

## Deploying to Render

`Dockerfile` builds a runnable image (multi-stage: Maven build, then a slim
JRE runtime). The repo root already has a `render.yaml` for the ML service,
so this backend isn't auto-detected by that same Blueprint — deploy it as
its own manually-configured Web Service instead:

1. In the Render dashboard: **New** → **Web Service** → connect this GitHub
   repo.
2. **Root Directory**: `backend`
3. **Runtime**: Docker (Render will find `backend/Dockerfile` automatically
   once the root directory is set).
4. **Plan**: Free is fine for a demo (same cold-start caveat as the ML
   service applies here too).
5. **Environment variables**: add `ML_SERVICE_URL` =
   `https://deblurgan-api.onrender.com` (or leave unset — that's already the
   compiled-in default).
6. **Health check path**: `/api/v1/health`.
7. Deploy. Render assigns a public URL like
   `https://deblurgan-backend.onrender.com` — put that in
   `../frontend/lib/config/api_config.dart` as `ApiConfig.baseUrl` so the
   Flutter app can reach it from any device, not just your dev machine.

`backend/render.yaml` documents this same configuration as a Blueprint file,
kept for reference (and ready to use directly if this backend is ever split
into its own repository).

## Notes / deviations from a strict "Spring Boot 3.3.x" pin

Spring Initializr no longer generates Spring Boot 3.3.x projects (it now
defaults to Spring Boot 4.x, which renames some starters, e.g.
`spring-boot-starter-web` → `spring-boot-starter-webmvc`, and splits the
single `spring-boot-starter-test` into per-module test starters). To keep
this service on the well-documented 3.3.x starter names/conventions the rest
of the team expects, the Maven Wrapper files were generated via Initializr
(they are Maven-version-only and not tied to any Spring Boot version) and
then `pom.xml` was hand-written against
`spring-boot-starter-parent:3.3.4`, which is still fully available on Maven
Central. Everything else follows the API contract as specified.

CORS is wide open (`allowedOrigins("*")`) for local development/demo
purposes — see the comment in `CorsConfig.java`. Tighten this before any
real deployment.
