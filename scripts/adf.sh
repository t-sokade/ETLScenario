#!/bin/bash
echo "Obtaining storage keys..."
az storage account keys list \
    --account-name $ADLSGen2StorageName \
    --resource-group $resourceGroup > adlskeys.json

az storage account keys list \
    --account-name $blobStorageName \
    --resource-group $resourceGroup > blobkeys.json

adlskey=$(cat adlskeys.json | jq -r '.[0].value')
blobkey=$(cat blobkeys.json | jq -r '.[0].value')

randomstring=$(date | md5sum)
echo "Deploying ADF..."
az group deployment create --name "ADFDeployment"+$randomstring \
    --resource-group $resourceGroup \
    --template-file ./templates/adftemplate.json \
    --parameters AzureDataLakeStorage1_accountKey=$adlskey AzureBlobStorage1_accountKey=$blobkey
echo "done"