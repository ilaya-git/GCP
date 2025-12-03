# Automated Deployment Procedure

This guide explains the automated deployment scripts and how to use them for the Phone Number Masking Dataproc Pipeline.

---

## Overview

The automated deployment uses shell scripts to orchestrate all deployment steps, reducing manual errors and ensuring consistency.

### Available Scripts

| Script | Purpose |
|--------|---------|
| `config.sh` | Central configuration file |
| `auth_gcs.sh` | Authentication and infrastructure setup |
| `run_serverless_job.sh` | Execute pipeline using Dataproc Serverless |
| `run_standalone_job.sh` | Execute pipeline using Standalone Dataproc Cluster |

---

## Script Architecture

```
┌─────────────────┐
│   config.sh     │  ← Configuration parameters
└────────┬────────┘
         │
         ├──→ ┌──────────────────┐
         │    │  auth_gcs.sh     │  ← Setup & Auth
         │    └──────────────────┘
         │
         ├──→ ┌──────────────────────────┐
         │    │ run_serverless_job.sh    │  ← Serverless execution
         │    └──────────────────────────┘
         │
         └──→ ┌──────────────────────────┐
              │ run_standalone_job.sh    │  ← Cluster-based execution
              └──────────────────────────┘
```

---

## Automated Deployment Steps

### Step 1: Configure Parameters

Edit `config.sh` with your specific values:

```bash
# GCP Project Details
export PROJECT_ID="prefab-pursuit-473910-b4"
export REGION="us-central1"
export SERVICE_ACCOUNT="69366831705-compute@developer.gserviceaccount.com"
export GOOGLE_APPLICATION_CREDENTIALS="C:/Users/ILAYA BHARATHI M/Downloads/prefab-pursuit-473910-b4-d019ef549665.json"

# Bucket and Cluster
export BUCKET_NAME="ilaya-dataproc-demo-001"
export CLUSTER_NAME="dataproc-cluster-demo"
```

**Key Configuration Variables:**

- `PROJECT_ID`: Your GCP project ID
- `REGION`: GCP region (e.g., us-central1, europe-west1)
- `SERVICE_ACCOUNT`: Email of the service account
- `GOOGLE_APPLICATION_CREDENTIALS`: Path to service account JSON key
- `BUCKET_NAME`: Unique GCS bucket name
- `CLUSTER_NAME`: Name for the Dataproc cluster (standalone only)

---

### Step 2: Run Authentication Setup

Execute the authentication and setup script:

```bash
bash auth_gcs.sh
```

**What it does:**
1. ✓ Validates configuration
2. ✓ Authenticates with GCP using service account
3. ✓ Enables required APIs (Dataproc, Compute, Storage)
4. ✓ Grants necessary IAM roles
5. ✓ Creates GCS bucket if it doesn't exist

**Expected Output:**
```
======================================
Dataproc Pipeline Setup
======================================

Configuration:
  Project ID: prefab-pursuit-473910-b4
  Region: us-central1
  Bucket: ilaya-dataproc-demo-001
  Service Account: 69366831705-compute@...

[1/4] Authenticating with GCP...
✓ Authentication complete

[2/4] Enabling required APIs...
✓ APIs enabled

[3/4] Verifying service account permissions...
✓ Permissions configured

[4/4] Checking GCS Bucket...
✓ Bucket ready

======================================
Setup Complete!
======================================
```

---

### Step 3A: Run Serverless Pipeline (Recommended)

Execute the serverless automated pipeline:

```bash
bash run_serverless_job.sh
```

**Pipeline Workflow:**

```
┌─────────────────────┐
│  Upload Scripts     │
│  to GCS             │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Submit Data        │
│  Generation Job     │
│  (Serverless)       │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Wait for           │
│  Completion         │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Submit Masking     │
│  Job (Serverless)   │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Wait for           │
│  Completion         │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Pipeline Complete  │
│  Output Available   │
└─────────────────────┘
```

**Expected Output:**
```
===================================================
Running Dataproc Serverless (Batches) Execution
Project: prefab-pursuit-473910-b4
Bucket: ilaya-dataproc-demo-001
===================================================

Uploading scripts to GCS...
Operation completed over 2 objects.

Submitting Data Generation Job...
Batch ID: dataproc-gen-20251202-125026
Batch [dataproc-gen-20251202-125026] submitted.
...
Batch [dataproc-gen-20251202-125026] finished.

Submitting Masking Job...
Batch ID: dataproc-mask-20251202-125248
Batch [dataproc-mask-20251202-125248] submitted.
...
Sample of masked data:
+---+---------+------------+---------------------+
|id |name     |phone_number|email                |
+---+---------+------------+---------------------+
|51 |Person_51|7********5  |person_51@example.com|
...
Batch [dataproc-mask-20251202-125248] finished.

===================================================
Serverless Pipeline Execution Completed Successfully
Output location: gs://ilaya-dataproc-demo-001/data/output_data_serverless
===================================================
```

**Advantages:**
- ✓ No cluster management
- ✓ Auto-scaling
- ✓ Pay only for job duration
- ✓ Faster startup time

---

### Step 3B: Run Standalone Cluster Pipeline (Alternative)

Execute the standalone cluster pipeline:

```bash
bash run_standalone_job.sh
```

**Pipeline Workflow:**

```
┌─────────────────────┐
│  Upload Scripts     │
│  to GCS             │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Create Dataproc    │
│  Cluster            │
│  (2-3 minutes)      │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Submit Data        │
│  Generation Job     │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Submit Masking     │
│  Job                │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Delete Cluster     │
│  (Auto cleanup)     │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Pipeline Complete  │
└─────────────────────┘
```

**Expected Output:**
```
===================================================
Running Dataproc Standalone Cluster Execution
Project: prefab-pursuit-473910-b4
Cluster: dataproc-cluster-demo
===================================================

Creating Dataproc Cluster...
Waiting for cluster creation operation...
Created [https://dataproc.googleapis.com/v1/projects/.../clusters/dataproc-cluster-demo]

Submitting Data Generation Job to Cluster...
Job [abc123] submitted.
...

Submitting Masking Job to Cluster...
Job [def456] submitted.
...

Deleting Cluster...
Waiting for cluster deletion operation...
Deleted [dataproc-cluster-demo]

===================================================
Standalone Pipeline Execution Completed Successfully
Output location: gs://ilaya-dataproc-demo-001/data/output_data_standalone
===================================================
```

**Advantages:**
- ✓ Better for multiple sequential jobs
- ✓ More control over cluster configuration
- ✓ Can use custom initialization actions
- ✓ SSH access for debugging

---

## Script Internals

### `auth_gcs.sh` - Detailed Breakdown

```bash
#!/bin/bash
set -e  # Exit on any error

# Load configuration
source ./config.sh

# 1. Validation
# Checks if config values are set correctly

# 2. Authentication
gcloud auth activate-service-account ...

# 3. Enable APIs
for api in "${apis[@]}"; do
    gcloud services enable "$api"
done

# 4. Grant IAM Roles
for role in "${roles[@]}"; do
    gcloud projects add-iam-policy-binding ...
done

# 5. Create GCS Bucket
gcloud storage buckets create ...
```

### `run_serverless_job.sh` - Detailed Breakdown

```bash
#!/bin/bash
set -e

source ./config.sh

# 1. Upload Scripts
gsutil cp *.py gs://${BUCKET_NAME}/scripts/

# 2. Generate Data (Serverless Batch)
BATCH_ID_GEN="dataproc-gen-$(date +%Y%m%d-%H%M%S)"
gcloud dataproc batches submit pyspark ... \
    --batch=$BATCH_ID_GEN \
    --version=2.2 \
    ...

# 3. Run Masking Job (Serverless Batch)
BATCH_ID_MASK="dataproc-mask-$(date +%Y%m%d-%H%M%S)"
gcloud dataproc batches submit pyspark ... \
    --batch=$BATCH_ID_MASK \
    --version=2.2 \
    ...
```

### `run_standalone_job.sh` - Detailed Breakdown

```bash
#!/bin/bash
set -e

source ./config.sh

# 1. Upload Scripts
gsutil cp *.py gs://${BUCKET_NAME}/scripts/

# 2. Create Cluster
gcloud dataproc clusters create ${CLUSTER_NAME} \
    --single-node \
    --master-machine-type=n1-standard-2

# 3. Submit Jobs to Cluster
gcloud dataproc jobs submit pyspark ...

# 4. Auto-delete Cluster
gcloud dataproc clusters delete ${CLUSTER_NAME} --quiet
```
