# Configuration Variables

# GCP Project Details
export PROJECT_ID="your-gcp-project-id"
export REGION="us-central1"
export SERVICE_ACCOUNT="your-sa"
export GOOGLE_APPLICATION_CREDENTIALS="your-service-account-key.json"

# Bucket and Cluster
# Using a dataproc specific bucket name to avoid confusion with dataflow
export BUCKET_NAME="dataproc-demo-001" 
export CLUSTER_NAME="dataproc-cluster-demo"

# Paths
export GCS_SCRIPT_PATH="gs://${BUCKET_NAME}/scripts"
export GCS_DATA_PATH="gs://${BUCKET_NAME}/data"

# Local paths to python scripts
export LOCAL_GENERATE_SCRIPT="generate_data.py"
export LOCAL_MASK_SCRIPT="mask_phone_numbers.py"