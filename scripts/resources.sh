#!/bin/bash
if [[ $# -ne 2 ]]
    then
        echo "Please provide arguments in the format './resources.sh <RESOURCEGROUP> <LOCATION>'"
        exit 1
fi
resourceGroup=$1
location=$2
echo "Creating resource group..." 
az group create --name $resourceGroup --location $location

echo "Creating managed identity..."
randomstring=$(date | md5sum)
az group deployment create --name "MIDeployment"+$randomstring --resource-group $resourceGroup \
     --template-file ./templates/mitemplate.json > mioutputs.json

principalId=$(cat mioutputs.json | jq -r '.properties.outputs.principalId.value')


sleep 20s
echo "Deploying ETL resources..."
az group deployment create --name "ResourcesDeployment"+randomstring \
    --resource-group $resourceGroup \
    --template-file ./templates/resourcestemplate.json \
    --parameters principalId=$principalId > resourcesoutputs.json

blobStorageName=$(cat resourcesoutputs.json | jq -r '.properties.outputs.blobStorageName.value')
ADLSGen2StorageName=$(cat resourcesoutputs.json | jq -r '.properties.outputs.ADLSGen2StorageName.value')

echo "Uploading data to blob storage..."
az storage blob upload-batch -d rawdata \
    --account-name $blobStorageName -s ./ --pattern *.csv

rm mioutputs.json
rm resourcesoutputs.json
echo "Done"