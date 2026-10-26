# Session 10 — Exercise 2: a governance review of our own company

LUBERNE Féliz — written as a group, from the analytics team at Cartier, where one of us is an apprentice analytics engineer. No table names, no figures, no identifiers, nothing about a specific weakness. Where we do not know, we say so.

## 1. Three columns that would be classified

**A client's contact details** (email, phone, postal address): contact data. They let anyone who reads them reach a client directly, and our clients are people whose purchases make them worth targeting. The decision should belong to the business owner of client data, with the data protection officer's advice.

**A client's purchase history and lifetime value**: financial and behavioural. Combined with a name, it says how wealthy someone is and what they keep at home, which matters more for a jeweller than for most retailers. The decision should belong to the same owner, but in practice the people who use it most are in sales and marketing analytics, and we could not tell who would arbitrate between the two.

**Free-text notes written by sales associates about a client** (preferences, occasions, family events): behavioural, and open to anything, including health or family details nobody meant to store. Nobody we know of would decide who reads it; the field belongs to the client relationship tool, not to anyone in data. That is our main finding for this section: for the most sensitive field of the three, we cannot name the role that decides.

## 2. Who can read them today

We do not fully know, and that is the first finding. What we can see from our position:

- In BigQuery, access is granted per dataset, to groups. Our team can read the client data we model. We have never seen anything granted per column, and we have never seen a policy tag on our projects.
- In the BI tools, access is per report or per workspace. Tableau extracts and Power BI datasets hold their own copy of the data, with their own permissions, separate from BigQuery's.
- On the Azure side, which still runs during the migration, we do not know who can read the same data. We have not been able to establish it, and the people who built it are not all still on the project.

So the honest answer is: whoever is in the right group for the dataset, plus whoever can open a report built on it, plus an unknown number of people on the legacy side. Nothing is granted per column.

## 3. Could an erasure request be honoured?

Tracing one client as far as we can:

- **The systems of record**: the client relationship tool, boutique point of sale (in many countries), e-commerce, after-sales. Each is owned by a different team, and none is ours.
- **Our raw layer in BigQuery**: we never modify raw tables, every fix produces a child table. That rule is what makes our models trustworthy, and it is exactly what an erasure has to break.
- **Derived copies that rebuild themselves**: the dbt models. Once raw is corrected and the models rebuild, they follow. This is the easy part.
- **Copies that do not rebuild**: BI extracts that refresh on their own schedule, CSV files sent to us by business teams and kept in inboxes and shared drives, BigQuery time travel, backups, and the Azure environment, which still holds the same data and is waiting to be decommissioned. During a migration, that is the system nobody really owns.
- **A legal limit**: invoices must be kept for years for accounting, so for purchases the realistic outcome is anonymisation (the sale stays, the person goes), not deletion.

Realistically: weeks, and at least four teams (client relationship, data platform and analytics, BI, legal), plus the local markets that hold their own copies. The part we could do quickly, our own models, is the smallest part.

## 4. One thing we would change first

Classify the client contact columns with BigQuery policy tags **while the analytics MVP is being built on GCP**, and give the reader role, bound on the tag, only to the few jobs that need to contact clients. The BI service accounts and the analytics group would not hold it. No dashboard needs a phone number.

The rough cost is three to four days. Listing the contact columns across the migrated datasets takes one day. Writing the taxonomy, the tags and the bindings in Terraform, which we already use, takes one day. Then a test with an account that should be refused, because a tag that blocks nobody is only configuration: we saw that in exercise 1. The rest goes to finding what reads those columns, using the job history and audit logs for two weeks before enforcing.

The objection will be that it slows the MVP, whose whole point is to prove that GCP works, and that it may break a report nobody has listed. Our answer is that the MVP is the cheapest moment to do it: today a handful of models read these columns; after the Azure decommissioning, every rebuilt report will depend on them. The two weeks of logs also tell us exactly which report would break, before anything does. That discovery is useful even if the tags never go live.
