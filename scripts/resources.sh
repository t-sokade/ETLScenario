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
az group deployment create --name MIDeployment --resource-group $resourceGroup \
     --template-file ./templates/mitemplate.json > mioutputs.json

principalId=$(cat mioutputs.json | jq -r '.properties.outputs.principalId.value')


sleep 20s
echo "Deploying ETL resources..."
az group deployment create --name ResourcesDeployment \
    --resource-group $resourceGroup \
    --template-file ./templates/resourcestemplate.json \
    --parameters principalId=$principalId

rm mioutputs.json
echo "Done"