#!/usr/bin/env bash
set -euo pipefail

RESOURCE_GROUP="rg-mtu-lab-eastus2"
LOCATION="eastus2"
TEMPLATE_FILE="main.bicep"
PARAM_FILE="parameters.json"
DEPLOYMENT_NAME="mtu-lab-$(date +%Y%m%d-%H%M%S)"

if ! command -v az >/dev/null 2>&1; then
  echo "Azure CLI is required but was not found in PATH."
  exit 1
fi

if ! az account show >/dev/null 2>&1; then
  echo "Azure CLI is not logged in. Run: az login"
  exit 1
fi

echo "Ensuring Bicep CLI is available..."
az bicep install >/dev/null

if [[ ! -f "${TEMPLATE_FILE}" ]]; then
  echo "Template file not found: ${TEMPLATE_FILE}"
  exit 1
fi

if [[ ! -f "${PARAM_FILE}" ]]; then
  echo "Parameter file not found: ${PARAM_FILE}"
  exit 1
fi

echo "Creating resource group ${RESOURCE_GROUP} in ${LOCATION}..."
az group create --name "${RESOURCE_GROUP}" --location "${LOCATION}" --output none

echo "Starting deployment ${DEPLOYMENT_NAME}..."
az deployment group create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${DEPLOYMENT_NAME}" \
  --template-file "${TEMPLATE_FILE}" \
  --parameters "@${PARAM_FILE}" \
  --output json > deployment-outputs.json

echo "Deployment complete. Key outputs:"
az deployment group show \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${DEPLOYMENT_NAME}" \
  --query "properties.outputs" \
  --output table

echo "Saved full deployment response to deployment-outputs.json"

echo "Source public IP:"
az deployment group show \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${DEPLOYMENT_NAME}" \
  --query "properties.outputs.sourceVmPublicIp.value" \
  --output tsv
