#!/bin/bash

# Cleanup Script for Dataflow Pipeline
# This script deletes all resources created for the pipeline

set -e  # Exit on error

echo "======================================"
echo "Dataflow Pipeline Cleanup"
echo "======================================"
echo ""

# ============================================
# CONFIGURATION
# ============================================
# These should match your setup_gcp.sh
PROJECT_ID="your_project-id"
REGION="your-region"  # e.g., us-central1
BUCKET_NAME="your-dataflow-bucket"
DATASET_NAME="dataflow_sample_dataset"
IMAGE_NAME="gcr.io/$PROJECT_ID/gcs-to-bq-template"

echo "Configuration:"
echo "  Project ID: $PROJECT_ID"
echo "  Bucket: $BUCKET_NAME"
echo "  Dataset: $DATASET_NAME"
echo "  Image: $IMAGE_NAME"
echo ""

read -p "⚠️  Are you sure you want to DELETE these resources? (y/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled."
    exit 1
fi
echo ""

# ============================================
# 1. Cancel Running Jobs
# ============================================
echo "[1/4] Checking for running jobs..."
# List active jobs and cancel them
JOBS=$(gcloud dataflow jobs list --project="$PROJECT_ID" --region="$REGION" --status=active --format="value(JOB_ID)")

if [ -n "$JOBS" ]; then
    echo "Found active jobs. Cancelling..."
    for JOB_ID in $JOBS; do
        echo "  Cancelling job: $JOB_ID"
        gcloud dataflow jobs cancel "$JOB_ID" --project="$PROJECT_ID" --region="$REGION"
    done
    echo "✓ Active jobs cancelled"
else
    echo "✓ No active jobs found"
fi
echo ""

# ============================================
# 2. Delete BigQuery Dataset
# ============================================
echo "[2/4] Deleting BigQuery dataset..."
if bq ls -d --project_id="$PROJECT_ID" | grep -q "$DATASET_NAME"; then
    # -r = recursive (delete tables), -f = force (no confirmation)
    bq rm -r -f -d "$PROJECT_ID:$DATASET_NAME"
    echo "✓ Dataset deleted: $DATASET_NAME"
else
    echo "✓ Dataset not found (already deleted)"
fi
echo ""

# ============================================
# 3. Delete GCS Bucket
# ============================================
echo "[3/4] Deleting GCS bucket..."
if gsutil ls -b "gs://$BUCKET_NAME" 2>/dev/null; then
    # -m = multi-threaded, -r = recursive
    gsutil -m rm -r "gs://$BUCKET_NAME"
    echo "✓ Bucket deleted: gs://$BUCKET_NAME"
else
    echo "✓ Bucket not found (already deleted)"
fi
echo ""

# ============================================
# 4. Delete Docker Image
# ============================================
echo "[4/4] Deleting Docker image..."
# Check if image exists
if gcloud container images list --repository="gcr.io/$PROJECT_ID" | grep -q "$IMAGE_NAME"; then
    gcloud container images delete "$IMAGE_NAME" --force-delete-tags --quiet
    echo "✓ Docker image deleted: $IMAGE_NAME"
else
    echo "✓ Docker image not found or already deleted"
fi
echo ""

# ============================================
# Summary
# ============================================
echo "======================================"
echo "Cleanup Complete!"
echo "======================================"
echo "All resources have been deleted."
echo ""
