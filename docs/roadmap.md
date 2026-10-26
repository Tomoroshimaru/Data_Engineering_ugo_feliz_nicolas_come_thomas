# Roadmap: Albert's Marketplace platform

Source of the GitHub Project. One row = one issue. Dates are YYYY-MM-DD. Who = GitHub handle, or `?` for nobody yet. Status = Todo | In Progress | Done. The lessons are over; the last session, 10 November, is the defence.

## Milestones

| Milestone | Due |
|---|---|
| Step 1 · Start the platform | 2026-10-28 |
| Step 2 · Bronze layer | 2026-10-28 |
| Step 3 · Ingestion | 2026-10-30 |
| Step 4 · Warehouse | 2026-10-31 |
| Step 5 · dbt and the medallion | 2026-11-03 |
| Step 6 · Packaged jobs | 2026-11-04 |
| Step 7 · Orchestration | 2026-11-06 |
| Step 8 · Infrastructure as code | 2026-11-04 |
| Step 9 · FinOps | 2026-11-06 |
| Step 10 · Security and governance | 2026-11-06 |
| Defence | 2026-11-09 |

## Issues

| # | Task | Milestone | Who | Start | Target | Status |
|---|---|---|---|---|---|---|
| 1 | Team table and working rules in README | Step 1 · Start the platform | fefelbrn | 2026-10-20 | 2026-10-20 | Done |
| 2 | docs/data-flows.md | Step 1 · Start the platform | fefelbrn | 2026-10-20 | 2026-10-20 | Done |
| 3 | ADR-0001 target architecture | Step 1 · Start the platform | fefelbrn | 2026-10-20 | 2026-10-20 | Done |
| 4 | docs/architecture.md with the diagram | Step 1 · Start the platform | fefelbrn | 2026-10-20 | 2026-10-21 | Done |
| 5 | Star schema sketch, daily demand | Step 1 · Start the platform | fefelbrn | 2026-10-20 | 2026-10-20 | Done |
| 6 | Review and merge the PR grpwrk → main | Step 1 · Start the platform | Tomoroshimaru | 2026-10-27 | 2026-10-28 | Todo |
| 7 | One commit per member (Côme: add GitHub handle to README) | Step 1 · Start the platform | ? | 2026-10-27 | 2026-10-28 | Todo |
| 8 | Check repo private, invitations accepted, mail sent | Step 1 · Start the platform | Tomoroshimaru | 2026-10-27 | 2026-10-27 | Todo |
| 9 | ADR-0002 bronze layout, data dictionary, costs | Step 2 · Bronze layer | fefelbrn | 2026-10-21 | 2026-10-21 | Done |
| 10 | Upload the bronze export to the group bucket and check it | Step 2 · Bronze layer | fefelbrn | 2026-10-27 | 2026-10-28 | In Progress |
| 11 | Ingestion: batch extract, clickstream consumer, CDC | Step 3 · Ingestion | ugozchi | 2026-10-27 | 2026-10-30 | Todo |
| 12 | Move the warehouse draft from homework to the repo | Step 4 · Warehouse | fefelbrn | 2026-10-28 | 2026-10-29 | Todo |
| 13 | Warehouse tuning: partitioning, clustering, measurements | Step 4 · Warehouse | ngilhodes-netizen | 2026-10-28 | 2026-10-31 | Todo |
| 14 | dbt project: staging, marts, fct_daily_demand with tests | Step 5 · dbt and the medallion | fefelbrn | 2026-10-30 | 2026-11-03 | Todo |
| 15 | Dockerfile for the ingestion job, pushed with a pinned tag | Step 6 · Packaged jobs | Tomoroshimaru | 2026-11-02 | 2026-11-04 | Todo |
| 16 | Airflow DAG: ingest, load, dbt build | Step 7 · Orchestration | Tomoroshimaru | 2026-11-03 | 2026-11-06 | Todo |
| 17 | Terraform for bucket, datasets, labels | Step 8 · Infrastructure as code | ugozchi | 2026-10-31 | 2026-11-04 | Todo |
| 18 | Cost ledger in docs/costs.md | Step 9 · FinOps | ngilhodes-netizen | 2026-11-03 | 2026-11-06 | Todo |
| 23 | Labels on the group bucket and dataset, through Terraform | Step 9 · FinOps | ngilhodes-netizen | 2026-11-03 | 2026-11-06 | Todo |
| 24 | Point the external tables at the group bucket, not a personal one | Step 4 · Warehouse | ngilhodes-netizen | 2026-10-28 | 2026-10-31 | Todo |
| 19 | docs/governance.md: classification policy and access matrix | Step 10 · Security and governance | fefelbrn | 2026-11-03 | 2026-11-06 | Todo |
| 20 | Update the architecture diagram to what we built | Defence | ? | 2026-11-06 | 2026-11-07 | Todo |
| 21 | Slides, 10 minutes | Defence | ? | 2026-11-05 | 2026-11-08 | Todo |
| 22 | Rehearsal: each member defends one technical choice | Defence | ? | 2026-11-09 | 2026-11-09 | Todo |
