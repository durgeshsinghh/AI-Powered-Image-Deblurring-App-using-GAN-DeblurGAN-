FROM python:3.11-slim

WORKDIR /app

# CPU-only torch wheel — far smaller than the default (which pulls CUDA deps
# even on a CPU-only host) and this app never touches a GPU.
RUN pip install --no-cache-dir torch --index-url https://download.pytorch.org/whl/cpu

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ ./app/
COPY checkpoints/ ./checkpoints/

# Bounds peak RAM for memory-constrained free-tier hosts (see README).
ENV DEBLURGAN_MAX_DIM=384
ENV PORT=8000

EXPOSE 8000
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT}"]
