# Serverless vs Standalone Dataproc

A comprehensive comparison of Dataproc Serverless (Batches) and Standalone Dataproc Clusters, including when to use each approach and their respective advantages.

---

## Quick Comparison Table

| Feature | Serverless (Batches) | Standalone Cluster |
|---------|---------------------|-------------------|
| **Cluster Management** | Fully automated | Manual management |
| **Startup Time** | 30-60 seconds | 90-180 seconds |
| **Scaling** | Automatic | Manual or auto-scaling |
| **Cost Model** | Per-job, per-second billing | Per-hour billing (minimum 1 minute) |
| **Best For** | One-off jobs, scheduled workloads | Interactive analysis, long-running jobs |
| **Resource Limits** | Predefined limits | Customizable |
| **SSH Access** | No | Yes |
| **Cluster Sharing** | No (isolated per job) | Yes (multiple jobs) |
| **Spark UI** | Available post-execution | Real-time access |
| **Custom Init Scripts** | Limited | Full support |
| **Preemptible Workers** | Via configuration | Full control |

---

## Architecture Comparison

### Serverless (Batches) Architecture

```
┌──────────────────────────────────────────────────┐
│  User submits job                                 │
│  gcloud dataproc batches submit pyspark ...      │
└─────────────────────┬────────────────────────────┘
                      │
                      ▼
┌──────────────────────────────────────────────────┐
│  Google Manages Everything                        │
│  ┌────────────────────────────────────────────┐  │
│  │ 1. Provisions resources                    │  │
│  │ 2. Creates ephemeral cluster               │  │
│  │ 3. Executes job                            │  │
│  │ 4. Tears down cluster                      │  │
│  │ 5. Stores logs in GCS                      │  │
│  └────────────────────────────────────────────┘  │
└─────────────────────┬────────────────────────────┘
                      │
                      ▼
┌──────────────────────────────────────────────────┐
│  Output in GCS                                    │
│  Logs available                                   │
│  No infrastructure left running                   │
└──────────────────────────────────────────────────┘
```

**Lifecycle:**
```
Submit → Provision → Execute → Complete → Auto-cleanup
   0s      ~30s        Xs        0s          0s
         
Total billable time: Provision + Execute only
```

### Standalone Cluster Architecture

```
┌──────────────────────────────────────────────────┐
│  User creates cluster                             │
│  gcloud dataproc clusters create ...             │
└─────────────────────┬────────────────────────────┘
                      │
                      ▼
┌──────────────────────────────────────────────────┐
│  Cluster Running (User Managed)                   │
│  ┌────────────────────────────────────────────┐  │
│  │  Master Node(s)                            │  │
│  │  - YARN Resource Manager                   │  │
│  │  - HDFS NameNode                           │  │
│  │  - Spark History Server                    │  │
│  ├────────────────────────────────────────────┤  │
│  │  Worker Nodes                              │  │
│  │  - YARN Node Managers                      │  │
│  │  - HDFS DataNodes                          │  │
│  │  - Spark Executors (when jobs run)         │  │
│  └────────────────────────────────────────────┘  │
│                                                   │
│  Cluster remains until deleted                    │
└─────────────────────┬────────────────────────────┘
                      │
                      ▼
┌──────────────────────────────────────────────────┐
│  Submit multiple jobs                             │
│  gcloud dataproc jobs submit pyspark ...         │
│  (runs on existing cluster)                       │
└──────────────────────────────────────────────────┘
```

**Lifecycle:**
```
Create → [Job1 → Job2 → ... → JobN] → Delete
  ~2m              Xs each                 ~2m

Total billable time: Entire cluster lifetime
```

---

## Detailed Comparison

### 1. **Cost Analysis**

#### Serverless Pricing

**Formula:**
```
Cost = (vCPU hours × CPU price) + (GB hours × Memory price) + Dataproc charge
```

**Example Job:**
- Job duration: 5 minutes
- Resources: 4 vCPUs, 16GB RAM
- Region: us-central1

```
vCPU cost:    4 × (5/60) × $0.056 = $0.0187
Memory cost:  16 × (5/60) × $0.0075 = $0.02
Dataproc fee: Same × 1.0 = $0.0387
Total: ~$0.04 per job
```

**Advantages:**
- ✓ Pay only for job execution time
- ✓ No idle costs
- ✓ Perfect for infrequent jobs

**Best For:**
- Daily/weekly batch jobs
- Ad-hoc analysis
- Event-driven processing

#### Standalone Cluster Pricing

**Formula:**
```
Cost = (Node hours × Node price × Number of nodes) + Dataproc charge
```

**Example Cluster:**
- 1 master: n1-standard-4 (4 vCPU, 15GB)
- 2 workers: n1-standard-4 each
- Running: 2 hours

```
Master:  1 × 2 × $0.19 = $0.38
Workers: 2 × 2 × $0.19 = $0.76
Dataproc fee: $1.14 × 0.01/hr = $0.02
Total: ~$1.16 for 2 hours
```

**Advantages:**
- ✓ Amortize cluster cost over multiple jobs
- ✓ No startup time for subsequent jobs
- ✓ Cheaper for many sequential jobs

**Best For:**
- Multiple jobs per hour
- Interactive workloads
- Development and testing

#### Cost Breakeven Analysis

```
Scenario: 10 jobs per day, each 5 minutes

Serverless:
  10 jobs × $0.04 = $0.40/day

Standalone (cluster runs 2 hours/day):
  $1.16 total

Breakeven: ~29 jobs in 2 hours
  If you run >29 jobs in 2 hrs → Standalone is cheaper
  If you run <29 jobs in 2 hrs → Serverless is cheaper
```

---

### 2. **Performance Comparison**

#### Startup Time

**Serverless:**
```
Submit job
    ↓ 30-60 seconds (cold start)
Job begins execution
```

**Standalone:**
```
Create cluster (one-time)
    ↓ 90-180 seconds
Cluster ready
    ↓
Submit job
    ↓ 5-10 seconds (warm start)
Job begins execution
```

**Winner:** Serverless for single jobs, Standalone for multiple jobs

#### Execution Speed

Both use the same Spark and Hadoop versions, so **execution speed is identical** for the same configuration.

However:
- **Standalone** can use larger/custom machine types
- **Serverless** has resource limits (max workers, memory, etc.)

#### Scalability

**Serverless:**
- Automatic scaling within limits
- Can handle burst workloads
- Limited by quota maximums

**Standalone:**
- Manual scaling (resize cluster)
- Auto-scaling workers (with policy)
- More control over scaling behavior

---

### 3. **Feature Comparison**

#### SSH and Interactive Access

**Serverless:**
- ❌ No SSH access
- ❌ No Jupyter notebooks directly
- ✓ Can submit Jupyter via gateway

**Standalone:**
- ✓ SSH to master node
- ✓ Run spark-shell, pyspark REPL
- ✓ Jupyter notebooks via component gateway
- ✓ Debug in real-time

**Use Case:** If you need interactive debugging → Standalone

#### Custom Configuration

**Serverless:**
```bash
gcloud dataproc batches submit pyspark script.py \
    --version=2.2 \
    --properties=spark.executor.memory=4g \
    --subnet=custom-subnet \
    --service-account=custom-sa@project.iam.gserviceaccount.com
```

**Limited to:**
- Spark properties
- Network configuration
- Service account
- Labels and metadata

**Standalone:**
```bash
gcloud dataproc clusters create my-cluster \
    --initialization-actions=gs://bucket/init.sh \
    --image-version=2.1-debian11 \
    --properties=spark:spark.executor.memory=8g \
    --metadata=key=value \
    --bucket=my-bucket \
    --optional-components=JUPYTER,ZEPPELIN
```

**Full control over:**
- Initialization scripts
- Custom images
- Component installation
- Network topology
- Persistent HDFS

**Use Case:** Custom software/libraries → Standalone

#### Job Dependencies

**Serverless:**
```bash
gcloud dataproc batches submit pyspark script.py \
    --py-files=lib1.py,lib2.py \
    --files=config.json \
    --archives=data.zip
```

- ✓ Supports py-files, files, archives
- ✓ Can specify pip packages (via properties)
- ❌ Cannot install system packages

**Standalone:**
- ✓ All of the above
- ✓ Init actions can install anything
- ✓ Pre-install in custom image

---

### 4. **Operational Comparison**

#### Monitoring and Debugging

**Serverless:**
| Aspect | Capability |
|--------|-----------|
| Spark UI | ✓ Available after job completion |
| Real-time logs | ✓ Via Cloud Logging |
| Job history | ✓ Stored in GCS |
| Metrics | ✓ Cloud Monitoring integration |
| Debugging | ❌ No live debugging |

**Standalone:**
| Aspect | Capability |
|--------|-----------|
| Spark UI | ✓ Real-time access during job |
| YARN UI | ✓ Full resource manager view |
| Job history | ✓ Persistent history server |
| Metrics | ✓ Cloud Monitoring + node-level metrics |
| Debugging | ✓ SSH access, live debugging |

#### Failure Handling

**Serverless:**
- Automatic retry (configurable)
- Job fails → entire batch fails
- No manual intervention

**Standalone:**
- Configurable Spark retry
- Can manually restart failed jobs
- Can debug on live cluster
- Cluster failures are separate from job failures

---

### 5. **Use Case Decision Matrix**

#### Choose Serverless When:

✓ **Scheduled batch jobs** (daily, weekly)
```bash
# Daily ETL at 2 AM
gcloud dataproc batches submit pyspark daily_etl.py ...
```

✓ **Event-driven processing** (Cloud Functions trigger)
```python
# Triggered by Cloud Storage upload
def trigger_dataproc(event, context):
    submit_batch_job(event['bucket'], event['name'])
```

✓ **Cost optimization is critical**
- Infrequent jobs
- Unpredictable workload patterns
- No idle time tolerance

✓ **Simple workloads**
- Standard Spark jobs
- No custom dependencies
- No interactive analysis needed

✓ **Short-lived jobs** (<1 hour typical)

---

#### Choose Standalone When:

✓ **Interactive development**
```bash
# SSH into cluster
gcloud compute ssh my-cluster-m --zone=us-central1-a

# Run interactive PySpark
pyspark
>>> df = spark.read.parquet("gs://...")
>>> df.show()
```

✓ **Multiple sequential jobs**
```bash
# Run 20 jobs in 2 hours
for i in {1..20}; do
    gcloud dataproc jobs submit pyspark job_$i.py --cluster=my-cluster
done
```

✓ **Complex dependencies**
```bash
# Init action installs TensorFlow, custom libraries
--initialization-actions=gs://bucket/install_deps.sh
```

✓ **Custom resource requirements**
```bash
# High-memory nodes
--master-machine-type=n1-highmem-8
--worker-machine-type=n1-highmem-8
```

✓ **Long-running jobs** (>2 hours)

✓ **Persistent HDFS needed**
- Temporary data between jobs
- Iterative algorithms

✓ **Testing and debugging**
- Development environment
- Performance tuning

---

## Migration Strategies

### From Standalone to Serverless

**Checklist:**
1. Remove custom init actions or package differently
2. Ensure all data is in GCS (not HDFS)
3. Test resource limits
4. Update CI/CD pipelines
5. Modify monitoring/alerting

**Example Migration:**

**Before (Standalone):**
```bash
# Create cluster
gcloud dataproc clusters create my-cluster \
    --initialization-actions=gs://bucket/install_deps.sh

# Submit job
gcloud dataproc jobs submit pyspark job.py \
    --cluster=my-cluster

# Delete cluster
gcloud dataproc clusters delete my-cluster
```

**After (Serverless):**
```bash
# Submit batch (includes dependencies)
gcloud dataproc batches submit pyspark job.py \
    --py-files=deps.zip \
    --version=2.2
```

### From Serverless to Standalone

**When to migrate:**
- Serverless limits are too restrictive
- Need SSH access for debugging
- Running many jobs concurrently
- Require custom system packages

**Migration steps:**
1. Create cluster with needed configuration
2. Update job submission commands
3. Implement cluster lifecycle management
4. Set up auto-scaling if needed

---

## Hybrid Approach

Use both for different workloads:

```bash
# Development: Standalone cluster (persistent)
gcloud dataproc clusters create dev-cluster --single-node

# Submit test jobs
gcloud dataproc jobs submit pyspark test.py --cluster=dev-cluster

# Production: Serverless batches
gcloud dataproc batches submit pyspark prod_job.py --version=2.2
```

**Strategy:**
- **Development:** Standalone for interactive work
- **Production:** Serverless for automated pipelines
- **Ad-hoc analysis:** Serverless for one-off queries
- **ML training:** Standalone with GPU nodes

---

## Best Practices

### Serverless Best Practices

1. **Optimize job duration** - Longer jobs = better startup time amortization
2. **Batch multiple operations** - Combine steps in one job
3. **Use appropriate instance types** - Match resources to workload
4. **Monitor and set limits** - Avoid runaway costs
5. **Leverage caching** - Use GCS for intermediate results

### Standalone Best Practices

1. **Right-size cluster** - Don't over-provision
2. **Use preemptible workers** - 70-80% cost savings
3. **Enable auto-scaling** - Adapt to workload
4. **Delete idle clusters** - Set up automatic deletion
5. **Use custom images** - Faster startup with pre-installed deps

---

## Summary

### Serverless Advantages

| Advantage | Impact |
|-----------|--------|
| Zero infrastructure management | Reduced operational overhead |
| Pay-per-use pricing | Lower costs for infrequent jobs |
| Automatic scaling | No capacity planning needed |
| Fast startup (cold start) | Quick one-off analysis |
| Fully managed | No patching, updates, or maintenance |

### Standalone Advantages

| Advantage | Impact |
|-----------|--------|
| Full control | Custom configurations |
| Interactive access | Better for development |
| Cost-effective at scale | Cheaper for high job volumes |
| Advanced features | Init scripts, custom images |
| Persistent storage | HDFS for temporary data |

---

## Recommendation for Our Pipeline

**For our Phone Number Masking Pipeline:**

✅ **Use Serverless** because:
1. Simple job with no custom dependencies
2. Runs infrequently (batch processing)
3. No interactive requirements
4. Cost-effective for scheduled runs
5. Easy to automate and schedule

**Consider Standalone if:**
- You need to run masking jobs every few minutes
- You want to test different masking strategies interactively
- You need to install custom libraries
- You're processing very large datasets (>10TB) that need tuning

---

## Conclusion

Both Serverless and Standalone Dataproc have their place. Choose based on:
- **Frequency** of jobs
- **Complexity** of required
- **Cost** constraints
- **Operational** capabilities
- **Development** vs **Production** needs

For most modern data pipelines, **Serverless is the recommended starting point**, with migration to Standalone only when specific limitations are encountered.
