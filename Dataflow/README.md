# GCS to BigQuery Dataflow Pipeline

A simple Flex Template pipeline that reads CSV files from Google Cloud Storage and loads them into BigQuery.

## Pipeline Flow

```
GCS Bucket (CSV) → Dataflow Pipeline → BigQuery Table
```

## Project Structure

```
dataflow/
├── pipeline.py          # Main Dataflow pipeline code
├── Dockerfile           # Container image for Flex Template
├── requirements.txt     # Python dependencies
├── metadata.json        # Flex Template metadata
├── sample_data.csv      # Sample test data
├── setup_gcp.sh         # GCP setup script
└── README.md            # This file
```

## Prerequisites

1. **Google Cloud Project** with billing enabled
2. **Service Account** with roles:
   - Dataflow Admin
   - Dataflow Worker
   - Storage Admin
   - BigQuery Admin
   - Cloud Build Editor (for building images in GCP)
3. **Service Account JSON key** downloaded
4. **Tools installed:**
   - Google Cloud SDK (gcloud)
   - Python 3.8+
   - Git Bash or WSL (for running shell scripts on Windows)

**Note:** No Docker Desktop needed! We'll build images in GCP using Cloud Build.

## Setup Instructions

### 1. Set Up Python Virtual Environment

```bash
# Create virtual environment
python -m venv venv

# Activate virtual environment
# On Windows (Git Bash):
source venv/Scripts/activate
# On Linux/Mac:
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### 2. Configure GCP Variables

Edit `setup_gcp.sh` and update these variables:

```bash
PROJECT_ID="your-project-id"
REGION="us-central1"
SERVICE_ACCOUNT="your-sa@your-project.iam.gserviceaccount.com"
SA_KEY_PATH="/path/to/your-service-account-key.json"
BUCKET_NAME="your-unique-bucket-name"
DATASET_NAME="dataflow_dataset"
TABLE_NAME="output_table"
```

### 3. Run GCP Setup Script

```bash
# Make script executable
chmod +x setup_gcp.sh

# Run setup (creates bucket, dataset, enables APIs)
./setup_gcp.sh
```

This script will:
- Authenticate with your service account
- Enable required GCP APIs
- Create GCS bucket
- Create BigQuery dataset
- Upload sample data

### 4. Build Docker Image (in GCP using Cloud Build)

```bash
# Set variables
export PROJECT_ID="your-project-id"
export TEMPLATE_NAME="gcs-to-bq-template"
export IMAGE_NAME="gcr.io/$PROJECT_ID/$TEMPLATE_NAME"

# Build image in GCP (no local Docker needed!)
gcloud builds submit --tag $IMAGE_NAME .

# This command:
# - Uploads your code to GCP
# - Builds the Docker image in Google Cloud Build
# - Automatically pushes to Container Registry
# - No Docker Desktop required on your machine
```

### 5. Create Flex Template

```bash
export BUCKET_NAME="your-bucket-name"
export TEMPLATE_PATH="gs://$BUCKET_NAME/templates/$TEMPLATE_NAME.json"

gcloud dataflow flex-template build $TEMPLATE_PATH \
  --image $IMAGE_NAME \
  --sdk-language PYTHON \
  --metadata-file metadata.json
```

### 6. Run the Pipeline

```bash
# Set job parameters
export JOB_NAME="gcs-to-bq-job-$(date +%Y%m%d-%H%M%S)"
export INPUT_PATH="gs://$BUCKET_NAME/input/*.csv"
export OUTPUT_TABLE="$PROJECT_ID:$DATASET_NAME.$TABLE_NAME"
export SERVICE_ACCOUNT="your-sa@your-project.iam.gserviceaccount.com"

# Run the job
gcloud dataflow flex-template run $JOB_NAME \
  --template-file-gcs-location=$TEMPLATE_PATH \
  --region=$REGION \
  --parameters input_path=$INPUT_PATH \
  --parameters output_table=$OUTPUT_TABLE \
  --service-account-email=$SERVICE_ACCOUNT \
  --staging-location=gs://$BUCKET_NAME/temp \
  --temp-location=gs://$BUCKET_NAME/temp
```

## Customizing for Your Data

### Update CSV Parsing

Edit `pipeline.py` - the `ParseCSV` class (lines 20-30):

```python
def process(self, element):
    fields = element.split(',')
    yield {
        'your_column1': fields[0].strip(),
        'your_column2': fields[1].strip(),
        'your_column3': fields[2].strip()
    }
```

### Update BigQuery Schema

Edit `pipeline.py` - the `table_schema` (lines 45-52):

```python
table_schema = {
    'fields': [
        {'name': 'your_column1', 'type': 'STRING', 'mode': 'REQUIRED'},
        {'name': 'your_column2', 'type': 'INTEGER', 'mode': 'NULLABLE'},
        {'name': 'your_column3', 'type': 'FLOAT', 'mode': 'NULLABLE'}
    ]
}
```

After changes, rebuild the Docker image and recreate the template (steps 4-5).

## Monitoring

### View Job in Console
```
https://console.cloud.google.com/dataflow/jobs?project=YOUR_PROJECT_ID
```

### Check Job Status
```bash
gcloud dataflow jobs list --region=$REGION --status=active
```

### Query Results in BigQuery
```bash
bq query --use_legacy_sql=false \
  "SELECT * FROM $DATASET_NAME.$TABLE_NAME LIMIT 10"
```

## Troubleshooting

### Permission Errors
Ensure your service account has all required roles:
```bash
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT" \
  --role="roles/dataflow.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT" \
  --role="roles/dataflow.worker"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT" \
  --role="roles/storage.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT" \
  --role="roles/bigquery.admin"
```

### Docker Push Fails
```bash
gcloud auth configure-docker
gcloud auth print-access-token | docker login -u oauth2accesstoken --password-stdin https://gcr.io
```

### Pipeline Fails
- Check CSV format matches schema
- Verify input path is correct
- Check job logs in Cloud Console
- Ensure all APIs are enabled

## Cleanup

```bash
# Cancel running job
gcloud dataflow jobs cancel JOB_ID --region=$REGION

# Delete BigQuery dataset
bq rm -r -f -d $PROJECT_ID:$DATASET_NAME

# Delete GCS bucket
gsutil -m rm -r gs://$BUCKET_NAME

# Delete Docker image
gcloud container images delete $IMAGE_NAME --quiet
```

## Sample Data Format

The included `sample_data.csv`:
```csv
id,name,value
1,Alice,100
2,Bob,200
3,Charlie,300
```

Replace with your own CSV files in the same format, or customize the pipeline code.

## Additional Resources

- [Dataflow Documentation](https://cloud.google.com/dataflow/docs)
- [Apache Beam Python SDK](https://beam.apache.org/documentation/sdks/python/)
- [Flex Templates Guide](https://cloud.google.com/dataflow/docs/guides/templates/using-flex-templates)
