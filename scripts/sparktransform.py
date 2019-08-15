from pyspark.sql import SparkSession
from pyspark.sql.functions import col
from pyspark.sql.types import * 

spark = SparkSession.builder.appName("SparkTransform").getOrCreate()
schema = StructType([
    StructField('ordernum', IntegerType(), True),
    StructField('region', StringType(), True),
    StructField('store', StringType(), True),
    StructField('saledate', DateType(), True),
    StructField('dep', StringType(), True),
    StructField('item', StringType(), True),
    StructField('unitsold', IntegerType(), True),
    StructField('unitprice', IntegerType(), True),
    StructField('employeeID', StringType(), True),
    StructField('customerID', StringType(), True),
    StructField('loyalty', BooleanType(), True),
    StructField('firstpurchase', DateType(), True),
    StructField('freq', IntegerType(), True),
    ])
df = spark.read.csv("abfs://files@<ADLS GEN2 STORAGE NAME>.dfs.core.windows.net/data/salesdata/*.csv", schema, header=True)
df = df.drop("employeeID").drop("ordernum")
df = df.withColumn("revenue", col('unitsold')*col('unitprice'))
df.write.format('csv').save("abfs://files@<ADLS GEN2 STORAGE NAME>.dfs.core.windows.net/transformed", mode="overwrite")

spark.stop()
