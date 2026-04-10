#!/usr/bin/env bash
# Run once per environment after Bicep deploys PostgreSQL + the Container App user-assigned MI.
# Prerequisites: Azure CLI, rdbms-connect extension, Entra sign-in with rights to create AAD principals on PG.
#
# Usage:
#   export PG_SERVER="pg-restrev-dev-...."
#   export PG_RESOURCE_GROUP="rg-restrev-dev"
#   export PG_DATABASE="restaurants_reviews"
#   export MI_NAME="id-restrev-dev"
#   ./scripts/grant-postgres-aad-user.sh
set -euo pipefail

: "${PG_SERVER:?}"
: "${PG_RESOURCE_GROUP:?}"
: "${PG_DATABASE:?}"
: "${MI_NAME:?}"

ADMIN_USER="$(az ad signed-in-user show --query mail -o tsv)"
TOKEN="$(az account get-access-token --resource-type oss-rdbms --query accessToken -o tsv)"

echo "Creating AAD principal for managed identity ${MI_NAME} on ${PG_SERVER}..."
az postgres flexible-server execute \
  --name "${PG_SERVER}" \
  --admin-user "${ADMIN_USER}" \
  --admin-password "${TOKEN}" \
  --database-name postgres \
  --querytext "select * from pgaadauth_create_principal('${MI_NAME}', false, false);"

echo "Granting privileges on ${PG_DATABASE}..."
az postgres flexible-server execute \
  --name "${PG_SERVER}" \
  --admin-user "${ADMIN_USER}" \
  --admin-password "${TOKEN}" \
  --database-name "${PG_DATABASE}" \
  --querytext "GRANT CONNECT ON DATABASE \"${PG_DATABASE}\" TO \"${MI_NAME}\"; GRANT USAGE ON SCHEMA public TO \"${MI_NAME}\"; GRANT CREATE ON SCHEMA public TO \"${MI_NAME}\"; GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO \"${MI_NAME}\"; GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO \"${MI_NAME}\"; ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO \"${MI_NAME}\";"

echo "Done."
