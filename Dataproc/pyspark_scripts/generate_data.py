from pyspark.sql import SparkSession
from pyspark.sql.functions import expr
import sys

def main():
    if len(sys.argv) != 2:
        print("Usage: generate_data.py <output_path>")
        sys.exit(1)

    output_path = sys.argv[1]

    spark = SparkSession.builder \
        .appName("Generate Sample Data") \
        .getOrCreate()

    # Generate data using Spark SQL
    # We'll create 100 rows
    num_rows = 100
    
    # Create a DataFrame with a range of numbers
    df = spark.range(1, num_rows + 1).toDF("id")
    
    # Add columns
    # Phone number: Generate random 10 digit number. 
    # Using simple math to generate pseudo-random 10 digit numbers for demo
    # (1000000000 + id * 12345) % 9999999999 is a simple way to get varied numbers, 
    # or just use rand() * ...
    
    df_with_data = df.selectExpr(
        "id",
        "concat('Person_', id) as name",
        "cast(1000000000 + floor(rand() * 8999999999) as string) as phone_number",
        "concat('person_', id, '@example.com') as email"
    )

    print("Generated Data Sample:")
    df_with_data.show(5)

    # Write to Parquet
    df_with_data.write.mode("overwrite").parquet(output_path)
    
    print(f"Sample data generated at {output_path}")
    spark.stop()

if __name__ == "__main__":
    main()
