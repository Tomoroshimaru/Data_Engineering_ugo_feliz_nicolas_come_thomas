from pathlib import Path

import pandas as pd

SCRIPT_DIR = Path(__file__).resolve().parent
CSV_DIR = SCRIPT_DIR.parent / "legacy_csv"
RESULTS_DIR = SCRIPT_DIR.parent / "scriptes_results"

df = pd.read_csv(CSV_DIR / "order_items.csv")
RESULTS_DIR.mkdir(exist_ok=True)
df.to_parquet(RESULTS_DIR / "order_items.parquet", compression="snappy")