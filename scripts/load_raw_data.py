"""
Load all Olist CSV files into the 'raw' schema of warehouse.duckdb.
Run once before `dbt run` / `dbt test`.

Usage:
    python scripts/load_raw_data.py
"""

import duckdb
import os

DATA_DIR = os.path.join(os.path.dirname(__file__), "..", "data")
DB_PATH = os.path.join(os.path.dirname(__file__), "..", "warehouse.duckdb")

TABLES = {
    "olist_customers_dataset":          "olist_customers_dataset.csv",
    "olist_sellers_dataset":            "olist_sellers_dataset.csv",
    "olist_products_dataset":           "olist_products_dataset.csv",
    "product_category_name_translation":"product_category_name_translation.csv",
    "olist_orders_dataset":             "olist_orders_dataset.csv",
    "olist_order_items_dataset":        "olist_order_items_dataset.csv",
    "olist_order_payments_dataset":     "olist_order_payments_dataset.csv",
    "olist_order_reviews_dataset":      "olist_order_reviews_dataset.csv",
}

def main():
    con = duckdb.connect(DB_PATH)
    con.execute("CREATE SCHEMA IF NOT EXISTS raw")

    for table, filename in TABLES.items():
        csv_path = os.path.join(DATA_DIR, filename).replace("\\", "/")
        con.execute(f"DROP TABLE IF EXISTS raw.{table}")
        con.execute(
            f"CREATE TABLE raw.{table} AS "
            f"SELECT * FROM read_csv_auto('{csv_path}', header=true)"
        )
        count = con.execute(f"SELECT count(*) FROM raw.{table}").fetchone()[0]
        print(f"  loaded raw.{table:45s} {count:>7,} rows")

    con.close()
    print("\nAll tables loaded into warehouse.duckdb — raw schema ready.")

if __name__ == "__main__":
    main()
