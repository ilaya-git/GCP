# Dockerfile for Dataflow Flex Template
FROM gcr.io/dataflow-templates-base/python3-template-launcher-base

# Set environment variables
ENV FLEX_TEMPLATE_PYTHON_PY_FILE="/template/pipeline.py"
ENV FLEX_TEMPLATE_PYTHON_REQUIREMENTS_FILE="/template/requirements.txt"

# Copy pipeline files
COPY pipeline.py /template/pipeline.py
COPY requirements.txt /template/requirements.txt

# Install dependencies
RUN pip install --no-cache-dir -r /template/requirements.txt