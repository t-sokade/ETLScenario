#!/bin/bash
if [[ $# -ne 2 ]]
    then
        echo "Please provide a resourcegroup and a location" 
        echo "Enter resource group name"
        read resourceGroup
        echo "Enter location (for example, westus)"
        read location
else 
    resourceGroup=$1
    location=$2
fi
subscriptionId=$(az account show | jq -r '.id')


echo "Creating resource group..." 
az group create --name $resourceGroup --location $location

echo "Deploying ETL resources..."
echo "Deploying Blob Storage Account"
echo "Deploying ADLS Gen2 Account"
echo "Deploying Managed Identity"
echo "Assigning role to Managed Identity"
echo "Deploying VNET"
echo "Deploying Network Security Group"
echo "Deploying Spark Cluster"
echo "Deploying LLAP cluster"
echo "Note: Cluster creation can take around 20 minutes"
az group deployment create --name "ResourcesDeployment"$resourceGroup \
    --resource-group $resourceGroup \
    --template-file ./templates/resourcestemplate.json > resourcesoutputs.json


blobStorageName=$(cat resourcesoutputs.json | jq -r '.properties.outputs.blobStorageName.value')
ADLSGen2StorageName=$(cat resourcesoutputs.json | jq -r '.properties.outputs.adlsGen2StorageName.value')

echo "Uploading data to blob storage..."
az storage blob upload-batch -d rawdata \
    --account-name $blobStorageName -s ./ --pattern *.csv

rm resourcesoutputs.json
echo "Done"
