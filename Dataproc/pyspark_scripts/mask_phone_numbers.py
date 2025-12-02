from pyspark.sql import SparkSession
from pyspark.sql.functions import col, udf
from pyspark.sql.types import StringType
import sys

def mask_middle_eight(phone_number):
    """
    Masks the middle 8 digits of a phone number.
    
    Logic:
    - Keeps the first digit visible.
    - Masks the next 8 digits with '*'.
    - Keeps the last digit visible.
    - Works for 10-digit numbers (Standard format in many regions).
    
    Example: '9876543210' -> '9********0'
    """
    if not phone_number:
        return None
        
    s_num = str(phone_number)
    
    # Validation: Ensure it has at least 10 digits to mask "middle 8"
    # If less than 10, we can't really mask "middle 8" while keeping start/end.
    # You can adjust this logic to mask everything or return as is.
    if len(s_num) < 10:
        return s_num
    
    # Extract parts
    first_digit = s_num[0]
    last_digit = s_num[-1]
    
    # Masking
    masked_part = "*" * 8
    
    return f"{first_digit}{masked_part}{last_digit}"

def main():
    # Check arguments
    if len(sys.argv) < 3:
        print("Usage: mask_phone_numbers.py <input_path> <output_path>")
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2]

    # Initialize Spark Session
    spark = SparkSession.builder \
        .appName("Phone Number Masking Job") \
        .getOrCreate()

    print(f"Reading data from: {input_path}")
    
    # Read Parquet file
    df = spark.read.parquet(input_path)
    
    # Register UDF (User Defined Function)
    mask_udf = udf(mask_middle_eight, StringType())

    # Apply transformation
    # We check if 'phone_number' column exists to avoid errors
    if 'phone_number' in df.columns:
        print("Masking 'phone_number' column...")
        masked_df = df.withColumn("phone_number", mask_udf(col("phone_number")))
    else:
        print("WARNING: 'phone_number' column not found! Data will be copied without masking.")
        masked_df = df

    # Show sample of results
    print("Sample of masked data:")
    masked_df.show(5, truncate=False)

    # Write output
    print(f"Writing data to: {output_path}")
    masked_df.write.mode("overwrite").parquet(output_path)
    
    print("Job completed successfully.")
    spark.stop()

if __name__ == "__main__":
    main()
