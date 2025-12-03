# Manual Deployment Procedure

This guide provides step-by-step manual deployment instructions for the Phone Number Masking Dataproc Pipeline.

## Prerequisites

- Google Cloud SDK (`gcloud`) installed
- Service Account with necessary permissions
- Service Account JSON key file downloaded

---

## Step 1: Initial Setup and Authentication

### 1.1 Set Environment Variables

```bash
export PROJECT_ID="prefab-pursuit-473910-b4"
export REGION="us-central1"
export SERVICE_ACCOUNT="69366831705-compute@developer.gserviceaccount.com"
export KEY_FILE="C:/Users/ILAYA BHARATHI M/Downloads/prefab-pursuit-473910-b4-d019ef549665.json"
export BUCKET_NAME="ilaya-dataproc-demo-001"
```

### 1.2 Authenticate with GCP

```bash
# Activate service account
gcloud auth activate-service-account "$SERVICE_ACCOUNT" --key-file="$KEY_FILE"

# Set active project
gcloud config set project "$PROJECT_ID"

# Verify authentication
gcloud auth list
```

---

## Step 2: Enable Required APIs

```bash
# Enable Dataproc API
gcloud services enable dataproc.googleapis.com --project="$PROJECT_ID"

# Enable Compute Engine API
gcloud services enable compute.googleapis.com --project="$PROJECT_ID"

# Enable Cloud Storage API
gcloud services enable storage.googleapis.com --project="$PROJECT_ID"

# Enable Artifact Registry API (for dependencies)
gcloud services enable artifactregistry.googleapis.com --project="$PROJECT_ID"
```

Wait 30-60 seconds for API enablement to propagate.

---

## Step 3: Grant IAM Permissions

```bash
# Grant Dataproc Admin role
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SERVICE_ACCOUNT" \
    --role="roles/dataproc.admin"

# Grant Dataproc Worker role
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SERVICE_ACCOUNT" \
    --role="roles/dataproc.worker"

# Grant Storage Admin role
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SERVICE_ACCOUNT" \
    --role="roles/storage.admin"

# Grant Service Account User role
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SERVICE_ACCOUNT" \
    --role="roles/iam.serviceAccountUser"
```

---

## Step 4: Create GCS Bucket

```bash
# Create bucket
gcloud storage buckets create "gs://${BUCKET_NAME}" \
    --project="$PROJECT_ID" \
    --location="$REGION"

# Verify bucket creation
gsutil ls -b "gs://${BUCKET_NAME}"
```

---

## Step 5: Upload Scripts to GCS

```bash
# Create script directories
gsutil cp generate_data.py "gs://${BUCKET_NAME}/scripts/generate_data.py"
gsutil cp mask_phone_numbers.py "gs://${BUCKET_NAME}/scripts/mask_phone_numbers.py"

# Verify upload
gsutil ls "gs://${BUCKET_NAME}/scripts/"
```

---

## Step 6: Option A - Serverless Dataproc Deployment

### 6.1 Generate Sample Data

```bash
BATCH_ID_GEN="dataproc-gen-$(date +%Y%m%d-%H%M%S)"

gcloud dataproc batches submit pyspark \
    "gs://${BUCKET_NAME}/scripts/generate_data.py" \
    --batch=$BATCH_ID_GEN \
    --project="$PROJECT_ID" \
    --region="$REGION" \
    --version=2.2 \
    --deps-bucket="$BUCKET_NAME" \
    -- "gs://${BUCKET_NAME}/data/input_data"
```

### 6.2 Monitor Job Progress

```bash
# Check batch status
gcloud dataproc batches describe $BATCH_ID_GEN \
    --region="$REGION" \
    --project="$PROJECT_ID"

# View logs
gcloud dataproc batches list --region="$REGION" --project="$PROJECT_ID"
```

### 6.3 Run Masking Job

```bash
BATCH_ID_MASK="dataproc-mask-$(date +%Y%m%d-%H%M%S)"

gcloud dataproc batches submit pyspark \
    "gs://${BUCKET_NAME}/scripts/mask_phone_numbers.py" \
    --batch=$BATCH_ID_MASK \
    --project="$PROJECT_ID" \
    --region="$REGION" \
    --version=2.2 \
    --deps-bucket="$BUCKET_NAME" \
    -- "gs://${BUCKET_NAME}/data/input_data" \
       "gs://${BUCKET_NAME}/data/output_data_serverless"
```

### 6.4 Verify Output

```bash
# List output files
gsutil ls -r "gs://${BUCKET_NAME}/data/output_data_serverless/"

# Download a sample file to inspect (optional)
gsutil cp "gs://${BUCKET_NAME}/data/output_data_serverless/part-*.parquet" ./sample_output.parquet
```

---

## Step 7: Option B - Standalone Dataproc Cluster Deployment

### 7.1 Create Dataproc Cluster

```bash
CLUSTER_NAME="dataproc-cluster-demo"

gcloud dataproc clusters create "$CLUSTER_NAME" \
    --project="$PROJECT_ID" \
    --region="$REGION" \
    --single-node \
    --master-machine-type=n1-standard-2 \
    --image-version=2.1-debian11 \
    --service-account="$SERVICE_ACCOUNT"
```

**Note:** Cluster creation takes approximately 2-3 minutes.

### 7.2 Verify Cluster Creation

```bash
# List clusters
gcloud dataproc clusters list --region="$REGION" --project="$PROJECT_ID"

# Describe cluster
gcloud dataproc clusters describe "$CLUSTER_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID"
```

### 7.3 Submit Data Generation Job

```bash
gcloud dataproc jobs submit pyspark \
    "gs://${BUCKET_NAME}/scripts/generate_data.py" \
    --cluster="$CLUSTER_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    -- "gs://${BUCKET_NAME}/data/input_data"
```

### 7.4 Submit Masking Job

```bash
gcloud dataproc jobs submit pyspark \
    "gs://${BUCKET_NAME}/scripts/mask_phone_numbers.py" \
    --cluster="$CLUSTER_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    -- "gs://${BUCKET_NAME}/data/input_data" \
       "gs://${BUCKET_NAME}/data/output_data_standalone"
```

### 7.5 Monitor Job Status

```bash
# List all jobs on the cluster
gcloud dataproc jobs list \
    --cluster="$CLUSTER_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID"

# Get job details (replace JOB_ID with actual job ID)
gcloud dataproc jobs describe JOB_ID \
    --region="$REGION" \
    --project="$PROJECT_ID"
```

### 7.6 Delete Cluster (To Save Costs)

```bash
gcloud dataproc clusters delete "$CLUSTER_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --quiet
```

---

## Step 8: Validation and Verification

### 8.1 Check Data in GCS

```bash
# List all data directories
gsutil ls "gs://${BUCKET_NAME}/data/"

# View file details
gsutil ls -lh "gs://${BUCKET_NAME}/data/output_data_serverless/"
```

### 8.2 Quick Data Inspection (Using Cloud Shell)

You can inspect the masked data by submitting a quick verification job:

**Create verify_data.py:**

```python
from pyspark.sql import SparkSession
import sys

spark = SparkSession.builder.appName("Verify Data").getOrCreate()
df = spark.read.parquet(sys.argv[1])
df.show(10, truncate=False)
spark.stop()
```

**Submit verification:**

```bash
gsutil cp verify_data.py "gs://${BUCKET_NAME}/scripts/"

gcloud dataproc batches submit pyspark \
    "gs://${BUCKET_NAME}/scripts/verify_data.py" \
    --project="$PROJECT_ID" \
    --region="$REGION" \
    --version=2.2 \
    --deps-bucket="$BUCKET_NAME" \
    -- "gs://${BUCKET_NAME}/data/output_data_serverless"
```

---

## Step 9: Troubleshooting

### Common Issues and Solutions

#### Issue 1: Permission Denied
**Error:** "Permission denied" or "Access denied"

**Solution:**
```bash
# Verify service account has correct roles
gcloud projects get-iam-policy "$PROJECT_ID" \
    --filter="bindings.members:serviceAccount:$SERVICE_ACCOUNT" \
    --flatten="bindings[].members" \
    --format="table(bindings.role)"
```

#### Issue 2: API Not Enabled
**Error:** "API [...] is not enabled"

**Solution:**
```bash
# Force enable the API
gcloud services enable SERVICE_NAME.googleapis.com --project="$PROJECT_ID"
```

#### Issue 3: Quota Exceeded
**Error:** "Quota exceeded for quota metric..."

**Solution:**
- Check quotas in GCP Console: IAM & Admin > Quotas
- Request quota increase if needed
- Consider using smaller machine types

#### Issue 4: Cluster Creation Fails
**Error:** Various cluster creation errors

**Solution:**
```bash
# Check Compute Engine default service account exists
gcloud iam service-accounts list --project="$PROJECT_ID"

# Ensure you have available IP addresses in the region
gcloud compute addresses list --project="$PROJECT_ID" --regions="$REGION"
```

---

## Step 10: Cleanup (Optional)

To avoid ongoing charges, clean up resources:

```bash
# Delete bucket and all contents
gsutil -m rm -r "gs://${BUCKET_NAME}"

# Delete any remaining clusters
gcloud dataproc clusters delete "$CLUSTER_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --quiet
```

---

## Best Practices

1. **Always delete clusters** when not in use to avoid charges
2. **Use lifecycle policies** on GCS buckets to auto-delete old data
3. **Monitor costs** regularly in the GCP Console
4. **Use preemptible workers** for non-critical workloads to save costs
5. **Enable logging** for troubleshooting and auditing
6. **Use labels** to organize and track resources

---

## Next Steps

- Review the automated deployment procedure in `DEPLOYMENT_AUTOMATED.md`
- Learn about Spark and Dataproc internals in `SPARK_DATAPROC_INTERNALS.md`
- Compare Serverless vs Standalone in `SERVERLESS_VS_STANDALONE.md`
