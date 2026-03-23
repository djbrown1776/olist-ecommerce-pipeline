import kagglehub
import os
import time
import boto3
import pandas as pd
from dotenv import load_dotenv

load_dotenv()

S3_BUCKET = os.getenv("S3_BUCKET")
assert S3_BUCKET, "S3_BUCKET environment variable is not set"


def fetch_data(path, max_retries=3, retry_delay=2):
    dataframes = {}
    for filename in os.listdir(path):
        if filename.endswith(".csv"):
            file_path = os.path.join(path, filename)
            for attempt in range(max_retries):
                try:
                    df = pd.read_csv(file_path)
                    df["loaded_at"] = pd.Timestamp.now()
                    dataframes[filename] = df
                    break
                except Exception as e:
                    if attempt < max_retries - 1:
                        print(f"Error reading {filename}: {e}. Retrying in {retry_delay}s...")
                        time.sleep(retry_delay)
                    else:
                        print(f"Failed to read {filename} after {max_retries} attempts.")
    return dataframes


def upload_to_s3(dataframes, bucket):
    s3 = boto3.client("s3")
    date_str = pd.Timestamp.now().strftime("%Y-%m-%d")
    for filename, df in dataframes.items():
        table_name = filename.replace(".csv", "")
        key = f"raw/{table_name}/{table_name}_{date_str}.parquet"
        parquet_data = df.to_parquet(index=False, engine="pyarrow")
        s3.put_object(Bucket=bucket, Key=key, Body=parquet_data)
        print(f"Uploaded {key}")


def main():
    path = kagglehub.dataset_download("olistbr/brazilian-ecommerce")
    dataframes = fetch_data(path)

    if not dataframes:
        print("No data fetched. Exiting.")
        return

    print(f"Fetched {len(dataframes)} tables.")
    upload_to_s3(dataframes, bucket=S3_BUCKET)
    print("All files loaded to S3 💥")


if __name__ == "__main__":
    main()

