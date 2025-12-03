# Spark and Dataproc Internals

This document provides an in-depth look at Apache Spark and Google Cloud Dataproc internals, architecture, and how they work together.

---

## Table of Contents

1. [Apache Spark Architecture](#apache-spark-architecture)
2. [Dataproc Architecture](#dataproc-architecture)
3. [How Dataproc Extends Spark](#how-dataproc-extends-spark)
4. [Job Execution Lifecycle](#job-execution-lifecycle)
5. [Resource Management](#resource-management)
6. [Data Processing Internals](#data-processing-internals)
7. [Performance Optimization](#performance-optimization)

---

## Apache Spark Architecture

### Core Components

```
┌─────────────────────────────────────────────────┐
│              Spark Application                   │
├─────────────────────────────────────────────────┤
│                                                  │
│  ┌──────────────┐        ┌─────────────────┐   │
│  │   Driver     │◄──────►│  Cluster        │   │
│  │   Program    │        │  Manager        │   │
│  └──────┬───────┘        └────────┬────────┘   │
│         │                          │            │
│         │      ┌──────────────────┘            │
│         │      │                                │
│         ▼      ▼                                │
│  ┌────────────────────────┐                    │
│  │   Spark Context        │                    │
│  │   (Job Scheduler)      │                    │
│  └──────────┬─────────────┘                    │
│             │                                    │
│   ┌─────────┴──────────┐                       │
│   │                     │                        │
│   ▼                     ▼                        │
│ ┌────────────┐    ┌────────────┐               │
│ │ Executor 1 │    │ Executor 2 │   ... N        │
│ │ ┌────────┐ │    │ ┌────────┐ │               │
│ │ │ Task 1 │ │    │ │ Task 3 │ │               │
│ │ ├────────┤ │    │ ├────────┤ │               │
│ │ │ Task 2 │ │    │ │ Task 4 │ │               │
│ │ └────────┘ │    │ └────────┘ │               │
│ │  Cache     │    │  Cache     │               │
│ └────────────┘    └────────────┘               │
│                                                  │
└─────────────────────────────────────────────────┘
```

### Key Components Explained

#### 1. **Driver**
- **Role**: Orchestrates the entire Spark application
- **Responsibilities**:
  - Converts user code into tasks
  - Schedules tasks on executors
  - Maintains metadata about RDDs/DataFrames
  - Responds to user queries
  - Coordinates with Cluster Manager
  
**In our pipeline:**
```python
# This code runs on the Driver
spark = SparkSession.builder.appName("Phone Number Masking").getOrCreate()
df = spark.read.parquet(input_path)  # Driver plans the read operation
```

#### 2. **Executors**
- **Role**: Worker processes that run tasks and store data
- **Responsibilities**:
  - Execute tasks assigned by driver
  - Store intermediate data in memory/disk
  - Report status back to driver
  - Cache data for future use

**In our pipeline:**
```python
# This transformation is executed on Executors
masked_df = df.withColumn("phone_number", mask_udf(col("phone_number")))
```

#### 3. **Cluster Manager**
- **Role**: Allocates resources across applications
- **Types**:
  - Standalone (simple built-in manager)
  - YARN (Hadoop's resource manager) 
  - Mesos
  - Kubernetes
  - **Dataproc uses YARN**

---

## Dataproc Architecture

### Cluster Components

```
┌───────────────────────────────────────────────────────┐
│                   Dataproc Cluster                     │
├───────────────────────────────────────────────────────┤
│                                                        │
│  ┌──────────────────────────────────────────┐        │
│  │         Master Node(s)                    │        │
│  │  ┌────────────────────────────────────┐  │        │
│  │  │  YARN Resource Manager             │  │        │
│  │  │  HDFS NameNode                     │  │        │
│  │  │  Spark Driver                      │  │        │
│  │  │  Job History Server                │  │        │
│  │  └────────────────────────────────────┘  │        │
│  └─────────────────┬──────────────────────── │        │
│                    │                                   │
│         ┌──────────┴──────────┐                       │
│         │                     │                        │
│  ┌──────▼────────┐    ┌──────▼────────┐              │
│  │ Worker Node 1 │    │ Worker Node 2 │   ...         │
│  │ ┌───────────┐ │    │ ┌───────────┐ │              │
│  │ │YARN Node  │ │    │ │YARN Node  │ │              │
│  │ │Manager    │ │    │ │Manager    │ │              │
│  │ ├───────────┤ │    │ ├───────────┤ │              │
│  │ │HDFS       │ │    │ │HDFS       │ │              │
│  │ │DataNode   │ │    │ │DataNode   │ │              │
│  │ ├───────────┤ │    │ ├───────────┤ │              │
│  │ │Spark      │ │    │ │Spark      │ │              │
│  │ │Executors  │ │    │ │Executors  │ │              │
│  │ └───────────┘ │    │ └───────────┘ │              │
│  └───────────────┘    └───────────────┘              │
│                                                        │
└───────────────────────────────────────────────────────┘
           │                          │
           └────────┬─────────────────┘
                    │
                    ▼
         ┌──────────────────────┐
         │   Google Cloud       │
         │   Storage (GCS)      │
         │   gs://bucket/...    │
         └──────────────────────┘
```

### Dataproc-Specific Components

#### 1. **Google Cloud Integration**
- **GCS Connector**: Direct integration with Cloud Storage
  - Replaces HDFS for persistent storage
  - No data loss when cluster is deleted
  - Better cost efficiency

```python
# Seamlessly read/write from GCS
df = spark.read.parquet("gs://bucket/input")  # GCS instead of HDFS
df.write.parquet("gs://bucket/output")
```

#### 2. **Stackdriver Logging Integration**
- Automatic log collection
- Centralized monitoring
- Integration with Cloud Monitoring

#### 3. **Image Versioning**
- Pre-configured Spark/Hadoop versions
- Consistent environments
- Easy upgrades

#### 4. **Initialization Actions**
- Custom scripts run on cluster creation
- Install additional libraries
- Configure services

---

## How Dataproc Extends Spark

### 1. **Storage Layer Enhancement**

**Traditional Spark:**
```
Spark ──► HDFS ──► Local Disks
```

**Dataproc:**
```
Spark ──► GCS Connector ──► Cloud Storage
       └► HDFS (optional, for temp data)
```

**Advantages:**
- ✓ Separate compute and storage
- ✓ No data loss on cluster deletion
- ✓ Lower storage costs
- ✓ Shared access across clusters

### 2. **Resource Management**

**Dataproc adds:**
- Auto-scaling workers
- Preemptible (spot) instances
- Enhanced scheduler policies
- Graceful decommissioning

### 3. **Metadata Management**

**Dataproc provides:**
- Hive Metastore integration
- Shared metastore across clusters
- BigQuery integration via connectors

---

## Job Execution Lifecycle

### Complete Flow: From Submission to Completion

```
┌─────────────────────────────────────────────────────┐
│ 1. Job Submission                                    │
│    gcloud dataproc jobs submit pyspark script.py    │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│ 2. Driver Initialization                             │
│    - Spark Session created                           │
│    - Configuration loaded                            │
│    - Job resources requested from YARN               │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│ 3. Resource Allocation (YARN)                        │
│    - Containers allocated on worker nodes            │
│    - Executors launched in containers                │
│    - Memory and CPU assigned                         │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│ 4. Data Loading Phase                                │
│    spark.read.parquet("gs://...")                    │
│    ┌─────────────────────────────────┐              │
│    │ - GCS connector reads metadata  │              │
│    │ - Partition info collected      │              │
│    │ - Logical plan created          │              │
│    └─────────────────────────────────┘              │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│ 5. Transformation Phase                              │
│    df.withColumn("phone_number", mask_udf(...))      │
│    ┌─────────────────────────────────┐              │
│    │ - Lazy evaluation (not executed) │              │
│    │ - Logical plan updated           │              │
│    │ - Lineage graph maintained       │              │
│    └─────────────────────────────────┘              │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│ 6. Action Trigger                                    │
│    df.write.parquet("gs://...")                      │
│    ┌─────────────────────────────────┐              │
│    │ - Triggers actual execution      │              │
│    │ - Physical plan generated        │              │
│    │ - DAG created                    │              │
│    └─────────────────────────────────┘              │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│ 7. DAG Execution                                     │
│                                                      │
│    Stage 1: Read Parquet                            │
│    ┌──────────────────────────┐                    │
│    │ Task 1.1 → Partition 1   │                    │
│    │ Task 1.2 → Partition 2   │                    │
│    │ Task 1.3 → Partition 3   │                    │
│    └──────────────────────────┘                    │
│              │                                       │
│              ▼                                       │
│    Stage 2: Apply UDF                               │
│    ┌──────────────────────────┐                    │
│    │ Task 2.1 → Transform P1  │                    │
│    │ Task 2.2 → Transform P2  │                    │
│    │ Task 2.3 → Transform P3  │                    │
│    └──────────────────────────┘                    │
│              │                                       │
│              ▼                                       │
│    Stage 3: Write Parquet                           │
│    ┌──────────────────────────┐                    │
│    │ Task 3.1 → Write P1      │                    │
│    │ Task 3.2 → Write P2      │                    │
│    │ Task 3.3 → Write P3      │                    │
│    └──────────────────────────┘                    │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│ 8. Task Execution (on Executors)                    │
│    ┌─────────────────────────────────┐             │
│    │ For each task:                   │             │
│    │ 1. Deserialize task              │             │
│    │ 2. Load data partition           │             │
│    │ 3. Execute UDF row-by-row        │             │
│    │ 4. Write output                  │             │
│    │ 5. Report status to driver       │             │
│    └─────────────────────────────────┘             │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│ 9. Job Completion                                    │
│    - All tasks successful                            │
│    - Executors shut down                             │
│    - Job marked as SUCCEEDED                         │
│    - Logs written to GCS                             │
└─────────────────────────────────────────────────────┘
```

### Detailed Stage Breakdown

#### Stage Creation Logic

Spark creates stages based on **wide transformations** (shuffle operations):

```python
# Our pipeline stages:
df = spark.read.parquet(input)           # Stage 1: Input
masked = df.withColumn(...)              # (Same stage - narrow transformation)
masked.write.parquet(output)             # Stage 2: Output
```

**Narrow Transformations** (no shuffle):
- `map`, `filter`, `withColumn`
- Processed in the same stage
- Data doesn't move between partitions

**Wide Transformations** (require shuffle):
- `groupBy`, `join`, `repartition`
- Create new stages
- Data redistributed across partitions

---

## Resource Management

### Memory Management in Spark

```
┌────────────────────────────────────────────┐
│         Executor Memory (e.g., 4GB)        │
├────────────────────────────────────────────┤
│                                            │
│  ┌──────────────────────────────────┐     │
│  │  Reserved Memory (300MB)         │     │
│  │  - Spark internal use            │     │
│  └──────────────────────────────────┘     │
│                                            │
│  ┌──────────────────────────────────┐     │
│  │  Spark Memory (60% = 2.22GB)     │     │
│  │  ┌────────────────────────────┐  │     │
│  │  │ Storage Memory (50%)       │  │     │
│  │  │ - Cached RDDs/DataFrames   │  │     │
│  │  │ - Broadcast variables      │  │     │
│  │  └────────────────────────────┘  │     │
│  │  ┌────────────────────────────┐  │     │
│  │  │ Execution Memory (50%)     │  │     │
│  │  │ - Shuffles, joins, sorts   │  │     │
│  │  │ - Aggregations             │  │     │
│  │  └────────────────────────────┘  │     │
│  └──────────────────────────────────┘     │
│                                            │
│  ┌──────────────────────────────────┐     │
│  │  User Memory (40% = 1.48GB)      │     │
│  │  - User data structures          │     │
│  │  - UDF objects                   │     │
│  │  - Custom code variables         │     │
│  └──────────────────────────────────┘     │
│                                            │
└────────────────────────────────────────────┘
```

### CPU Allocation

```
┌────────────────────────────────────┐
│   Worker Node (e.g., n1-standard-4) │
│   4 vCPUs, 15GB RAM                 │
├────────────────────────────────────┤
│                                     │
│   YARN Overhead: 1 vCPU, 1GB       │
│   ──────────────────────────────   │
│   Available: 3 vCPUs, 14GB          │
│                                     │
│   Executor 1:                       │
│   ├─ 2 cores                        │
│   └─ 4GB memory                     │
│                                     │
│   Executor 2:                       │
│   ├─ 1 core                         │
│   └─ 4GB memory                     │
│                                     │
└────────────────────────────────────┘
```

### Configuring Resources

```python
# In our PySpark script
spark = SparkSession.builder \
    .appName("Phone Masking") \
    .config("spark.executor.memory", "4g") \
    .config("spark.executor.cores", "2") \
    .config("spark.dynamicAllocation.enabled", "true") \
    .getOrCreate()
```

Or via gcloud:
```bash
gcloud dataproc jobs submit pyspark script.py \
    --properties=spark.executor.memory=4g,spark.executor.cores=2
```

---

## Data Processing Internals

### How Our Masking Job Works Under the Hood

#### 1. **Data Reading**

```python
df = spark.read.parquet("gs://bucket/input")
```

**What happens:**
1. GCS connector lists all parquet files
2. Reads parquet metadata (schema, row groups)
3. Creates logical partitions (one per file or per row group)
4. Builds an RDD/DataFrame with partition info
5. **No data is actually loaded yet** (lazy evaluation)

#### 2. **UDF Application**

```python
mask_udf = udf(mask_middle_eight, StringType())
masked_df = df.withColumn("phone_number", mask_udf(col("phone_number")))
```

**What happens:**
1. UDF function is serialized (pickled)
2. UDF broadcasted to all executors
3. Logical plan updated with UDF transformation
4. **Still no execution** (still lazy)

**Execution (when action is called):**
```
For each partition:
  For each row:
    1. Extract phone_number value
    2. Call Python UDF function
       - Conversion: Spark row → Python object
       - Execute: mask_middle_eight(phone_number)
       - Conversion: Python result → Spark row
    3. Create new row with masked value
```

**Performance Note:** 
- Python UDFs are slower than Spark built-in functions
- Data serialization overhead (JVM ↔ Python)
- Better alternative: Pandas UDF (vectorized)

#### 3. **Data Writing**

```python
masked_df.write.mode("overwrite").parquet("gs://bucket/output")
```

**What happens:**
1. Triggers execution (action!)
2. Each executor writes its partition
3. Creates multiple parquet files (one per partition)
4. GCS connector streams data to Cloud Storage
5. Commits  the write operation

---

## Performance Optimization

### 1. **Partition Optimization**

```python
# Check current partitions
print(f"Partitions: {df.rdd.getNumPartitions()}")

# Too few partitions → underutilized executors
# Too many partitions → scheduling overhead

# Optimal: 2-3 partitions per CPU core
df = df.repartition(num_cores * 2)
```

### 2. **Caching Strategy**

```python
# Cache if data is reused
df = spark.read.parquet("gs://bucket/input")
df.cache()  # or .persist(StorageLevel.MEMORY_AND_DISK)

# Use cached data multiple times
count = df.count()
sample = df.sample(0.1).show()

# Clear cache when done
df.unpersist()
```

### 3. **Broadcast Joins**

```python
# Small lookup table
small_df = spark.read.csv("gs://bucket/lookup.csv")

# Broadcast to all executors
from pyspark.sql.functions import broadcast
result = large_df.join(broadcast(small_df), "key")
```

### 4. **Vectorized UDFs (Pandas UDF)**

```python
# Faster alternative to regular UDF
from pyspark.sql.functions import pandas_udf, PandasUDFType
import pandas as pd

@pandas_udf(StringType(), PandasUDFType.SCALAR)
def mask_middle_eight_vectorized(phone_series: pd.Series) -> pd.Series:
    return phone_series.str[0] + "********" + phone_series.str[-1]

# Use it
masked_df = df.withColumn("phone_number", mask_middle_eight_vectorized("phone_number"))
```

**Performance Improvement:** 10x-100x faster than regular Python UDFs!

### 5. **Predicate Pushdown**

```python
# Read with filter - only loads relevant data
df = spark.read.parquet("gs://bucket/input") \
    .filter(col("year") == 2024)  # Parquet metadata filter
```

### 6. **Columnar Storage Benefits**

Parquet format:
- Only reads required columns
- Compressed efficiently
- Predicate pushdown support

```python
# Only reads 'id' and 'phone_number' columns from parquet
df.select("id", "phone_number").show()
```

---

## Monitoring and Debugging

### Spark UI

Access via:
- Dataproc Console → Cluster → Web Interfaces → Spark History Server
- Dataproc Serverless → Batch → View Logs → Spark UI

**Key Metrics:**
- **Jobs**: High-level operations
- **Stages**: DAG execution stages
- **Tasks**: Individual partition operations
- **Executors**: Resource usage
- **SQL**: DataFrame query plans

### Important Metrics to Monitor

1. **Task Duration Distribution**
   - Identifies data skew
   - Shows slow tasks

2. **GC Time**
   - High GC = memory pressure
   - Consider increasing executor memory

3. **Shuffle Read/Write**
   - Large shuffles = performance bottleneck
   - Optimize partitioning

4. **Data Spill**
   - Memory → Disk spill is expensive
   - Increase memory or reduce data per partition

---

## Summary

### Key Takeaways

1. **Spark** is a distributed computing framework with driver and executors
2. **Dataproc** adds GCP integration, auto-scaling, and ease of management
3. **Lazy evaluation** allows Spark to optimize the entire pipeline
4. **Partitioning** is crucial for parallelism and performance
5. **UDFs** provide flexibility but have performance costs
6. **Resource tuning** requires understanding memory and CPU allocation

---

## Further Reading

- [Official Spark Documentation](https://spark.apache.org/docs/latest/)
- [Dataproc Documentation](https://cloud.google.com/dataproc/docs)
- [Spark Performance Tuning](https://spark.apache.org/docs/latest/tuning.html)
- [GCS Connector Guide](https://cloud.google.com/dataproc/docs/concepts/connectors/cloud-storage)
