from pathlib import Path

import pandas as pd

SCRIPT_DIR = Path(__file__).resolve().parent
CSV_DIR = SCRIPT_DIR.parents[1] / "legacy_csv"

df = pd.read_csv(CSV_DIR / "order_items.csv")
df.to_parquet(SCRIPT_DIR / "order_items.parquet", compression="snappy")