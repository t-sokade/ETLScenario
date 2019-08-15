#!/bin/bash
echo "Creating service principal"

subscriptionId=$(az account show | jq -r '.id')

az ad sp create-for-rbac --role "Storage Blob Data Contributor" --scope \
    "subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Storage/storageAccounts/$ADLSGen2StorageName" \
    > serviceprincipal.json

echo "Filling in storage name in spark script..."
CLIENT_ID=$(cat serviceprincipal.json | jq -r ".appId")
CLIENT_SECRET=$(cat serviceprincipal.json | jq -r ".password")
TENANT_NAME=$(cat serviceprincipal.json | jq -r ".tenant")