# Costs

The monthly cost of what the platform holds, from published list prices. This
file grows every lesson; by lesson 9 it is the input to the FinOps work.

## Prices used

Read on **2026-10-20** from https://cloud.google.com/storage/pricing, for a
regional bucket (europe-west1), in USD.

| Item | Price | Source |
|---|---|---|
| Standard storage | $0.020 per GiB per month | Course material for europe-west1. The pricing page shows regional storage prices only in a region selector; **to confirm by selecting "Belgium (europe-west1)"** |
| Nearline, Coldline, Archive storage | $0.010, $0.004, $0.0012 per GiB per month | **Not read today**; to confirm on the same selector |
| Class A operations (writes, lists), Standard | $0.005 per 1,000 | Pricing page, 2026-10-20 |
| Class B operations (reads), Standard | $0.0004 per 1,000 | Pricing page, 2026-10-20 |
| Retrieval, Nearline / Coldline / Archive | $0.01 / $0.02 / $0.05 per GiB read | Pricing page, 2026-10-20 |
| Minimum storage duration, Nearline / Coldline / Archive | 30 / 90 / 365 days | Pricing page, 2026-10-20 |

## L02: the bronze bucket

| What | Quantity | Cost |
|---|---|---|
| Storage | 54,063,123 bytes = 0.0504 GiB, Standard | 0.0504 × $0.020 = **$0.0010 a month** |
| Writes for one load | 25 objects = 25 Class A operations | 25 / 1,000 × $0.005 = **$0.000125 per load** |
| Reads | Pipelines read bronze when silver is rebuilt: 25 Class B operations per full rebuild | $0.00001 per rebuild |

**Total today: about $0.001 a month**, plus a fraction of a cent per load. The
first landing was done twice (once in snappy, once in zstd), so 50 writes were
billed, about $0.00025.

The lifecycle policy ([infra/lifecycle.json](../infra/lifecycle.json)) moves
bronze to Nearline after 30 days. At this size that saves nothing measurable,
and every rebuild of silver from data older than 30 days pays the Nearline
retrieval fee ($0.01 per GiB read).

## If the data were a hundred times larger

| What | Today | ×100 |
|---|---|---|
| One load | 51.6 MiB | 5.0 GiB |
| Storage of one load | $0.001 a month | $0.10 a month |
| A full export every day for a month | 1.5 GiB, $0.03 a month | 151 GiB, **$3.02 a month**, growing every month |
| Writes per load | 25 | 25: one file per table per load, whatever its size |

At a hundred times the size, **storage of repeated full copies** becomes the
cost, while operations stay flat because the layout writes one file per table
per load. That is the argument for lesson 3 landing changes instead of full
copies, and for the lifecycle policy, which moves the older copies to cheaper
classes.
