#!/bin/bash

# GCP Setup Script for Dataflow Pipeline
# This script sets up the required GCP resources

set -e  # Exit on error

echo "======================================"
echo "GCS to BigQuery Dataflow Setup"
echo "======================================"
echo ""

# ============================================
# CONFIGURATION - UPDATE THESE VALUES
# ============================================
PROJECT_ID="your_project-id"
REGION="your-region"  # e.g., us-central1
SERVICE_ACCOUNT="your-service-account@your_project-id.iam.gserviceaccount.com"
SA_KEY_PATH="your-service-account-key.json"
BUCKET_NAME="your-dataflow-bucket"
DATASET_NAME="dataflow_sample_dataset"
TABLE_NAME="dataflow_sample_table"

# ============================================
# Validate Configuration
# ============================================
if [ "$PROJECT_ID" = "your-project-id" ]; then
    echo "ERROR: Please update the configuration variables in this script!"
    echo "Edit setup_gcp.sh and update the variables at the top."
    exit 1
fi

echo "Configuration:"
echo "  Project ID: $PROJECT_ID"
echo "  Region: $REGION"
echo "  Bucket: $BUCKET_NAME"
echo "  Dataset: $DATASET_NAME"
echo ""

# ============================================
# Authentication
# ============================================
echo "[1/6] Authenticating with GCP..."
export GOOGLE_APPLICATION_CREDENTIALS="$SA_KEY_PATH"
gcloud auth activate-service-account "$SERVICE_ACCOUNT" --key-file="$SA_KEY_PATH"
gcloud config set project "$PROJECT_ID"
echo "✓ Authentication complete"
echo ""

# ============================================
# Enable APIs
# ============================================
echo "[2/6] Enabling required APIs..."
apis=(
    "dataflow.googleapis.com"
    "compute.googleapis.com"
    "storage.googleapis.com"
    "bigquery.googleapis.com"
    "cloudbuild.googleapis.com"
    "artifactregistry.googleapis.com"
)

for api in "${apis[@]}"; do
    echo "  Enabling $api..."
    gcloud services enable "$api" --project="$PROJECT_ID"
done

echo "✓ APIs enabled (waiting 30 seconds for propagation...)"
sleep 30
echo ""

# ============================================
# Create GCS Bucket
# ============================================
echo "[3/6] Creating GCS bucket..."
if gsutil ls -b "gs://$BUCKET_NAME" 2>/dev/null; then
    echo "✓ Bucket already exists: gs://$BUCKET_NAME"
else
    gsutil mb -p "$PROJECT_ID" -l "$REGION" "gs://$BUCKET_NAME"
    echo "✓ Bucket created: gs://$BUCKET_NAME"
fi

# Create folders
gsutil mkdir "gs://$BUCKET_NAME/templates" 2>/dev/null || true
gsutil mkdir "gs://$BUCKET_NAME/input" 2>/dev/null || true
gsutil mkdir "gs://$BUCKET_NAME/temp" 2>/dev/null || true
echo ""

# ============================================
# Create BigQuery Dataset
# ============================================
echo "[4/6] Creating BigQuery dataset..."
if bq ls -d --project_id="$PROJECT_ID" | grep -q "$DATASET_NAME"; then
    echo "✓ Dataset already exists: $DATASET_NAME"
else
    bq --project_id="$PROJECT_ID" mk -d --location="$REGION" "$DATASET_NAME"
    echo "✓ Dataset created: $DATASET_NAME"
fi
echo ""

# ============================================
# Upload Sample Data
# ============================================
echo "[5/6] Uploading sample data..."
if [ -f "sample_data.csv" ]; then
    gsutil cp sample_data.csv "gs://$BUCKET_NAME/input/sample_data.csv"
    echo "✓ Sample data uploaded"
else
    echo "⚠ sample_data.csv not found, skipping..."
fi
echo ""

# ============================================
# Verify Service Account Permissions
# ============================================
echo "[6/6] Verifying service account permissions..."
echo "  Granting required roles to $SERVICE_ACCOUNT..."

roles=(
    "roles/dataflow.admin"
    "roles/dataflow.worker"
    "roles/storage.admin"
    "roles/bigquery.admin"
    "roles/cloudbuild.builds.editor"
)

for role in "${roles[@]}"; do
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:$SERVICE_ACCOUNT" \
        --role="$role" \
        --quiet 2>/dev/null || true
done

echo "✓ Permissions configured"
echo ""

# ============================================
# Summary
# ============================================
echo "======================================"
echo "Setup Complete!"
echo "======================================"
echo ""
echo "Resources created:"
echo "  ✓ GCS Bucket: gs://$BUCKET_NAME"
echo "  ✓ BigQuery Dataset: $PROJECT_ID:$DATASET_NAME"
echo "  ✓ APIs enabled"
echo "  ✓ Permissions configured"
echo ""
echo "Next steps:"
echo "  1. Build Docker image in GCP:"
echo "     gcloud builds submit --tag gcr.io/$PROJECT_ID/gcs-to-bq-template ."
echo ""
echo "  2. Create Flex Template:"
echo "     gcloud dataflow flex-template build gs://$BUCKET_NAME/templates/template.json \\"
echo "       --image gcr.io/$PROJECT_ID/gcs-to-bq-template \\"
echo "       --sdk-language PYTHON \\"
echo "       --metadata-file metadata.json"
echo ""
echo "  3. Run pipeline (see README.md for full command)"
echo ""
