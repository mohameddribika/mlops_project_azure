# MLflow Telco Churn — Azure-ready container image.
#
# Build phase:
#   1. Install Python deps from requirements.txt.
#   2. Copy the project code and dataset.
#   3. Run the full lifecycle once at build time so the image ships with a
#      populated SQLite tracking store and a registered model already at
#      @production. The container boots ready-to-demo — no waiting for
#      training to finish after deployment.
#
# Run phase:
#   - Starts the MLflow tracking UI on 0.0.0.0:5000.
#   - Single layer, single port, suitable for Azure Container Apps.
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# System deps for the sklearn/scipy stack and for git (used by mlflow internals).
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        git \
        curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python deps first so they cache when only the code changes.
COPY requirements.txt ./
RUN pip install --upgrade pip \
    && pip install -r requirements.txt

# Project code, dataset, scripts.
COPY src/ ./src/
COPY scripts/ ./scripts/
COPY data/raw/ ./data/raw/
COPY artifacts/ ./artifacts/
COPY README.md ./

# Bake the lifecycle into the image:
#   train → tune → registry → monitor
# The fewer Hyperopt trials (5 vs 20) keeps the build to ~90 seconds while
# still demonstrating the parent/nested-runs pattern.
RUN python -m src.train \
    && python -m src.tune --model gradient_boosting --max-evals 5 \
    && python -m src.registry register-best \
    && python -m src.registry transition 1 staging \
    && python -m src.registry transition 1 production \
    && python -m src.monitor

EXPOSE 5000

# Azure Container Apps health probe hits "/" by default; MLflow returns 200 there.
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD curl -fsS http://localhost:5000/ || exit 1

# --host 0.0.0.0 (not 127.0.0.1) so the container accepts external traffic.
# Use the env-driven backend so the same image works locally and in Azure.
ENV MLFLOW_BACKEND_STORE_URI=sqlite:///app/mlflow.db \
    MLFLOW_ARTIFACT_ROOT=/app/mlruns

CMD ["mlflow", "server", \
     "--backend-store-uri", "sqlite:////app/mlflow.db", \
     "--default-artifact-root", "/app/mlruns", \
     "--host", "0.0.0.0", \
     "--port", "5000"]
