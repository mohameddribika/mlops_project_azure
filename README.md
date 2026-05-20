# MLflow Lifecycle Management — Telco Customer Churn

End-to-end machine-learning lifecycle management built on **MLflow**, covering all five
lifecycle stages required by the brief — experiment tracking, model training & tuning,
model deployment, performance monitoring, and the model registry — applied to predicting
customer churn on the IBM Telco dataset.

The project ships as a **single, self-contained Docker image** that bakes the full
lifecycle in at build time, so the MLflow UI is populated and demo-ready the moment the
container starts. The same image runs locally with `docker compose` or deploys to
**Azure Container Apps** in one command for a public HTTPS URL.

> **Course:** AIN-3009 MLOps — Bahçeşehir University
> **Author:** Mohamed Dribika (2280197)
> **Best test ROC-AUC:** 0.8457 (tuned Gradient Boosting)

---

## Lifecycle objectives → where they live in the code

| # | Objective                | Module                         | What it does                                                                                                  |
|---|--------------------------|--------------------------------|---------------------------------------------------------------------------------------------------------------|
| 1 | Experiment tracking      | [`src/train.py`](src/train.py) | Logs parameters, train/val/test metrics, ROC + confusion-matrix plots, and the packaged model to MLflow      |
| 2 | Model training & tuning  | [`src/train.py`](src/train.py), [`src/tune.py`](src/tune.py) | Three baseline classifiers (LogReg, Random Forest, Gradient Boosting) plus Hyperopt TPE search with nested runs |
| 3 | Model deployment         | [`Dockerfile`](Dockerfile), [`azure/`](azure/), [`scripts/start_mlflow_serve.sh`](scripts/start_mlflow_serve.sh) | `mlflow models serve` from the registry alias; Docker image deployable to Azure Container Apps                |
| 4 | Performance monitoring   | [`src/monitor.py`](src/monitor.py) | PSI + KS + Evidently drift reports against simulated production batches (clean / feature drift / concept drift) |
| 5 | Model registry           | [`src/registry.py`](src/registry.py) | Auto-registers the best run, transitions versions through `@staging` → `@production` aliases                 |

---

## Quick start — local Docker

Prereq: Docker Desktop installed and running.

```bash
docker compose up --build
# open http://127.0.0.1:5002 in a browser
docker compose down
```

The first build takes ~4 minutes (it runs `train → tune → registry → monitor` inside the
image). Subsequent runs are seconds — the populated MLflow store ships baked into the
image layer.

You will see:
- Two experiments — `telco_churn` (training & tuning runs) and `telco_churn_monitoring`
  (drift batches).
- A registered model `telco-churn-classifier` with `@staging` and `@production` aliases.
- ROC + confusion-matrix plots and Evidently drift HTMLs as run artifacts.

---

## Quick start — Azure Container Apps (public HTTPS URL)

See [`azure/README.md`](azure/README.md) for the full prerequisites and walkthrough.
Short version:

```bash
az group create --name mlops-telco-rg --location germanywestcentral
az containerapp env create \
    --name mlops-telco-env --resource-group mlops-telco-rg \
    --location germanywestcentral --logs-destination none

az containerapp up \
    --resource-group mlops-telco-rg --environment mlops-telco-env \
    --name mlflow-telco-ui --location germanywestcentral \
    --source . --target-port 5000 --ingress external
```

When the command finishes it prints a public HTTPS URL — the same MLflow UI you have
locally, but reachable from anywhere.

---

## Results summary

### Baseline runs (Objective 1)

| Model                       | Test ROC-AUC | Test F1 | Test Accuracy |
|-----------------------------|--------------|---------|---------------|
| Logistic Regression         | 0.8426       | 0.6049  | 0.8062        |
| Gradient Boosting           | 0.8390       | 0.5710  | 0.7963        |
| Random Forest               | 0.8223       | 0.5392  | 0.7828        |

### Tuned best (Objective 2)

20-trial Hyperopt TPE search over Gradient Boosting:

```
learning_rate     = 0.0180
max_depth         = 5
min_samples_leaf  = 18
min_samples_split = 4
n_estimators      = 225
subsample         = 0.627
```

Best val ROC-AUC = 0.8672, **best test ROC-AUC = 0.8457**.

### Drift monitoring (Objective 4)

| Scenario        | max PSI | drift_alert | prod ROC-AUC | prod F1 |
|-----------------|---------|-------------|--------------|---------|
| clean           | 0.023   | False       | 0.834        | 0.551   |
| feature drift   | 1.488   | **True**    | 0.843        | 0.617   |
| concept drift   | 0.016   | False       | **0.654**    | 0.445   |

Concept drift is the key insight — feature distributions are unchanged, PSI doesn't fire,
yet ROC-AUC collapses. Production monitoring must combine input-distribution checks
**and** performance metrics on labelled samples.

Full discussion in [`reports/project_report.pdf`](reports/project_report.pdf).

---

## Project layout

```
PRJ-mohameddribika-2280197/
├── src/                       # lifecycle stage modules + shared helpers
│   ├── data_loader.py         # raw CSV → cleaned train/val/test splits
│   ├── pipeline.py            # sklearn Pipeline: preprocessor + estimator
│   ├── evaluation.py          # accuracy / precision / recall / F1 / ROC-AUC
│   ├── train.py               # baseline runs (Objective 1, 2)
│   ├── tune.py                # Hyperopt TPE search (Objective 2)
│   ├── registry.py            # register-best, staging→production transitions (Objective 5)
│   ├── monitor.py             # PSI / KS / Evidently drift batches (Objective 4)
│   └── mlflow_utils.py        # tracking URI + experiment helpers
├── scripts/                   # local MLflow UI / serve launchers
├── data/raw/                  # IBM Telco Customer Churn dataset
├── artifacts/                 # ROC + confusion-matrix plots
├── reports/                   # PDF + DOCX report, PPTX presentation, drift HTMLs
├── azure/
│   └── README.md              # Azure Container Apps deploy guide
├── Dockerfile                 # bakes the full lifecycle at build time
├── docker-compose.yml         # local Docker run
├── requirements.txt
└── README.md
```

---

## Tech stack

| Concern          | Tool                                                     |
|------------------|----------------------------------------------------------|
| Tracking server  | MLflow 3.12 (SQLite backend store, local artifact root)  |
| ML framework     | scikit-learn 1.8 (`Pipeline` + `ColumnTransformer`)      |
| Tuning           | Hyperopt 0.2.7 (Tree-structured Parzen Estimator)        |
| Model packaging  | `mlflow.sklearn.log_model` with inferred signature       |
| Serving          | `mlflow models serve` against `models:/...@production`   |
| Drift detection  | Population Stability Index, KS test, Evidently HTML      |
| Containerisation | Docker (Python 3.12-slim)                                |
| Cloud deployment | Azure Container Apps (one-command deploy)                |

---

## Reproducing the run-set

The same commands the Dockerfile uses, so you can run them outside the container:

```bash
pip install -r requirements.txt
python -m src.train                                      # all 3 baselines
python -m src.tune --model gradient_boosting --max-evals 20
python -m src.registry register-best
python -m src.registry transition 1 staging
python -m src.registry transition 1 production
python -m src.monitor                                     # 3 drift scenarios
```

Then `bash scripts/start_mlflow_ui.sh` to open the UI at `http://127.0.0.1:5000`.

Random seeds are fixed at `RANDOM_STATE = 42` (splits + estimators) and `seed=7`
(monitoring batches) — metrics in the results table above are reproducible.

---

## Deliverables (per brief)

- **Code:** this repository
- **Project report:** [`reports/project_report.pdf`](reports/project_report.pdf) (+ DOCX source)
- **Presentation:** [`reports/presentation.pptx`](reports/presentation.pptx)
