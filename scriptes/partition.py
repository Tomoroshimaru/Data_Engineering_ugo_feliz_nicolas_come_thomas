from pathlib import Path

import pandas as pd

SCRIPT_DIR = Path(__file__).resolve().parent
CSV_DIR = SCRIPT_DIR.parent / "legacy_csv"

df = pd.read_csv(CSV_DIR / "order_items.csv").merge(pd.read_csv(CSV_DIR / "orders.csv")[["order_id", "order_date"]], on="order_id")
df["dt"] = pd.to_datetime(df.order_date).dt.strftime("%Y-%m-%d")
df = df[["order_id", "p_id", "qty", "price_at_purchase", "dt"]]

df.to_parquet(SCRIPT_DIR.parent / "results" / "by_day", partition_cols=["dt"], max_partitions=2000, basename_template="part-{i}.parquet")