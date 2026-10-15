# Session 3 — Exercise 1: three ways to extract, and what each one misses

LUBERNE Féliz — route 1 (Airbyte on my machine, abctl). Company stack:
albert-marketplace (PostgreSQL 17, Kafka), with its load generator running
throughout.

## The table

| | New rows | Updates | Deletes | Duplicates on restart | Secrets excluded |
|---|---|---|---|---|---|
| **Incremental batch** (step C) | Yes: `ZZZFL` arrived on the next sync. | **No**: the price of `0124784577` changed to 99.99 and the sync did not bring it, because `p_id` did not move. | **No**: a deleted row leaves nothing for the cursor to read. | **Yes, on every run**, with no crash: the boundary row `B0CHXWTSM6` came back on a sync where nothing had changed. | Yes, at the connector: `pwd`, `card_no` and `cvv` deselected, absent from the destination. |
| **Change data capture** (step B) | Yes: the `INSERT` is in the log. | Yes: the `UPDATE` carries the new price (24.50). | Yes: the `DELETE` is in the log. | Possible: after a crash the slot replays from its last confirmed position. | Only if configured: the log carries every column of every changed row. |
| **Streaming consumer** (step A) | Only what the producer emits. | Only if the producer emits an update event. | Only if the producer emits a delete event. | **Yes, measured**: 200 duplicates after one crash. | Only for what the producer chose to put in the event. |

## The delivery guarantees

- **Incremental batch: at least once.** The cursor comparison is "greater than or equal", so the row sitting on the boundary is read again on every run: with nothing changed, one record still moved.
- **Change data capture: at least once.** The slot only advances when the reader confirms, so a crash replays from the last confirmed position; the log sequence numbers make deduplication possible downstream.
- **Streaming consumer: at least once, by construction.** `flush()` writes the Parquet file and only then commits the Kafka offset; killed between the two, the rows are written but not marked as read, and are read again.

## Step A: the four numbers

| Files | Rows | Distinct `event_id` | Duplicates |
|---|---|---|---|
| 11 | 2,200 | 2,000 | **200** |

I killed the consumer once, during the 20-second pause after a 200-row file
was written and before its offset was committed. On restart the consumer
group resumed from the last committed offset and read those 200 events again:
one killed flush gives back exactly one batch.

With the 20-second pause, a new file appeared roughly every 16 to 22 seconds.
All files landed in `dt=2026-09-15`, the date of the events, not the day they
were read.

## Step B: what a cursor would have missed

Of my three changes to product `EX1FL` (insert at 21.98, price corrected to
24.50, delete), a cursor on a date column would have found only the insert.
The price correction moves no cursor column, and the delete leaves no row to
find; the write-ahead log has all three, because it records what the database
did rather than what the table says now. The cost to the business: the
warehouse keeps reporting a price nobody was charged and a product that no
longer exists, and nothing raises an error, so it is found by reconciliation
weeks later, if at all.

The slot also showed what it costs to forget one: with nobody reading it, the
WAL it retained grew from 343 kB to 796 kB in a few minutes, because the load
generator keeps writing. I dropped it.

## Step C: what moved, sync by sync

All on table `product` (42,858 rows), cursor `p_id`:

| Sync | Change made before it | Records moved | What arrived |
|---|---|---|---|
| Full refresh, overwrite | none | 42,858 | the whole table |
| First incremental | none | 42,858 | the whole table; cursor set at `B0CHXWTSM6` |
| Incremental | **none** | **1** | `B0CHXWTSM6`, the boundary row |
| Incremental | inserted `ZZZFL` | **2** | `ZZZFL` and `B0CHXWTSM6` again |
| Incremental | price of `0124784577` set to 99.99 | **1** | `ZZZFL` only, the new boundary; **the new price is not there** |

The record count alone is misleading: after the update it shows one record,
which looks like a change was captured. Opening the output shows that the
record is the boundary row and the corrected price never left the source.

## Deviation from the route, and the grant

The GCS destination needs an HMAC key on a service account with access to my
bucket. My account can neither create service accounts nor list HMAC keys in
the project, so I could not set it up. I used a PostgreSQL destination instead
(a separate `airbyte_dest_sess3` database on the same server), which shows the
same cursor behaviour row by row.

So nothing was granted to anyone outside my machine. One grant still deserves
a line: the Airbyte source holds the `postgres` superuser password, far more
than a read-only extraction needs. In a real deployment it should be a
dedicated user with `SELECT` on the extracted tables only, revoked by dropping
that user or deleting the source in Airbyte. Excluding `pwd`, `card_no` and
`cvv` also left `email` and `phone` in the copy of `customer`: deselecting
credentials is not the same as excluding personal data.
