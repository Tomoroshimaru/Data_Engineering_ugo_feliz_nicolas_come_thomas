import os
import pandas as pd
import psycopg

DSN   = os.environ["DATABASE_URL"]
TABLE = os.environ.get("TABLE", "orders")
OUT   = os.environ.get("OUT", "/data")

with psycopg.connect(DSN) as conn, conn.cursor() as cur:
    cur.execute(f"SELECT * FROM {TABLE}")
    df = pd.DataFrame(cur.fetchall(), columns=[c.name for c in cur.description])

os.makedirs(OUT, exist_ok=True)
path = os.path.join(OUT, f"{TABLE}.parquet")
df.to_parquet(path, index=False)
print(f"{len(df)} rows -> {path}", flush=True)


