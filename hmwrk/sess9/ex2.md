# Session 9 — Exercise 2: a FinOps review of somebody else's bill

LUBERNE Féliz — written as a group. **This bill is generated**: the course's `make_bill.py`, 60 days (1 July – 29 August 2026), real europe-west1 unit prices, invented quantities. It describes no real company. We loaded it into BigQuery and grouped every line by day. Figures marked *est.* in section 4 are our own projections, not read from the bill. All amounts are in euros, the bill's currency.

## 1. The three largest costs

| SKU | Total | Shape | What the days show |
|---|---|---|---|
| Class A Operations | 3,662.27 | **flat** | about 61 a day for 60 days (58 to 63), about 12.2 million operations a day |
| N2 Instance Core running in EMEA | 1,119.74 | **flat** | exactly 18.66 every day: 192 core-hours, i.e. 8 cores running 24 hours a day |
| Download Worldwide Destinations | 836.93 | **step** | zero for 30 days, then about 28 a day (232 GiB) from 31 July |

The two smaller lines carry the other shapes: BigQuery analysis is a **spike** (305.06 on 11 August against about 6.40 on other days), and storage is a **slope** (1.45 a day over the first two weeks, 4.15 over the last two), since nothing is ever deleted.

## 2. What we would investigate first

The egress. The largest line, operations, is flat: it costs the same every day from the first day of the bill to the last, so whatever causes it was designed, deployed and has not changed. Expensive, but explicable. Egress is the opposite: nothing for thirty days, then about 232 GiB leaving the region every day from 31 July, every day since, with no end in sight. Something changed that day that nobody wrote down: a new consumer, a new export, or data going somewhere it should not. Until we know which, we cannot even say whether it is a cost problem or a security one. The good news is that it is labelled `team=data-platform`, so there is somebody to ask, today.

## 3. The part nobody can be asked about

**1,963.50 of 6,468.49, 30 % of the bill, carries no label at all.** 93 % of it (1,825.19) is Class A operations: half of the bill's operations belong to no team. The rest is BigQuery analysis (96.34) and storage (41.97).

Labels never apply backwards, so these 60 days stay unattributed. What we would do is make sure the next 60 cannot be:

- **Find the source now, by elimination.** Every labelled operation belongs to `data-platform`; the unlabelled half has the same flat shape. We would list the buckets with no labels (`gcloud storage buckets list`) and ask `data-platform` which of their writers use them: most likely one of their own pipelines writing to a bucket that was created by hand.
- **Label through code, not by hand.** Every bucket and dataset declared in Terraform with the four keys (`team`, `environment`, `pipeline`, `lesson`), so labelling becomes a pull request instead of twenty pages of console.
- **Refuse unlabelled resources.** A check in CI that fails any Terraform plan where a bucket or dataset has no `team` label, and a monthly query on this export reporting the unlabelled share, so that 30 % is noticed in its first week, not after two months.

## 4. One optimisation: switch off the ML development machine outside working hours

**What we would change.** The N2 line is the ML team's, labelled `environment=dev`, `pipeline=experiments`. It runs 8 cores, 24 hours a day, weekends included: 192 core-hours every day of the 60, with no variation at all. A development machine that never changes its load is a machine nobody is using at night. We would stop it outside 08:00–20:00 on weekdays, with an instance schedule.

**The saving, in units first.**

- Today: 8 cores × 24 h = 192 core-hours a day, 1,344 a week.
- After: 8 cores × 12 h × 5 days = 480 core-hours a week. *est.*
- Saving: 864 core-hours a week, 64 % of the line.
- At the bill's unit price of 0.0972 per core-hour: 1,344 × 0.0972 = 130.64 a week today (the bill's own weekly figure), 480 × 0.0972 = 46.66 after, so **about 84 a week saved, about 720 over the bill's 60 days**. *est.*

The bill carries only the core line, not N2 memory, which is billed separately on a real export; the true saving would be larger by the memory's share.

**How we would confirm it, and when.** We would read `usage.amount` for this SKU, per day, in the billing export, not the cost: the quantity says directly whether the machine ran. It is trustworthy two days after the change, once the export has caught up, and the first Saturday is the cleanest test: it should read **0 core-hours**, and a weekday about 96.

**What would tell us we were wrong.** If a Saturday still shows 192 core-hours, the schedule is not applied. If the weekday figure drops but the ML team's experiments start failing or getting rerun in the evening, the machine was not idle at night: they were running long jobs on it, our diagnosis was wrong, and the right change is a cheaper machine type for those jobs, not a schedule.

## 5. What we would say to the team

> Hi all, I've been through the last 60 days of the cloud bill and I'd love 15 minutes with data-platform this week. Since 31 July about 230 GiB a day has been leaving the region (around 28 € a day) and I can't tell from the bill where it goes; probably something new and legitimate, but I'd like to write down what. Two smaller things for later: about 30 % of the spend has no labels, mostly storage operations, so I'll propose a Terraform label convention; and ML, your dev machine runs nights and weekends, would a 08:00–20:00 schedule get in your way?
