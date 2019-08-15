#!/bin/bash
echo "Creating service principal"
subscriptionId=$(az account show | jq -r '.id')
az ad sp create-for-rbac --role "Storage Blob Data Contributor" --scope \
    "subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Storage/storageAccounts/$ADLSGEN2StorageName" \
    > serviceprincipal.json