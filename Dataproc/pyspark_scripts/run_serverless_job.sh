#!/bin/bash
set -e

# Load configuration
source ./config.sh

echo "==================================================="
echo "Running Dataproc Serverless (Batches) Execution"
echo "Project: ${PROJECT_ID}"
echo "Bucket: ${BUCKET_NAME}"
echo "==================================================="

# 1. Upload Scripts to GCS
echo "Uploading scripts to GCS..."
gsutil cp ${LOCAL_GENERATE_SCRIPT} ${GCS_SCRIPT_PATH}/
gsutil cp ${LOCAL_MASK_SCRIPT} ${GCS_SCRIPT_PATH}/

# 2. Run Data Generation (Serverless)
echo "Submitting Data Generation Job..."
BATCH_ID_GEN="dataproc-gen-$(date +%Y%m%d-%H%M%S)"
echo "Batch ID: $BATCH_ID_GEN"
gcloud dataproc batches submit pyspark ${GCS_SCRIPT_PATH}/${LOCAL_GENERATE_SCRIPT} \
    --batch=$BATCH_ID_GEN \
    --project=${PROJECT_ID} \
    --region=${REGION} \
    --version=2.2 \
    --deps-bucket=${BUCKET_NAME} \
    -- "${GCS_DATA_PATH}/input_data"

echo "Data Generation Complete."

# 3. Run Masking Job (Serverless)
echo "Submitting Masking Job..."
BATCH_ID_MASK="dataproc-mask-$(date +%Y%m%d-%H%M%S)"
echo "Batch ID: $BATCH_ID_MASK"
gcloud dataproc batches submit pyspark ${GCS_SCRIPT_PATH}/${LOCAL_MASK_SCRIPT} \
    --batch=$BATCH_ID_MASK \
    --project=${PROJECT_ID} \
    --region=${REGION} \
    --version=2.2 \
    --deps-bucket=${BUCKET_NAME} \
    -- "${GCS_DATA_PATH}/input_data" "${GCS_DATA_PATH}/output_data_serverless"

echo "==================================================="
echo "Serverless Pipeline Execution Completed Successfully"
echo "Output location: ${GCS_DATA_PATH}/output_data_serverless"
echo "==================================================="
