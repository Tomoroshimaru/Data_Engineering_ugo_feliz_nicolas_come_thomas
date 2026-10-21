"""Land the company's CSV export in bronze as Parquet, unchanged.

Every value is kept as the exact string the export wrote: no types inferred,
no cleaning, no deduplication, no dropped column. Types are silver's job.

    python ingestion/batch/export_to_bronze.py --source legacy_csv
    gcloud storage cp -r out/bronze gs://data-engineering-i2-toes-futcn/
"""

import argparse
from datetime import date
from pathlib import Path

import pandas as pd

# Tables holding credentials or card data stay out of bronze (ADR-0002).
EXCLUDED = {
    "customer": "pwd",
    "payment_details": "card_no, cvv",
}

parser = argparse.ArgumentParser()
parser.add_argument("--source", default="legacy_csv", help="folder holding the export's CSV files")
parser.add_argument("--out", default="out/bronze", help="local folder to write Parquet into")
parser.add_argument("--ingest-date", default=date.today().isoformat(), help="partition value, YYYY-MM-DD")
args = parser.parse_args()

for csv in sorted(Path(args.source).glob("*.csv")):
    table = csv.stem
    if table in EXCLUDED:
        print(f"  skip  {table:20s} holds {EXCLUDED[table]}")
        continue

    df = pd.read_csv(csv, dtype=str, keep_default_na=False)
    # The export's unnamed index column gets a name Parquet and BigQuery accept.
    df = df.rename(columns={"Unnamed: 0": "unnamed_0"})

    folder = Path(args.out) / table / f"ingest_date={args.ingest_date}"
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / "part-0.parquet"
    df.to_parquet(path, compression="zstd", index=False)
    print(f"  wrote {table:20s} {len(df):>9,} rows  {csv.stat().st_size:>12,} B csv  {path.stat().st_size:>12,} B parquet")
