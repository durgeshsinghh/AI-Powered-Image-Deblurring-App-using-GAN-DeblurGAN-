FROM python:3.11-slim

WORKDIR /app

# Install Python dependencies first for better layer caching.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code.
COPY model ./model
COPY utils ./utils
COPY api ./api
COPY inference.py .
COPY weights ./weights

ENV MODEL_CHECKPOINT_PATH=/app/weights/generator.pth

EXPOSE 8000

CMD ["uvicorn", "api.app:app", "--host", "0.0.0.0", "--port", "8000"]
