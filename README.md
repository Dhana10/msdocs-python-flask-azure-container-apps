# Restaurant reviews — Flask on Azure Container Apps + Static Web Apps

Sample Flask app with PostgreSQL, packaged for **production-style** Azure deployment: **Container Apps** (API), **Static Web Apps** (UI), **Bicep** IaC, **GitHub Actions** with **OIDC** (no Entra client secrets for Azure login), and **dev** / **qa** environments.

The upstream tutorial repo was extended with a JSON API, a static frontend, modular Bicep, and drift detection. See **[Plan.md](./Plan.md)** for architecture, naming, security, and step-by-step deployment.

## Repository layout

| Path | Description |
|------|-------------|
| [`backend/`](./backend/) | Flask app, Dockerfile, Alembic migrations, optional Jinja templates |
| [`frontend/`](./frontend/) | Static site for Azure Static Web Apps (`config.js` sets API URL in CI) |
| [`infra/`](./infra/) | Bicep modules (`main.bicep`, `main-shared.bicep`, `acr`, `postgres`, …) |
| [`.github/workflows/`](./.github/workflows/) | `infra.yml`, `deploy.yml`, `drift.yml` |
| [`scripts/`](./scripts/) | PostgreSQL AAD principal helper |
| [`Plan.md`](./Plan.md) | Full deployment and operations guide |

## Quick start (local)

1. Copy [`backend/.env.example`](backend/.env.example) to `backend/.env` and set PostgreSQL variables.
2. Install Python 3.12+, `cd backend`, `pip install -r requirements.txt`.
3. `set FLASK_APP=app.py` (Windows) or `export FLASK_APP=app.py`, then `flask db upgrade` and `flask run`.
4. For Docker from repo root: `docker compose up --build` (uses `backend/.env`).

For the SPA against a local API, set `window.APP.apiBase` in [`frontend/config.js`](frontend/config.js) to `http://localhost:5000`.

## Azure deployment

1. Configure Entra app + federated credential for GitHub Actions; assign subscription/RG permissions.
2. Add repository variables (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `ACR_NAME`, `ACR_RESOURCE_GROUP`, …).
3. Create GitHub Environments **dev** and **qa** with variables and secrets listed in **Plan.md**.
4. Run **Infra** workflow, then run [`scripts/grant-postgres-aad-user.sh`](scripts/grant-postgres-aad-user.sh) per PostgreSQL server.
5. Run **Deploy** workflow (or push to `main` under `backend/` / `frontend/`).

Original Microsoft tutorial (shell-based): [Deploy a Python web app on Azure Container Apps](https://learn.microsoft.com/azure/developer/python/tutorial-deploy-python-web-app-azure-container-apps-01).

## Requirements

Python packages are listed in [`backend/requirements.txt`](backend/requirements.txt) (Flask, Flask-Cors, SQLAlchemy, Gunicorn, Azure Identity, etc.).

## License

See [LICENSE.md](./LICENSE.md).
