# Telco Churn — Azure-deployed MLflow Lifecycle (variant)

This is the **Azure-deployed variant** of my AIN-3009 MLOps term project.
The Python code is identical to the local submission
([mohameddribika/mlops_project](https://github.com/mohameddribika/mlops_project));
the only addition is a Docker + Azure Container Apps deployment layer so
the same MLflow tracking UI can run on a public HTTPS URL.

| Variant | Repository | What it shows |
| --- | --- | --- |
| Local | [mlops_project](https://github.com/mohameddribika/mlops_project) | The graded submission. MLflow tracking server on localhost. |
| Azure | this repo | The same project, containerised, deployable to Azure Container Apps in one `az containerapp up` command. |

The brief allows "local machine **or** cloud environment" for the MLflow
setup. The local version satisfies the requirement; this Azure variant
demonstrates the cloud option as well.

---

## Quick start — local Docker (no Azure account needed)

```bash
docker compose up --build           # build the image and start it
# open http://127.0.0.1:5001 in a browser
docker compose down                 # stop everything
```

The image bakes the full lifecycle in at build time — training, Hyperopt
tuning, registry promotion, and a monitoring batch — so the UI is
populated and ready to demo the moment the container is reachable.

---

## Quick start — Azure Container Apps

See [`azure/README.md`](azure/README.md) for full prerequisites and the
single-command deploy.

Short version, once you have the Azure CLI installed and `az login` done:

```bash
az group create --name mlops-telco-rg --location westeurope
az containerapp env create --name mlops-telco-env --resource-group mlops-telco-rg --location westeurope
az containerapp up \
    --resource-group mlops-telco-rg \
    --environment mlops-telco-env \
    --name mlflow-telco-ui \
    --location westeurope \
    --source . \
    --target-port 5000 \
    --ingress external
```

When the command finishes it prints a public HTTPS URL — open it and you
see the same populated MLflow UI you have locally.

---

## Project layout

```
PRJ-mohameddribika-2280197-azure/
├── src/                     # unchanged: data_loader, train, tune,
│                            # registry, monitor, evaluation, pipeline,
│                            # mlflow_utils, config
├── scripts/                 # local MLflow UI / serve launchers (unchanged)
├── data/raw/                # IBM Telco Customer Churn dataset
├── artifacts/               # ROC + confusion-matrix plots
├── reports/                 # deliverables (PDF, DOCX, PPTX, drift HTMLs)
├── azure/
│   └── README.md            # step-by-step Azure deploy guide
├── Dockerfile               # containerises the project + bakes the lifecycle
├── docker-compose.yml       # for local Docker testing
├── .dockerignore
├── requirements.txt
└── README.md                # this file
```

---

## What is the same as the local submission

All five lifecycle objectives, the same source code, the same dataset,
the same metrics, and the same registered model
`telco-churn-classifier` with `@staging` and `@production` aliases.

## What is new in this variant

- **Dockerfile** that runs `train → tune → registry → monitor` at build
  time, so the deployed container starts with a populated tracking store.
- **`docker-compose.yml`** for testing the image locally before deploying.
- **`azure/README.md`** documenting the single-command Container Apps
  deploy.

## What I deliberately did not do

- Externalise the backend store to Azure Database for PostgreSQL.
- Externalise the artifact root to Azure Blob Storage.
- Add Azure AD authentication in front of the ingress.

These are appropriate for a real production deployment but unnecessary
for the term-project demo. The Architecture notes section in
`azure/README.md` lays out what would change for a production-grade setup.
