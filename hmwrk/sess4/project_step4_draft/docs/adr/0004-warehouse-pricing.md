# ADR-0004: Pay for BigQuery on demand, with a per-query cap

- **Status:** proposed
- **Date:** 2026-10-20
- **Author:** Féliz Luberne
- **Lesson:** L04

## Context

The warehouse (dataset `toes_ugo_feliz_thomas_warehouse`, europe-west1) holds seven native tables of 3 to 29 MB each. BigQuery offers two meters: on demand, billed per byte scanned, or capacity, billed per slot-hour whether used or not.

**The workload, in numbers.** The per-query figures are measured; the volume and timing are estimates, labelled as such.

| What | Figure | Source |
|------|--------|--------|
| Queries a day | about 200 | **Estimate**: three analysts exploring, the ML team's daily extract, and a few dashboards from lesson 9. |
| Concentration in time | about 90% between 09:00 and 18:00 | **Estimate**: analysts work in the day; the ML extract is one nightly query. |
| Bytes processed by a typical query | 13 to 16 MB | **Measured**: queries A, B and F after tuning ([warehouse-tuning.md](../warehouse-tuning.md)). |
| Bytes billed by a typical query | 20 to 40 MiB | **Measured**: the 10 MiB minimum per table read dominates; A and B read four tables. |

At this size, **the billing minimum, not the data, drives the bill**: query B processes 13.4 MB and is billed 40 MiB.

## The crossover arithmetic

**On demand.** 200 queries × 40 MiB × 30 days = 234 GiB ≈ **0.23 TiB a month** billed. The first TiB each month is free:

max(0, 0.23 − 1) × $7.50 = **$0 a month**.

**Capacity.** The smallest reservation is 50 slots of the Standard edition, at the list price of $0.04 per slot-hour (US list price; we could not find a clear europe-west1 figure, which is usually a little higher):

| Reservation | Hours a month | Cost |
|-------------|---------------|------|
| 50 slots, working hours only (10 h × 22 days) | 220 | 50 × $0.04 × 220 = **$440** |
| 50 slots, always on | 730 | 50 × $0.04 × 730 = **$1,460** |

**Where the lines cross.** On demand costs $440 a month at (440 / 7.50) + 1 ≈ **60 TiB billed a month**, and $1,460 at about **196 TiB**. Our estimate is 0.23 TiB: about 250 times below the cheapest crossover.

## Options considered

| Option | For | Against |
|---|---|---|
| On demand | Costs nothing at our volume; nothing to size; the peak is served by the shared slot pool. | No ceiling on the bill: one careless query, or one loop, is paid per byte. |
| Capacity, working hours | Flat, predictable bill. | $440 a month for a workload worth $0, and paid during idle hours too. |
| Capacity, always on | Same, plus the nightly jobs. | $1,460 a month for the same workload. |

## Criteria

**Cost** decides it, by a factor of about 250. **Workload** confirms it: the load is light and concentrated in office hours, so a reservation would sit idle most of the time it is paid for.

## Decision

Use BigQuery **on demand**, with `maximum_bytes_billed` set to 50 MiB on every query (set where, and seen to trip: [warehouse-tuning.md](../warehouse-tuning.md#7-the-cap)).

## Consequences

- **What it costs us: an unbounded bill.** On demand has no monthly ceiling. The per-query cap stops one huge query, but not a thousand small ones: a dashboard refreshing in a loop runs queries that each pass the cap. A daily quota per user would close that gap; it needs a project administrator, which we are not.
- **Tuning is worth bytes, not time.** Every partition and filter shows up directly in the bill, so the tuning on [warehouse-tuning.md](../warehouse-tuning.md) is measured in bytes processed. The materialised view, which saves 1.14x in bytes, would be worth more on a time-billed warehouse than it is here.
- **What would change our mind, as a number to watch:** bytes billed a month, from `SUM(total_bytes_billed)` in `INFORMATION_SCHEMA.JOBS_BY_PROJECT`. **Above 30 TiB a month for two months running** (half the cheapest crossover), we re-run this arithmetic with measured volumes instead of estimates.
