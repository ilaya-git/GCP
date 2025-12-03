#!/bin/bash
set -e

# Load configuration
source ./config.sh

echo "==================================================="
echo "Running Dataproc Standalone Cluster Execution"
echo "Project: ${PROJECT_ID}"
echo "Cluster: ${CLUSTER_NAME}"
echo "==================================================="

# 1. Upload Scripts to GCS
echo "Uploading scripts to GCS..."
gsutil cp ${LOCAL_GENERATE_SCRIPT} ${GCS_SCRIPT_PATH}/
gsutil cp ${LOCAL_MASK_SCRIPT} ${GCS_SCRIPT_PATH}/

# 2. Create Cluster
echo "Creating Dataproc Cluster ${CLUSTER_NAME}..."
# Using single-node for cost efficiency in this demo
gcloud dataproc clusters create ${CLUSTER_NAME} \
    --project=${PROJECT_ID} \
    --region=${REGION} \
    --single-node \
    --master-machine-type=n1-standard-2 \
    --image-version=2.1-debian11

# 3. Submit Data Generation Job
# Note: We can submit to the cluster, but for generation we could also just use the serverless script. 
# Here we submit to the cluster to demonstrate standalone usage.
echo "Submitting Data Generation Job to Cluster..."
gcloud dataproc jobs submit pyspark ${GCS_SCRIPT_PATH}/${LOCAL_GENERATE_SCRIPT} \
    --cluster=${CLUSTER_NAME} \
    --region=${REGION} \
    --project=${PROJECT_ID} \
    -- \
    "${GCS_DATA_PATH}/input_data"

# 4. Submit Masking Job
echo "Submitting Masking Job to Cluster..."
gcloud dataproc jobs submit pyspark ${GCS_SCRIPT_PATH}/${LOCAL_MASK_SCRIPT} \
    --cluster=${CLUSTER_NAME} \
    --region=${REGION} \
    --project=${PROJECT_ID} \
    -- \
    "${GCS_DATA_PATH}/input_data" \
    "${GCS_DATA_PATH}/output_data_standalone"

echo "Jobs Completed."

# 5. Delete Cluster
echo "Deleting Cluster ${CLUSTER_NAME}..."
gcloud dataproc clusters delete ${CLUSTER_NAME} \
    --region=${REGION} \
    --project=${PROJECT_ID} \
    --quiet

echo "==================================================="
echo "Standalone Pipeline Execution Completed Successfully"
echo "Output location: ${GCS_DATA_PATH}/output_data_standalone"
echo "==================================================="
