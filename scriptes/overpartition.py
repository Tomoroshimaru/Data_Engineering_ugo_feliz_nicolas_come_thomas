from pathlib import Path

import pandas as pd

SCRIPT_DIR = Path(__file__).resolve().parent
CSV_DIR = SCRIPT_DIR.parent / "legacy_csv"
RESULTS_DIR = SCRIPT_DIR.parent / "scriptes_results"

df = pd.read_csv(CSV_DIR / "order_items.csv").merge(
    pd.read_csv(CSV_DIR / "orders.csv")[["order_id", "order_date"]], on="order_id")
df["dt"] = pd.to_datetime(df.order_date).dt.strftime("%Y-%m-%d")
df = df[["order_id", "p_id", "qty", "price_at_purchase", "dt"]]

month = df[df.dt.str.startswith("2026-08")]
print("rows in the month:", len(month))

# the same month, two ways
RESULTS_DIR.mkdir(exist_ok=True)
month.to_parquet(RESULTS_DIR / "month_by_day", partition_cols=["dt"], basename_template="part-{i}.parquet")
month.to_parquet(RESULTS_DIR / "month_by_day_product", partition_cols=["dt", "p_id"], max_partitions=20000, basename_template="part-{i}.parquet")
