# End to End Extract Transform and Load (ETL) Pipeline using Azure HDInsight: 

Consider this: you're a large company with stores all across the world that sells many products in different departments. You have large amounts of sales data from the different stores and would like to see revenue trends and other business insights from it. After looking into Microsoft’s Azure HDInsight, you think it might be a great tool to understanding data associated with the company. 

You decide to build an ETL pipeline using Azure services. This pipeline combines the data from all your different stores, removes any unwanted data, appends new data, and loads this back to your storage to visualize business insights. Read more about ETL pipelines [here](https://docs.microsoft.com/en-us/azure/hdinsight/hadoop/apache-hadoop-etl-at-scale). 

You also see that you can build out this entire pipeline using Azure products, with HDInsight being the primary mode for data transformations. Given the large volume of data associated with the multitudes of stores, a big data product like HDInsight provides the perfect solution to transforming and analyzing this data quickly and at scale. 

![alt text](./media/architecture.png)
### Overview

In this tutorial you will build an end to end ETL pipeline. The pipeline will use an ADLS Gen2 Storage account, a Spark HDInsight cluster to apply transformations, an Interactive Query HDInsight cluster for quick querying and business insight visualization on Power BI. 

### Prerequisites

If you don't have an Azure subscription, create a [free account](https://azure.microsoft.com/free/) before you begin.

Download [Power BI Desktop](https://www.microsoft.com/en-us/download/details.aspx?id=45331) to visualize business insights at the end of this tutorial. 

#### Sign into Azure

Through the Azure portal, open the Cloud Shell from the top menu bar. Log into your Azure account and set the subscription. 

```azurecli-interactive 
az login
az account set --subscription <SUBSCRIPTION ID>
```
#### Download relevant files for this project

Clone this [git hub repository]() and `cd` into the folder.  

- `/salesdata/`
- `/templates/`
    - `resourcestemplate.json`, `resourcesparameters.json`
    - `adftemplate.json`, `adfparameters.json`
- `/scripts/`
    - `resources.sh` 
    - `sparktransform.py` 
    - `adlsgen2script.sh`
    - `adf.sh`

Navigate to this directory on your Azure CLI. 

## Deploy Azure resources needed for the pipeline 

This section will deploy the following resources: 
1. Azure Blob Storage - to mimic your company's storage of raw data
2. ADLS Gen2 Storage - the storage account for both HDInsight clusters. Read more about HDInsight and ADLS Gen 2 storage [here](https://azure.microsoft.com/en-us/blog/azure-hdinsight-integration-with-data-lake-storage-gen-2-preview-acl-and-security-update/).
3. Managed Identity - to give clusters access to the storage account
4. Spark Cluster - to clean up and transform the raw data
5. Interactive Query Cluster - to allow quick querying and data visualization on Power BI
6. VNET supported by NSG rules - to provide security to your clusters 

The `resourcestemplate.json` Resource Manager Template configures all the above resources. The default password used for ssh access to the clusters is `Thisisapassword1`. If you'd like to change the password navigate to `resourcesparameters.json` file and change the password for the `sparksshPassword`, `sparkClusterLoginPassword`, `llapClusterLoginPassword`, `llapsshPassword` parameters. 

Run the resource script to deploy the resources and to upload data to the blob storage account. Type in your own unique resource group name as the first argument, and the location of the resource group as the second argument (for example `'westus'`). Include the first `.` so that variables set in this script propogate to the shell. 

```azurecli-interactive 
. ./scripts/resources.sh "<RESOURCEGROUPNAME>" "<LOCATION>" 
```
To check on your deployment progress in the Azure portal, navigate to your resource group. Then click where it says Deployments as shown below.

![alt text](media/deployment.png)
 
Note: Cluster creation can take around 20 minutes. 
 
To verify this step worked correctly, go to the resource group on the azure portal and check all the outlined resources were deployed. You can also check that the data is uploaded to the Blob Storage account. 

## Create an Azure Data Factory

Azure Data Factory is a tool that helps automate Azure Pipelines. It's not the only way to accomplish these tasks, but it's a great way to automate these processes. Read more about it [here](https://azure.microsoft.com/en-us/services/data-factory/). 

This Azure Data Factory will do 2 things: 

1. It will copy the data from the Azure Blob Storage to the ADLS Gen 2 Storage Account to mimic data ingestion. 
2. It will transform the data using spark by removing unwanted columns as well as appending a new column that calculates the revenue generated by a single transaction.

In `sparktransform.py`, fill in the ADLS Gen2 storage account name within the angle brackets. 

Run `adlsgen2script.sh` with the following arguments. This creates a service principal with  Storage Blob Data Contributor permissions on the ADLS Gen2 storage account. It then obtains an authentication token to authorize POST requests to the [ADLS Gen2 FileSystem REST API](https://docs.microsoft.com/en-us/rest/api/storageservices/datalakestoragegen2/filesystem/create)

```
./adlsgen2script.sh $t"<SUBSCRIPTION ID>" $resourceGroup $ADLSGen2StorageName
```
Deploy the ADF by running the adf script. 

```azurecli-interactive 
. ./adf.sh
```

### Trigger the Pipeline
You can either trigger the ADF pipeline with the following command: 

```powershell
Invoke-AzDataFactoryV2Pipeline -DataFactory "<DATA FACTORY NAME>" -PipelineName "IngestAndTransform" 
```

Or you can also open the Data Factory, select Author & Monitor, and trigger the copy pipeline, then the spark pipeline from the portal. [Here](https://docs.microsoft.com/en-us/azure/hdinsight/hdinsight-hadoop-create-linux-clusters-adf#trigger-a-pipeline) is a tutorial that shows you how to trigger pipelines from the portal. 

To verify that the pipelines executed you can either 
1. Navigate to the monitor section on ADF through the portal. 
2. Go to your ADLS Gen 2 storage account storage explorer, go to the `files` FileSystem, and navigate to the `transformed` folder and check its contents to see if the pipeline succeeded.

For other ways to transform data using HDInsight check out this article on using [Jupyter notebook](https://docs.microsoft.com/en-us/azure/hdinsight/spark/apache-spark-load-data-run-query)

## Create a table on the Interactive Query cluster to view data on Power BI

Now, SSH into the LLAP cluster using the following command and then enter your password. If you have not altered the `resourcesparameters.json` file this should be `Thisisapassword1`. 

```
ssh sshuser@<clustername>-ssh.azurehdinsight.net
```

Next, create a file that will contain the Hive query to create a table. 
```
nano query.hql
```
Copy the contents below into `query.hql` and substitute your storage account name in the angle brackets. 
```
DROP TABLE sales_raw;
-- Creates an external table over the csv file
CREATE EXTERNAL TABLE sales_raw(
  REGION STRING,
  STORE STRING,
  SALEDATE STRING,
  DEP STRING,
  ITEM STRING,
  UNITSOLD INT,
  UNITPRICE INT,
  REVENUE INT,
  CUSTOMERID INT, 
  LOYALTY BOOLEAN, 
  FIRSTPURCHASE STRING,
  FREQ INT)
--Format and location of the file
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
STORED AS TEXTFILE
LOCATION 'abfs://files@<ADLS GEN2 STORAGE NAME>.dfs.core.windows.net/transformed';
--Drop table sales if exists
DROP TABLE sales;
--Create sales table and populate with data\
--pulled in from csv file (via external table defined previously)
CREATE TABLE sales AS
SELECT REGION AS region,
	STORE as store,
	CAST(SALEDATE as DATE) as saledate, 
	DEP as dep,
	ITEM as item,
	UNITSOLD as unitsold,
	UNITPRICE as unitprice,
	REVENUE as revenue,
	CUSTOMERID as customerID,
	LOYALTY as loyalty,
	FIRSTPURCHASE as firstpurchase,
	FREQ as freq
FROM sales_raw;
```
Run the following command to execute the script
```
beeline -u 'jdbc:hive2://localhost:10001/;transportMode=http' -f query.hql
```

This script will create a table on the Interactive Query cluster that you can access from Power BI. 

Open up Power BI Desktop and select Get Data. Search for HDInsight Interactive Query cluster and paste the URI for your cluster there. It should be in the format `https://<LLAP CLUSTER NAME>.azurehdinsight.net` Type `default` for the database. 

Once the data is loaded, you can experiment with the dashboard you would like to create. Here is an example dashboard with the given data. 

![alt text](./media/dashboard.png)

## Clean up resources

If you're not going to continue to use this application, delete all resources with the following steps so that you are not charged for them. 

```azurecli-interactive 
az group delete -n $resourceGroup
```