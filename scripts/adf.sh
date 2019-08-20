#!/bin/bash
echo "Creating service principal"

subscriptionId=$(az account show | jq -r '.id')

if [ -z "$resourceGroup" ]
then 
    echo "Please input the name of your resource group here"
    read resourceGroup
fi

if [ -z "$ADLSGen2StorageName" ]
then 
    echo "Please input the name of your ADLS Gen2 Storage Account. Here are the storage accounts in this resource group."
    az resource list --resource-group $resourceGroup --resource-type Microsoft.Storage/storageAccounts | jq '.[].name'
    read ADLSGen2StorageName
fi

if [ -z "$blobStorageName" ]
then 
    echo "Please input the name of your Blob Storage Account. Here are the storage accounts in this resource group."
    az resource list --resource-group $resourceGroup --resource-type Microsoft.Storage/storageAccounts | jq '.[].name'
    read blobStorageName
fi

az ad sp create-for-rbac --role "Storage Blob Data Contributor" --scope \
    "subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Storage/storageAccounts/$ADLSGen2StorageName" \
    > serviceprincipal.json

CLIENT_ID=$(cat serviceprincipal.json | jq -r ".appId")
CLIENT_SECRET=$(cat serviceprincipal.json | jq -r ".password")
TENANT_NAME=$(cat serviceprincipal.json | jq -r ".tenant")

# get authorization token
echo "Getting authorization token..."
ACCESS_TOKEN=$(curl -X POST -H "Content-Type: application/x-www-form-urlencoded" --data-urlencode "client_id=$CLIENT_ID" \
    --data-urlencode "client_secret=$CLIENT_SECRET" --data-urlencode "scope=https://storage.azure.com/.default" --data-urlencode \
    "grant_type=client_credentials" "https://login.microsoftonline.com/$TENANT_NAME/oauth2/v2.0/token" | jq -r ".access_token")
echo $ACCESS_TOKEN
counter=10
until [ $counter -eq 1 ] || [ "$ACCESS_TOKEN" != "null" ]; do
    counter=$(( $counter - 1))
    sleep 15s
    ACCESS_TOKEN=$(curl -X POST -H "Content-Type: application/x-www-form-urlencoded" --data-urlencode "client_id=$CLIENT_ID" \
    --data-urlencode "client_secret=$CLIENT_SECRET" --data-urlencode "scope=https://storage.azure.com/.default" --data-urlencode \
    "grant_type=client_credentials" "https://login.microsoftonline.com/$TENANT_NAME/oauth2/v2.0/token" | jq -r ".access_token")
    echo $ACCESS_TOKEN
done

if [ "$ACCESS_TOKEN" == "null" ]
then
    echo "Unable to obtain ACCESS_TOKEN"
    exit 1
fi 
# create files FS
# While loop to give role assignment time to propagate. 
# Continue trying to create FileSystem until the role assignment is successful
echo "Creating FileSystem"
counter=10
response=$(curl -s -o -I -w "%{http_code}" -i -X PUT -H "x-ms-version: 2018-11-09" -H "content-length: 0" -H "Authorization: Bearer $ACCESS_TOKEN" "https://$ADLSGen2StorageName.dfs.core.windows.net/files?resource=filesystem")
until [ $counter -eq 1 ] || [ "$response" -eq "201" ]; do
    counter=$(( $counter - 1))
    sleep 60s
    echo "Waiting on access to storage account...Trying again."
    response=$(curl -s -o -I -w "%{http_code}" -i -X PUT -H "x-ms-version: 2018-11-09" -H "content-length: 0" -H "Authorization: Bearer $ACCESS_TOKEN" "https://$ADLSGen2StorageName.dfs.core.windows.net/files?resource=filesystem")
    echo "Response code for FileSystem create request: "$response
done
if [ $response -eq "201" ]; then
    echo "FileSystem created"
else
    echo "Unable to create FileSystem" 
    exit 1
fi

curl -i -X PATCH -H "x-ms-version: 2018-11-09" -H "content-length: 0" -H "x-ms-acl: user::rwx,group::r-x,other::--x,default:user::rwx,default:group::r-x,default:other::--x" -H "Authorization: Bearer $ACCESS_TOKEN" "https://$ADLSGen2StorageName.dfs.core.windows.net/files/?action=setAccessControl"

# create correct folder structure
echo "Creating folder structure..."
curl -i -X PUT -H "x-ms-version: 2018-11-09" -H "content-length: 0" -H "Authorization: Bearer $ACCESS_TOKEN" "https://$ADLSGen2StorageName.dfs.core.windows.net/files/data?resource=directory"
curl -i -X PUT -H "x-ms-version: 2018-11-09" -H "content-length: 0" -H "Authorization: Bearer $ACCESS_TOKEN" "https://$ADLSGen2StorageName.dfs.core.windows.net/files/transformed?resource=directory"
curl -i -X PUT -H "x-ms-version: 2018-11-09" -H "content-length: 0" -H "Authorization: Bearer $ACCESS_TOKEN" "https://$ADLSGen2StorageName.dfs.core.windows.net/files/adf?resource=directory"
curl -i -X PUT -H "x-ms-version: 2018-11-09" -H "content-length: 0" -H "Authorization: Bearer $ACCESS_TOKEN" "https://$ADLSGen2StorageName.dfs.core.windows.net/files/adf/files?resource=directory"
curl -i -X PUT -H "x-ms-version: 2018-11-09" -H "content-length: 0" -H "Authorization: Bearer $ACCESS_TOKEN" "https://$ADLSGen2StorageName.dfs.core.windows.net/files/adf/pyFiles?resource=directory"
curl -i -X PUT -H "x-ms-version: 2018-11-09" -H "content-length: 0" -H "Authorization: Bearer $ACCESS_TOKEN" "https://$ADLSGen2StorageName.dfs.core.windows.net/files/adf/jars?resource=directory"
curl -i -X PUT -H "x-ms-version: 2018-11-09" -H "content-length: 0" -H "Authorization: Bearer $ACCESS_TOKEN" "https://$ADLSGen2StorageName.dfs.core.windows.net/files/adf/archives?resource=directory"
curl -i -X PUT -H "x-ms-version: 2018-11-09" -H "content-length: 0" -H "Authorization: Bearer $ACCESS_TOKEN" "https://$ADLSGen2StorageName.dfs.core.windows.net/files/adf/logs?resource=directory"
curl -i -X PUT -H "x-ms-version: 2018-11-09" -H "content-length: 0" -H "Authorization: Bearer $ACCESS_TOKEN" "https://$ADLSGen2StorageName.dfs.core.windows.net/files/adf/sparktransform.py?resource=file"
echo "Folder structure created" 

# create the sparktransform.py file
# replace <ADLS GEN2 STORAGE NAME> with actual name
echo "Creating sparktransform file..."
sed -i -e 's/<ADLS GEN2 STORAGE NAME>/'$ADLSGen2StorageName'/g' ./scripts/sparktransform.py

cat ./scripts/sparktransform.py | curl -i -X PATCH -H "x-ms-version: 2018-11-09" -H "Authorization: Bearer $ACCESS_TOKEN" --data-binary @- "https://$ADLSGen2StorageName.dfs.core.windows.net/files/adf/sparktransform.py?action=append&position=0"
curl -i -H "x-ms-version: 2018-11-09" -H "Authorization: Bearer $ACCESS_TOKEN" "https://$ADLSGen2StorageName.dfs.core.windows.net/files/adf/sparktransform.py"
FILENUM=$(wc -c < ./scripts/sparktransform.py)
curl -i -X PATCH -H "x-ms-version: 2018-11-09" -H "content-length: 0" -H "Authorization: Bearer $ACCESS_TOKEN" "https://$ADLSGen2StorageName.dfs.core.windows.net/files/adf/sparktransform.py?action=flush&position=$FILENUM"

echo "Obtaining storage keys..."
az storage account keys list \
    --account-name $ADLSGen2StorageName \
    --resource-group $resourceGroup > adlskeys.json
echo "ADLS Key obtained..."
az storage account keys list \
    --account-name $blobStorageName \
    --resource-group $resourceGroup > blobkeys.json
echo "Blob key obtained..."
adlskey=$(cat adlskeys.json | jq -r '.[0].value')
blobkey=$(cat blobkeys.json | jq -r '.[0].value')

echo "Deploying ADF..."
az group deployment create --name "ADFDeployment"$resourceGroup \
    --resource-group $resourceGroup \
    --template-file ./templates/adftemplate.json \
    --parameters AzureDataLakeStorage1_accountKey=$adlskey AzureBlobStorage1_accountKey=$blobkey
echo "ADF deployed"
rm serviceprincipal.json
rm blobkeys.json
rm adlskeys.json