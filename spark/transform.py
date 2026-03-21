import sys
from awsglue.utils import getResolvedOptions
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import TimestampType, DoubleType, IntegerType

args = getResolvedOptions(sys.argv, ["S3_BUCKET", "RAW_PREFIX", "SILVER_PREFIX"])

S3_BUCKET = args["S3_BUCKET"]
RAW_PREFIX = args["RAW_PREFIX"]
SILVER_PREFIX = args["SILVER_PREFIX"]

spark = (
    SparkSession.builder.appName("olist-transform").getOrCreate()
)

RAW_PATH = f"s3://{S3_BUCKET}/{RAW_PREFIX}"
SILVER_PATH = f"s3://{S3_BUCKET}/{SILVER_PREFIX}"

# Read 

print("Reading raw tables from S3.")

orders = spark.read.parquet(f"{RAW_PATH}/olist_orders_dataset/")
order_items = spark.read.parquet(f"{RAW_PATH}/olist_order_items_dataset/")
products = spark.read.parquet(f"{RAW_PATH}/olist_products_dataset/")
sellers = spark.read.parquet(f"{RAW_PATH}/olist_sellers_dataset/")
customers = spark.read.parquet(f"{RAW_PATH}/olist_customers_dataset/")
payments = spark.read.parquet(f"{RAW_PATH}/olist_order_payments_dataset/")
reviews = spark.read.parquet(f"{RAW_PATH}/olist_order_reviews_dataset/")
category_translation = spark.read.parquet(f"{RAW_PATH}/product_category_name_translation/")

# Transform

print("Building silver order_details.")

order_details = (
    order_items
    .join(orders, on="order_id", how="inner")
    .join(customers, on="customer_id", how="inner")
    .join(products, on="product_id", how="left")
    .join(category_translation, on="product_category_name", how="left")
    .join(sellers, on="seller_id", how="left")
    .select(
        #  From order_items
        F.col("order_id"),
        F.col("order_item_id").cast(IntegerType()),
        F.col("price").cast(DoubleType()),
        F.col("freight_value").cast(DoubleType()),
        F.col("shipping_limit_date").cast(TimestampType()),

        # From orders
        F.col("order_status"),
        F.col("order_purchase_timestamp").cast(TimestampType()),
        F.col("order_approved_at").cast(TimestampType()),
        F.col("order_delivered_carrier_date").cast(TimestampType()),
        F.col("order_delivered_customer_date").cast(TimestampType()),
        F.col("order_estimated_delivery_date").cast(TimestampType()),

        # From customers
        F.col("customer_unique_id"),
        F.col("customer_city"),
        F.col("customer_state"),

        # From products
        F.col("product_id"),
        F.col("product_category_name"),
        F.col("product_weight_g").cast(IntegerType()),
        F.col("product_length_cm").cast(IntegerType()),
        F.col("product_height_cm").cast(IntegerType()),
        F.col("product_width_cm").cast(IntegerType()),

        # From category_translation
        F.col("product_category_name_english"),

        # From sellers
        F.col("seller_id"),
        F.col("seller_city"),
        F.col("seller_state"),
    )
)

order_details = (
    order_details
    .withColumn("total_item_value", F.col("price") + F.col("freight_value"))
    .withColumn(
        "delivery_days",
        F.datediff(
            F.col("order_delivered_customer_date"),
            F.col("order_purchase_timestamp")
        )
    )
    .withColumn(
        "estimated_vs_actual_days",
        F.datediff(
            F.col("order_estimated_delivery_date"),
            F.col("order_delivered_customer_date")
        )
    )
)

print("Building silver order_payments.")

order_payments = (
    payments
    .join(orders, on="order_id", how="inner")
    .select(
        F.col("order_id"),
        F.col("order_status"),
        F.col("order_purchase_timestamp").cast(TimestampType()),
        F.col("payment_sequential").cast(IntegerType()),
        F.col("payment_type"),
        F.col("payment_installments").cast(IntegerType()),
        F.col("payment_value").cast(DoubleType()),
    )
)

print("Building silver order_reviews.")

order_reviews = (
    reviews
    .join(orders, on="order_id", how="inner")
    .select(
        F.col("order_id"),
        F.col("order_status"),
        F.col("order_purchase_timestamp").cast(TimestampType()),
        F.col("review_id"),
        F.col("review_score").cast(IntegerType()),
        F.col("review_comment_title"),
        F.col("review_comment_message"),
        F.col("review_creation_date").cast(TimestampType()),
        F.col("review_answer_timestamp").cast(TimestampType()),
    )
)

print("Writing silver tables to S3...")

# Write 
order_details.coalesce(2).write.mode("overwrite").parquet(
    f"{SILVER_PATH}/order_details/"
)

order_payments.coalesce(2).write.mode("overwrite").parquet(
    f"{SILVER_PATH}/order_payments/"
)

order_reviews.coalesce(2).write.mode("overwrite").parquet(
    f"{SILVER_PATH}/order_reviews/"
)

spark.stop()
print("Transform complete")