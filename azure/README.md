# Deploying to Azure Container Apps

Step-by-step guide for putting the MLflow Telco Churn project on a public
HTTPS URL. The project itself is unchanged — Azure Container Apps just
runs the same Docker image documented in the top-level [`README.md`](../README.md)
and [`Dockerfile`](../Dockerfile).

The deployment target is **Azure Container Apps** — a managed,
serverless-style container platform that scales to zero when idle, exposes
a public HTTPS URL out of the box, and bills only for compute used. It is
the cheapest and least-fuss way to put the MLflow UI on the public internet.

---

## What you get

- Public HTTPS URL → `https://mlflow-telco-ui.<region>.azurecontainerapps.io`
- MLflow UI fully populated (`telco_churn` + `telco_churn_monitoring`
  experiments, `telco-churn-classifier` v1 with `@staging` and
  `@production` aliases). The image bakes the lifecycle in at build time,
  so the UI is demo-ready the moment the container is reachable.
- One container, one port, no extra databases or blob storage to manage.

---

## Prerequisites (one-time, ~10 minutes)

1. **Install the Azure CLI**
   ```bash
   brew install azure-cli            # macOS
   # or: https://learn.microsoft.com/cli/azure/install-azure-cli
   ```

2. **Log in to Azure**
   ```bash
   az login
   ```
   This opens a browser tab. If you are a Bahçeşehir student you can use
   your student credit ($100/year) — it covers Container Apps easily.

3. **Install Docker Desktop** (optional, only needed if you want to test
   the image locally before deploying to Azure)
   ```bash
   brew install --cask docker
   ```

---

## Optional: test the container locally first (~3 minutes)

This catches any build errors before you ever talk to Azure.

```bash
cd PRJ-mohameddribika-2280197-azure
docker compose up --build
```

When you see `Listening at: http://0.0.0.0:5000`, open
**http://127.0.0.1:5001** in your browser (port 5001 on the host maps to
5000 in the container, so it doesn't collide with macOS AirPlay Receiver
or with the local MLflow you already have running).

Stop it with `Ctrl+C`, then:
```bash
docker compose down
```

---

## Deploy to Azure (~5 minutes the first time)

The whole deployment is **one command**: `az containerapp up`. Azure
handles the image build (using your local Dockerfile), pushes it to a
managed registry, creates the runtime environment, and starts the app.

```bash
cd PRJ-mohameddribika-2280197-azure

# Optional — change region/name if you want. westeurope is fine for Turkey.
RG=mlops-telco-rg
LOCATION=westeurope
ENV_NAME=mlops-telco-env
APP_NAME=mlflow-telco-ui

# Resource group + Container Apps environment (idempotent, safe to re-run).
az group create --name "$RG" --location "$LOCATION"
az containerapp env create --name "$ENV_NAME" --resource-group "$RG" --location "$LOCATION"

# Build + push + deploy from the local Dockerfile in one shot.
az containerapp up \
    --resource-group "$RG" \
    --environment "$ENV_NAME" \
    --name "$APP_NAME" \
    --location "$LOCATION" \
    --source . \
    --target-port 5000 \
    --ingress external
```

The first run takes ~5 minutes because Azure builds the image from
scratch. Subsequent re-runs (after code edits) take ~2 minutes because
the base layers are cached.

When it finishes, grab the public URL:

```bash
az containerapp show \
    --resource-group "$RG" \
    --name "$APP_NAME" \
    --query properties.configuration.ingress.fqdn \
    -o tsv
```

Then open `https://<that-hostname>` in a browser. You should see the
populated MLflow UI exactly as it looks locally.

---

## Updating the deployed app

Edit code locally, then re-run the `az containerapp up` command above.
Azure detects the source change, rebuilds the image, and rolls a new
revision into production with zero downtime. Old revision stays as a
fallback for a few minutes.

---

## Watching logs

```bash
az containerapp logs show \
    --name mlflow-telco-ui \
    --resource-group mlops-telco-rg \
    --follow
```

---

## Tearing it all down (so you stop paying)

```bash
# Deletes the app, the environment, the managed container registry, and
# all logs. Idempotent; safe to re-run.
az group delete --name mlops-telco-rg --yes --no-wait
```

Container Apps charges per second of active compute. With this image and
no traffic, idle cost is essentially zero ($0–$2/month). Under load you
pay for actual vCPU and memory consumption. Tear it down when you're done
to be safe.

---

## Architecture notes (for the report or Q&A)

| Concern | Local submission | Azure variant |
| --- | --- | --- |
| Tracking backend store | SQLite file (`mlflow.db`) | Same — inside the container |
| Artifact root | Local filesystem (`mlruns/`) | Same — inside the container |
| Serving | `mlflow models serve` on `127.0.0.1:5001` | MLflow UI on the public HTTPS URL |
| Persistence | Persisted across runs locally | Lost on container restart (acceptable for demo; production would externalise to Postgres + Azure Blob) |
| Cost | $0 | $0–$2/month idle, more under load |

For a real production deployment you would:
- Move the backend store to Azure Database for PostgreSQL Flexible Server.
- Move the artifact root to Azure Blob Storage (`wasbs://...`).
- Add Azure AD authentication in front of the ingress.
- Split training (offline batch jobs) from serving (always-on container).

This demo deliberately stays simple — the brief asks for "local machine
or cloud environment", and a single self-contained container satisfies
the cloud option without the complexity of a fully externalised state
store.
