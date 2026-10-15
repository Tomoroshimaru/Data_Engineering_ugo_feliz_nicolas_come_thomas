"""Read clickstream events from Kafka and write them to partitioned Parquet."""

import json
import os
import time
from datetime import datetime, timezone

import pandas as pd
from confluent_kafka import Consumer

BOOTSTRAP = os.environ.get("KAFKA_BOOTSTRAP", "localhost:9092")
TOPIC = os.environ.get("KAFKA_TOPIC", "clickstream")
GROUP = os.environ["CONSUMER_GROUP"]           # your own: clickstream-<initials>
OUT = os.environ.get("OUT", "out/bronze/clickstream")
DLQ = os.environ.get("DLQ", "out/_dlq/clickstream")
BATCH = int(os.environ.get("BATCH", "200"))    # rows per file
PAUSE = float(os.environ.get("PAUSE_BEFORE_COMMIT", "0"))

REQUIRED = ("event_id", "event_type", "event_time", "buyer_id")

consumer = Consumer({
    "bootstrap.servers": BOOTSTRAP,
    "group.id": GROUP,
    "auto.offset.reset": "earliest",
    "enable.auto.commit": False,               # committed by hand. That is the lesson.
})
consumer.subscribe([TOPIC])

good, bad = [], []
written = 0


def write(rows, root):
    """One Parquet file per event date, under dt=YYYY-MM-DD/."""
    df = pd.DataFrame(rows)
    # Filed by event_time: the day it happened, not the day it reached us.
    df["dt"] = pd.to_datetime(df["event_time"], format="mixed").dt.strftime("%Y-%m-%d")
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%f")
    for dt, part in df.groupby("dt"):
        folder = os.path.join(root, f"dt={dt}")
        os.makedirs(folder, exist_ok=True)
        path = os.path.join(folder, f"part-{stamp}.parquet")
        part.drop(columns=["dt"]).to_parquet(path, index=False)
        print(f"  wrote {len(part):4d} rows  {path}")


def flush():
    global good, bad, written
    if not good and not bad:
        return
    if good:
        write(good, OUT)
        written += len(good)
    if bad:
        write(bad, DLQ)                        # the reason travels with the row
        print(f"  {len(bad)} row(s) quarantined")
    # The window. Everything above has happened; nothing below has.
    if PAUSE:
        print(f"  ... {PAUSE}s before committing the offset. Kill me now.")
        time.sleep(PAUSE)
    consumer.commit(asynchronous=False)
    print(f"  offset committed   (rows written so far: {written})")
    good, bad = [], []


print(f"reading {TOPIC} from {BOOTSTRAP} as group {GROUP}")
print(f"writing to {OUT}\n")
try:
    while True:
        msg = consumer.poll(1.0)
        if msg is None:
            flush()                            # idle: write what we have
            continue
        if msg.error():
            print(f"  kafka error: {msg.error()}")
            continue
        raw = msg.value().decode("utf-8")
        try:
            event = json.loads(raw)
            missing = [f for f in REQUIRED if f not in event]
            if missing:
                raise ValueError(f"missing field(s): {', '.join(missing)}")
            good.append(event)
        except Exception as exc:               # malformed: quarantine, never drop
            bad.append({"raw": raw, "reason": str(exc),
                        "event_time": datetime.now(timezone.utc).isoformat(),
                        "topic": msg.topic(), "partition": msg.partition(),
                        "offset": msg.offset()})
        if len(good) + len(bad) >= BATCH:
            flush()
except KeyboardInterrupt:
    # Not a tidy shutdown. This is what a crash looks like.
    print("\nkilled")
    os._exit(1)
