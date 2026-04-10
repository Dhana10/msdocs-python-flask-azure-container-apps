# Restaurant Reviews — Simplified Azure Deployment

Flask API on **Azure Container Apps**, SQLite as the database (free, no separate service),
images in **Azure Container Registry**, Bicep IaC, GitHub Actions CI/CD with OIDC
(zero stored client secrets for Azure).

> **Student-account friendly**: only ACR Basic (~$5/month from your $100 credit) and
> Container Apps consumption plan (generous free tier). No PostgreSQL, no Static Web Apps.

---

## Architecture

```
  GitHub Actions (OIDC — no client secret)
        │
        ├─── infra.yml ──► Bicep deploy ──► Azure Resource Group
        │                                       ├── ACR (Basic)
        │                                       ├── Managed Identity
        │                                       ├── Log Analytics
        │                                       └── Container App
        │
        └─── deploy.yml ─► docker build
                           docker push ──► ACR
                           az containerapp update ──► Container App
                                                          │
                                                     Flask + SQLite
                                                     (templates + /api/*)
```

**SQLite note**: data lives inside the container — it resets if the container restarts
or scales. This is fine for demos. Add Azure Files or migrate to PostgreSQL later if
persistence is needed.

---

## Cost

| Resource | SKU | Approx cost |
|----------|-----|-------------|
| Azure Container Registry | Basic | ~$5/month |
| Container Apps | Consumption (scale-to-zero) | Free within monthly grant |
| Log Analytics | Pay-as-you-go | ~$0 for low volume |
| **Total** | | **~$5/month** from student credit |

---

## One-time setup

### 1. Register an Entra app for OIDC

```bash
# Create the app registration
az ad app create --display-name "github-restrev-deploy"

# Note the appId from output — this is AZURE_CLIENT_ID
APP_ID="<appId from above>"

# Create the service principal
az ad sp create --id "${APP_ID}"

# Get the SP object ID (needed for role assignments and Bicep)
SP_OID="$(az ad sp show --id "${APP_ID}" --query id -o tsv)"
echo "SP object ID: ${SP_OID}"
```

### 2. Add federated credentials (GitHub OIDC)

Go to **Azure Portal → Entra ID → App registrations → your app → Certificates & secrets
→ Federated credentials → Add credential**:

| Field | Value |
|-------|-------|
| Federated credential scenario | GitHub Actions deploying Azure resources |
| Organization | your GitHub username or org |
| Repository | `msdocs-python-flask-azure-container-apps` |
| Entity type | Branch |
| Branch | `main` |
| Name | `github-main` |

Or via CLI:
```bash
az ad app federated-credential create \
  --id "${APP_ID}" \
  --parameters '{
    "name": "github-main",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:<YOUR_GITHUB_ORG>/<YOUR_REPO>:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

### 3. Assign Contributor role to the service principal

```bash
SUBSCRIPTION_ID="$(az account show --query id -o tsv)"

az role assignment create \
  --assignee-object-id "${SP_OID}" \
  --assignee-principal-type ServicePrincipal \
  --role Contributor \
  --scope "/subscriptions/${SUBSCRIPTION_ID}"
```

> You can scope this to a resource group instead for least privilege — just create the
> resource group first.

### 4. Note down your IDs

```bash
az account show --query '{subscriptionId:id, tenantId:tenantId}' -o table
echo "Client ID (App ID): ${APP_ID}"
```

---

## GitHub repository configuration

### Repository Variables (Settings → Secrets and variables → Variables → Repository)

| Variable | Example | Description |
|----------|---------|-------------|
| `AZURE_CLIENT_ID` | `xxxxxxxx-xxxx-...` | App Registration Application (client) ID |
| `AZURE_TENANT_ID` | `xxxxxxxx-xxxx-...` | Azure Active Directory tenant ID |
| `AZURE_SUBSCRIPTION_ID` | `xxxxxxxx-xxxx-...` | Azure subscription ID |
| `AZURE_LOCATION` | `eastus` | Azure region (optional, defaults to eastus) |
| `ACR_NAME` | `acrrestrev12345` | **Globally unique**, alphanumeric only, 5-50 chars |
| `RESOURCE_GROUP` | `rg-restrev` | Resource group name (created automatically) |
| `CONTAINER_APP_NAME` | `ca-restrev` | Must match `projectSlug` in Bicep (default `restrev`) |

### Repository Secrets (Settings → Secrets and variables → Secrets → Repository)

| Secret | Description |
|--------|-------------|
| `FLASK_SECRET_KEY` | Random string — generate with `python -c "import secrets; print(secrets.token_hex(32))"` |

---

## Deploy

### Step 1 — Push infra changes to deploy infrastructure

The `infra.yml` workflow triggers on any change to `infra/**` or manually via
**Actions → Infra → Run workflow**.

```
GitHub push to main (infra/** changed)
    → infra.yml
        → az group create
        → az deployment group create (main.bicep)
            → ACR + Managed Identity + Container App
```

After the first run, copy the Container App name from the workflow output (or Portal)
and set `CONTAINER_APP_NAME` in repository variables if you used a custom `projectSlug`.

### Step 2 — Push backend changes to build and deploy

The `deploy.yml` workflow triggers on any change to `backend/**` or manually.

```
GitHub push to main (backend/** changed)
    → deploy.yml
        → az acr login
        → docker build ./backend
        → docker push → ACR
        → az containerapp update --image <new-image>
```

### Step 3 — Verify

```bash
# Get the Container App URL
az containerapp show \
  --name ca-restrev \
  --resource-group rg-restrev \
  --query properties.configuration.ingress.fqdn -o tsv

# Health check
curl https://<fqdn>/api/health
# → {"status":"ok"}

# Open in browser
start https://<fqdn>
```

---

## Workflows summary

| Workflow | Triggers | What it does |
|----------|----------|--------------|
| `infra.yml` | Push to `infra/**`, manual | Creates RG + deploys Bicep (ACR, Container App) |
| `deploy.yml` | Push to `backend/**`, manual | `docker build` → push to ACR → `containerapp update` |

---

## Local development (no Azure)

```bash
cd backend
cp .env.example .env      # fill in LOCAL_SECRET_KEY, DBHOST/DBNAME/DBUSER/DBPASS
pip install -r requirements.txt
export FLASK_APP=app.py
flask db upgrade           # creates local SQLite or Postgres tables
flask run                  # http://localhost:5000
```

Docker:
```bash
docker compose up --build   # uses backend/.env
```

---

## Bicep resource overview

```
infra/
├── main.bicep          ← entry point (single resource group, no postgres, no SWA)
├── acr.bicep           ← Azure Container Registry (Basic)
├── acr-role.bicep      ← AcrPull role for managed identity; AcrPush for CI
├── identity.bicep      ← User-assigned managed identity
└── containerapp.bicep  ← Log Analytics + Container App Environment + Container App
```

Parameters accepted by `main.bicep`:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `projectSlug` | `restrev` | Short name prefix for all resources |
| `acrName` | (required) | Globally unique ACR name |
| `deployerPrincipalId` | `''` | SP object ID for AcrPush grant |
| `flaskSecretKey` | (required, secure) | Flask session secret |
| `containerImage` | hello-world placeholder | Overwritten by deploy workflow |

---

## Adding PostgreSQL later (optional)

If you outgrow SQLite, re-add the database:

1. Set `DBHOST`, `DBUSER`, `DBNAME` env vars in the Container App.
2. `backend/azureproject/production.py` already detects `DBHOST` and switches to
   PostgreSQL with Azure AD token auth automatically.
3. Re-add `infra/postgres.bicep` module to `main.bicep`.
4. Run `scripts/grant-postgres-aad-user.sh` to configure AAD login.
