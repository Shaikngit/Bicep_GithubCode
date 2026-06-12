#!/usr/bin/env bash
set -euo pipefail

RESOURCE_GROUP="rg-mtu-lab-eastus2"

if ! command -v az >/dev/null 2>&1; then
  echo "Azure CLI is required but was not found in PATH."
  exit 1
fi

if ! az account show >/dev/null 2>&1; then
  echo "Azure CLI is not logged in. Run: az login"
  exit 1
fi

echo "Deleting resource group ${RESOURCE_GROUP}..."
az group delete --name "${RESOURCE_GROUP}" --yes --no-wait

echo "Deletion started in background. Use this command to monitor:"
echo "az group show --name ${RESOURCE_GROUP}"
