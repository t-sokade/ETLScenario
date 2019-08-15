#!/bin/bash
# create service principal, assign role, save variables
STORAGE_ACCOUNT_NAME=$ADLSGen2StorageName

./scripts/serviceprincipal.sh

echo "Filling in storage name in spark script..."
sed -i -e 's/<ADLS GEN2 STORAGE NAME>/'$ADLSGen2StorageName'/g' ./scripts/sparktransform.py

CLIENT_ID=$(cat serviceprincipal.json | jq -r ".appId")
CLIENT_SECRET=$(cat serviceprincipal.json | jq -r ".password")
TENANT_NAME=$(cat serviceprincipal.json | jq -r ".tenant")

# get authorization token
echo "Getting authorization token..."
ACCESS_TOKEN=$(curl -X POST -H "Content-Type: application/x-www-form-urlencoded" --data-urlencode "client_id=$CLIENT_ID" \
--data-urlencode "client_secret=$CLIENT_SECRET" --data-urlencode "scope=https://storage.azure.com/.default" --data-urlencode \
"grant_type=client_credentials" "https://login.microsoftonline.com/$TENANT_NAME/oauth2/v2.0/token" | jq -r ".access_token")

#create files FS
echo "Creating FileSystem"
curl -i -X PUT -H "x-ms-version: 2018-11-09" -H "content-length: 0" -H "Authorization: Bearer $ACCESS_TOKEN" "https://$STORAGE_ACCOUNT_NAME.dfs.core.windows.net/files?resource=filesystem"
curl -i -X PATCH -H "x-ms-version: 2018-11-09" -H "content-length: 0" -H "x-ms-acl: user::rwx,group::r-x,other::--x,default:user::rwx,default:group::r-x,default:other::--x" -H "Authorization: Bearer $ACCESS_TOKEN" "https://$STORAGE_ACCOUNT_NAME.dfs.core.windows.net/files/?action=setAccessControl"

# create correct folder structure
echo "Creating folder structure..."
curl -i -X PUT -H "x-ms-version: 2018-11-09" -H "content-length: 0" -H "Authorization: Bearer $ACCESS_TOKEN" "https://$STORAGE_ACCOUNT_NAME.dfs.core.windows.net/files/data?resource=directory"
curl -i -X PUT -H "x-ms-version: 2018-11-09" -H "content-length: 0" -H "Authorization: Bearer $ACCESS_TOKEN" "https://$STORAGE_ACCOUNT_NAME.dfs.core.windows.net/files/transformed?resource=directory"
curl -i -X PUT -H "x-ms-version: 2018-11-09" -H "content-length: 0" -H "Authorization: Bearer $ACCESS_TOKEN" "https://$STORAGE_ACCOUNT_NAME.dfs.core.windows.net/files/adf?resource=directory"
curl -i -X PUT -H "x-ms-version: 2018-11-09" -H "content-length: 0" -H "Authorization: Bearer $ACCESS_TOKEN" "https://$STORAGE_ACCOUNT_NAME.dfs.core.windows.net/files/adf/files?resource=directory"
curl -i -X PUT -H "x-ms-version: 2018-11-09" -H "content-length: 0" -H "Authorization: Bearer $ACCESS_TOKEN" "https://$STORAGE_ACCOUNT_NAME.dfs.core.windows.net/files/adf/pyFiles?resource=directory"
curl -i -X PUT -H "x-ms-version: 2018-11-09" -H "content-length: 0" -H "Authorization: Bearer $ACCESS_TOKEN" "https://$STORAGE_ACCOUNT_NAME.dfs.core.windows.net/files/adf/jars?resource=directory"
curl -i -X PUT -H "x-ms-version: 2018-11-09" -H "content-length: 0" -H "Authorization: Bearer $ACCESS_TOKEN" "https://$STORAGE_ACCOUNT_NAME.dfs.core.windows.net/files/adf/archives?resource=directory"
curl -i -X PUT -H "x-ms-version: 2018-11-09" -H "content-length: 0" -H "Authorization: Bearer $ACCESS_TOKEN" "https://$STORAGE_ACCOUNT_NAME.dfs.core.windows.net/files/adf/logs?resource=directory"
curl -i -X PUT -H "x-ms-version: 2018-11-09" -H "content-length: 0" -H "Authorization: Bearer $ACCESS_TOKEN" "https://$STORAGE_ACCOUNT_NAME.dfs.core.windows.net/files/adf/sparktransform.py?resource=file"

# create the sparktransform.py file
echo "Creating sparktransform file..."
cat ./scripts/sparktransform.py | curl -i -X PATCH -H "x-ms-version: 2018-11-09" -H "Authorization: Bearer $ACCESS_TOKEN" --data-binary @- "https://$STORAGE_ACCOUNT_NAME.dfs.core.windows.net/files/adf/sparktransform.py?action=append&position=0"
curl -i -H "x-ms-version: 2018-11-09" -H "Authorization: Bearer $ACCESS_TOKEN" "https://$STORAGE_ACCOUNT_NAME.dfs.core.windows.net/files/adf/sparktransform.py"
FILENUM=$(wc -c < ./scripts/sparktransform.py)
curl -i -X PATCH -H "x-ms-version: 2018-11-09" -H "content-length: 0" -H "Authorization: Bearer $ACCESS_TOKEN" "https://$STORAGE_ACCOUNT_NAME.dfs.core.windows.net/files/adf/sparktransform.py?action=flush&position=$FILENUM"

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
az group deployment create --name "ADFDeployment"$resourceGroup \
    --resource-group $resourceGroup \
    --template-file ./templates/adftemplate.json \
    --parameters AzureDataLakeStorage1_accountKey=$adlskey AzureBlobStorage1_accountKey=$blobkey
echo "done"
rm serviceprincipal.json
rm blobkeys.json
rm adlskeys.json