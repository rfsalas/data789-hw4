#!/usr/bin/env bash
set -euo pipefail
# ─────────────────────────────────────────────────────────────────────────────
# DATA 789 · HW4 FLOOR (required) — import the provided Project 2 fraud image into
# Azure Container Registry and run it on Azure Container Apps, giving a public URL.
#
# Best run in AZURE CLOUD SHELL (https://shell.azure.com): already signed in, has az.
# The image is pre-built and public, so there's nothing to build — we just import it.
#
# NOTE: this floor runs the API container ALONE (no Redis). /health and /predict both
# work here — /predict scores without customer-history features (the app falls back
# gracefully). The full feature store (Redis) is part of the local-Kubernetes deploy.
#
# Cost: scale-to-zero + same-day teardown ⇒ ~$0 inside the Container Apps free grant.
# Auth: AAD/RBAC only — ACR admin user disabled; the app pulls via a managed identity.
# ─────────────────────────────────────────────────────────────────────────────
source "$(dirname "$0")/config.env"

SUFFIX="$(echo "${USER:-$RANDOM}" | tr -cd 'a-z0-9' | cut -c1-12)"  # unique-per-student
LOCATION="centralus"                         # course default — do NOT use eastus/eastus2
RG="rg-data789-hw4-${SUFFIX}"
ACR_NAME="$(echo "acrdata789hw4${SUFFIX}" | cut -c1-50)"   # 5-50 lower-alnum, globally unique
ENV_NAME="cae-data789-hw4"
APP_NAME="trustbank-fraud"
TAG="v1"

echo "▶ subscription : $(az account show --query name -o tsv 2>/dev/null || { echo 'NOT LOGGED IN — run: az login'; exit 1; })"
echo "▶ region       : $LOCATION"
echo "▶ source image : $IMAGE"
echo

echo "▶ registering resource providers (idempotent)…"
az provider register -n Microsoft.App --wait
az provider register -n Microsoft.ContainerRegistry --wait
az provider register -n Microsoft.OperationalInsights --wait

echo "▶ creating resource group…"
az group create -n "$RG" -l "$LOCATION" -o none

echo "▶ creating registry (Basic, admin user disabled — AAD auth only)…"
az acr create -n "$ACR_NAME" -g "$RG" --sku Basic --admin-enabled false -o none

echo "▶ importing the provided public image into your registry (no build, no keys)…"
az acr import -n "$ACR_NAME" --source "$IMAGE" --image "${APP_NAME}:${TAG}"
FULL_IMAGE="${ACR_NAME}.azurecr.io/${APP_NAME}:${TAG}"

echo "▶ creating Container Apps environment…"
az containerapp env create -n "$ENV_NAME" -g "$RG" -l "$LOCATION" -o none

echo "▶ deploying the container app (system identity + AcrPull, scale-to-zero)…"
az containerapp create \
  -n "$APP_NAME" -g "$RG" --environment "$ENV_NAME" \
  --image "$FULL_IMAGE" \
  --registry-server "${ACR_NAME}.azurecr.io" \
  --registry-identity system \
  --target-port "$CONTAINER_PORT" --ingress external \
  --cpu 0.25 --memory 0.5Gi \
  --min-replicas 0 --max-replicas 3 \
  -o none

FQDN="$(az containerapp show -n "$APP_NAME" -g "$RG" \
        --query properties.configuration.ingress.fqdn -o tsv)"

echo
echo "✅ deployed. Your fraud API is live in the cloud — try it:"
echo "      curl https://${FQDN}${HEALTH_PATH}       # → {\"status\":\"ok\"}"
echo "      curl -s -X POST https://${FQDN}${PREDICT_PATH} \\"
echo "        -H 'Content-Type: application/json' \\"
echo "        -d '{\"transaction_id\":\"t1\",\"customer_id\":\"CUST0001\",\"amount\":1500,\"merchant_category\":\"online_retail\",\"is_online\":true,\"timestamp\":\"2026-01-01T00:50:00Z\"}'"
echo "      # → a fraud decision  ← screenshot this"
echo
echo "   ⚠️  capture your screenshot, then TEAR DOWN SAME DAY:"
echo "      ./teardown_azure.sh"
echo
# ── TROUBLESHOOTING — first revision failed to pull? (AcrPull still propagating) ──
#   PRINCIPAL="$(az containerapp show -n "$APP_NAME" -g "$RG" --query identity.principalId -o tsv)"
#   ACR_ID="$(az acr show -n "$ACR_NAME" -g "$RG" --query id -o tsv)"
#   az role assignment create --assignee "$PRINCIPAL" --role AcrPull --scope "$ACR_ID"
#   sleep 60   # let RBAC propagate
#   az containerapp revision restart -n "$APP_NAME" -g "$RG" \
#     --revision "$(az containerapp revision list -n "$APP_NAME" -g "$RG" --query '[0].name' -o tsv)"
