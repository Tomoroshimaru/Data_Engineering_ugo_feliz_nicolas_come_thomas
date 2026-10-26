# Review — Exercise 1: the platform modernisation proposal

Group TOES (Thomas Alaph, Féliz Luberne, Ugo Zanchi, Nicolas Gilhodes, Côme Bonneviale). We read the proposal, then checked it against the prototype in `l11-review`.

## 1. What is wrong

1. **§3 and §11 against the prototype: the sensitive columns are not deselected.** The document says passwords, card numbers and security codes never leave the source database. The connector (`ingestion/connector.json`) syncs `customer` and `payment_details` with `"sync_all_fields": true`. Every fifteen minutes, passwords and card data land in bronze, in a bucket the document says holds none, with versioning on, so every copy is kept. §11's "passwords and card numbers are not present" is built on that false statement. This one is invisible from the document alone.
2. **§3, the consumer commits its Kafka offset before writing the batch.** If it crashes between the two, up to 5,000 events are marked as read and never written. Nothing retries them and nothing alerts: we would only notice a gap in a chart weeks later, when the events have expired from Kafka.
3. **§2, the BI dashboard reads the Parquet files in bronze directly.** It sees raw data: duplicated order rows, blank-padded phones, the at-least-once replays. Finance reads gold and marketing reads the dashboard, so the company gets two revenue figures. That is the opposite of the second objective.
4. **§4, bronze is partitioned by `buyer_id`.** With one object per batch and one prefix per buyer, each batch is split into thousands of tiny files. The daily report, which needs one day across all buyers, has to list and open every prefix. Customer-level questions were never the workload; the workload is by day.
5. **§5, the "per-query cap" of 100 GB is not something you configure once.** `maximum_bytes_billed` is set on each job by whoever runs it. An analyst who does not set it has no cap. The only project-wide control is a daily quota, which is not what the document describes. *This is the one we are least sure is among the ten.*
6. **§6, `fct_order_lines` is described as "one row per order" but holds one row per order line.** The prototype's `unique` test on `order_id` therefore fails, and has been downgraded to a warning "while the pipeline stabilises", so it never stops a run. The region also comes from the customer's *current* default address: a customer with two default addresses doubles their lines and their revenue, and a customer who moves rewrites the region of every past order.
7. **§7, images are pushed as `:latest` on `python:3`.** We cannot say what ran last Tuesday, or roll back to it, and the base image changes under us without review. They are also public on Docker Hub, so our dbt project and the consumer's code are readable by anyone.
8. **§8, every task appends, and failures retry three times.** A load that fails after inserting part of its rows inserts them again on the retry, and a rerun of any day doubles it. Retries make a non-idempotent task worse, not safer.
9. **§9, the Terraform state is committed to the repository.** It holds every resource's attributes in clear, including secrets, and stays in the git history forever. Two people applying from their own machines have no lock and overwrite each other's state.
10. **§10, the €500 budget "prevents overspending".** A budget sends an email; it stops nothing. A runaway query or a loop of retries can exceed it by any amount. And without labels, nobody can say which pipeline caused it.
11. **§11, encryption at rest is presented as protection of personal data.** Encryption protects against a stolen disk, not against a reader. Analysts get dataset viewer on gold, so they read every address and phone number. Nothing is classified per column, and §11 does not say who can read the personal data, only that it is encrypted.

## 2. What we would fix first

1. **The connector (1).** On Monday, before anything else: stop syncing `customer` and `payment_details`, then purge them from bronze, including the old object versions. It is a few lines of config, but every fifteen minutes it runs, more card data lands in a place nobody is protecting.
2. **The offset commit (2).** Moving one line, `commit` after `write_batch`, is half an hour of work. It is the quietest problem in the document: every crash loses a batch for good, and in a year we would have a dataset with holes nobody can explain or fill.
3. **The dashboard on bronze (3).** It is the one still costing us in a year because nobody noticed. Each month finance and marketing reconcile two figures by hand, and the forecasting model is trained on whichever table someone picked. Pointing the dashboard at gold is a day; the cost of not doing it compounds.

We put the loud and dangerous one first, then the cheap and permanent one, then the quiet one that undermines the reason the platform exists.

## 3. What we decided was fine

**On-demand pricing (§5).** We considered flagging it, since capacity pricing is the usual answer for a scheduled workload. At this volume, with one team and a workload still changing, on-demand is defensible: no commitment, and a daily report that reads one day costs little. We would revisit it at ten times the analysts.

**Parquet rather than Iceberg or Delta (§4).** Defensible at this size, and the document states the trade-off honestly. What makes bronze hard to operate is the `buyer_id` layout, not the absence of a table format.

## 4. The disclosure

It told us what mattered most: the document was generated and its recommendations were not checked, so we read every claim as unverified. It should also have said that the prototype was generated separately, from the same prompt, and never compared with the document. That is exactly where the most serious defect sits. It should also have said that the figures (€400 a month, the 100 GB cap) are not measured.
