#!/usr/bin/env bash
# Run at the start of EVERY KodeKloud Azure playground session (the sandbox is
# recycled when the session ends). Takes about 2-3 minutes.
#
# Copy these from the playground start page first:
#   export ARM_CLIENT_ID=...  ARM_CLIENT_SECRET=...  ARM_TENANT_ID=...
#   export ARM_SUBSCRIPTION_ID=...  RESOURCE_GROUP=kml_rg_main_...
# Usage: scripts/sandbox-up.sh <owner/repo>
set -euo pipefail
REPO="${1:?usage: sandbox-up.sh <owner/repo>}"
: "${ARM_CLIENT_ID:?}" "${ARM_CLIENT_SECRET:?}" "${ARM_TENANT_ID:?}" "${ARM_SUBSCRIPTION_ID:?}" "${RESOURCE_GROUP:?}"

az login --service-principal -u "$ARM_CLIENT_ID" -p "$ARM_CLIENT_SECRET" --tenant "$ARM_TENANT_ID" -o none
az account set -s "$ARM_SUBSCRIPTION_ID"
LOCATION=$(az group show -n "$RESOURCE_GROUP" --query location -o tsv)
APP="vibe2prod-$(python3 -c 'import secrets; print(secrets.token_hex(3))')"

echo "Creating App Service plan (B1, Linux) and web app $APP in $LOCATION..."
az appservice plan create -g "$RESOURCE_GROUP" -n "$APP-plan" --is-linux --sku B1 -l "$LOCATION" -o none
az webapp create -g "$RESOURCE_GROUP" -p "$APP-plan" -n "$APP" --runtime "PYTHON:3.12" -o none
az webapp config set -g "$RESOURCE_GROUP" -n "$APP" -o none \
  --startup-file "gunicorn -w 2 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000 main:app"
az webapp config appsettings set -g "$RESOURCE_GROUP" -n "$APP" -o none --settings \
  SCM_DO_BUILD_DURING_DEPLOYMENT=true WEBSITES_PORT=8000 DB_PATH=/home/orders.db \
  ADMIN_TOKEN="$(python3 -c 'import secrets; print(secrets.token_urlsafe(24))')"
az webapp update -g "$RESOURCE_GROUP" -n "$APP" --https-only true -o none

echo "Wiring GitHub to this session's sandbox..."
printf '{"clientId":"%s","clientSecret":"%s","subscriptionId":"%s","tenantId":"%s"}' \
  "$ARM_CLIENT_ID" "$ARM_CLIENT_SECRET" "$ARM_SUBSCRIPTION_ID" "$ARM_TENANT_ID" \
  | gh secret set AZURE_CREDENTIALS -R "$REPO" --env production
gh variable set AZURE_WEBAPP_NAME -R "$REPO" -b "$APP"

echo
echo "Ready: https://$APP.azurewebsites.net"
echo "Deploy current main now (approve it in the Actions tab):"
echo "  gh workflow run deploy -R $REPO"
