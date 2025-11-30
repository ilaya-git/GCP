"""
Simple GCS to BigQuery Dataflow Pipeline
Reads CSV files from Google Cloud Storage and writes to BigQuery
"""

import argparse
import logging
import apache_beam as beam
from apache_beam.options.pipeline_options import PipelineOptions
from apache_beam.io import ReadFromText, WriteToBigQuery
from apache_beam.io.gcp.bigquery import BigQueryDisposition


class ParseCSV(beam.DoFn):
    """Parse CSV line into dictionary"""
    
    def process(self, element):
        try:
            # Split CSV line (adjust based on your CSV structure)
            fields = element.split(',')
            
            # Example: assuming CSV has 3 columns: id, name, value
            # Modify this based on your actual CSV structure
            yield {
                'id': fields[0].strip(),
                'name': fields[1].strip(),
                'value': fields[2].strip()
            }
        except Exception as e:
            logging.error(f"Error parsing line: {element}, Error: {e}")


def run(argv=None):
    """Main pipeline execution"""
    
    parser = argparse.ArgumentParser()
    
    # Pipeline arguments
    parser.add_argument(
        '--input_path',
        required=True,
        help='Input GCS path (e.g., gs://your-bucket/input/*.csv)'
    )
    parser.add_argument(
        '--output_table',
        required=True,
        help='Output BigQuery table (format: project:dataset.table)'
    )
    
    known_args, pipeline_args = parser.parse_known_args(argv)
    
    # Pipeline options
    pipeline_options = PipelineOptions(pipeline_args)
    
    # BigQuery schema - modify based on your data
    table_schema = {
        'fields': [
            {'name': 'id', 'type': 'STRING', 'mode': 'REQUIRED'},
            {'name': 'name', 'type': 'STRING', 'mode': 'NULLABLE'},
            {'name': 'value', 'type': 'STRING', 'mode': 'NULLABLE'}
        ]
    }
    
    # Create and run pipeline
    with beam.Pipeline(options=pipeline_options) as p:
        (p
         | 'Read from GCS' >> ReadFromText(known_args.input_path, skip_header_lines=1)
         | 'Parse CSV' >> beam.ParDo(ParseCSV())
         | 'Write to BigQuery' >> WriteToBigQuery(
             known_args.output_table,
             schema=table_schema,
             write_disposition=BigQueryDisposition.WRITE_APPEND,
             create_disposition=BigQueryDisposition.CREATE_IF_NEEDED
         ))


if __name__ == '__main__':
    logging.getLogger().setLevel(logging.INFO)
    run()
