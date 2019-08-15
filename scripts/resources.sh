#!/bin/bash
if [[ $# -ne 2 ]]
    then
        echo "Please provide arguments in the format './resources.sh <RESOURCEGROUP> <LOCATION>'"
        exit 1
fi
subscriptionId=$(az account show | jq -r '.id')

resourceGroup=$1
location=$2
echo "Creating resource group..." 
az group create --name $resourceGroup --location $location

echo "Creating managed identity..."
az group deployment create --name "MIDeployment"$resourceGroup --resource-group $resourceGroup \
     --template-file ./templates/mitemplate.json > mioutputs.json

principalId=$(cat mioutputs.json | jq -r '.properties.outputs.principalId.value')
miname=$(cat mioutputs.json | jq -r '.properties.outputs.miname.value')
ADLSGen2StorageName=$(cat mioutputs.json | jq -r '.properties.outputs.adls.value')
# for hierarchical namespace argument
az extension add --name storage-preview

echo "Deploying ADLS Gen2 Storage Account called "$ADLSGen2StorageName
az storage account create --name $ADLSGen2StorageName\
    --resource-group $resourceGroup \
    --location $location --sku Standard_LRS \
    --kind StorageV2 --hierarchical-namespace true

echo "Assigning Role to Managed Identity"
sleep 20s
az role assignment create --role "Storage Blob Data Contributor" \
--assignee $principalId --scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Storage/storageAccounts/$ADLSGen2StorageName"

echo "Deploying ETL resources..."
echo "Deploying Blob Storage Account"
echo "Deploying VNET"
echo "Deploying Network Security Group"
echo "Deploying Spark Cluster"
echo "Deploying LLAP cluster"
echo "Note: Cluster creation can take around 20 minutes"
az group deployment create --name "ResourcesDeployment"$resourceGroup \
    --resource-group $resourceGroup \
    --template-file ./templates/resourcestemplate.json \
    --parameters ADLSGen2storageName=$ADLSGen2StorageName > resourcesoutputs.json


blobStorageName=$(cat resourcesoutputs.json | jq -r '.properties.outputs.blobStorageName.value')

echo "Uploading data to blob storage..."
az storage blob upload-batch -d rawdata \
    --account-name $blobStorageName -s ./ --pattern *.csv

rm mioutputs.json
rm resourcesoutputs.json
echo "Done"
