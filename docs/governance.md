# Governance

How the platform's data is classified, and who may read what. First version, 26 October 2026; the project step turns it into the full policy and access matrix.

## Classification

Taxonomy `marketplace-pii-fl` (europe-west1), with fine-grained access control activated. Tags are named for what the data is, never for who may see it.

| Tag | What belongs in it | Tagged today |
|---|---|---|
| `pii-contact` | Data that lets someone reach a person directly: street address, phone, email. | `l04_fl.shipping_details.street_address`, `.phone` |
| `pii-quasi-identifier` | Data that is harmless alone but identifies a person in combination, with each other or with an order date: zip, city. | `l04_fl.shipping_details.zip`, `.city` |

## Who may read each tag, and who decides

- `pii-contact`: only the jobs that ship parcels or contact customers, through `roles/datacatalog.categoryFineGrainedReader` bound on the tag itself, never on the project. Analytics does not need it: no metric is computed from an address.
- `pii-quasi-identifier`: analysts who need geography, on request, for a stated use; dashboards use `country` and `state`, which are not tagged.
- Who decides: the data owner of the subject (the business contact for customers), on a request reviewed in a pull request. The platform team applies the grant; it does not decide it.

## Not classified yet, and why

- `buyer_id` / `c_id`: the key that links a person to every order, review and address. Tagging it would break every dbt model that joins on it, so it needs pseudonymisation at ingestion rather than a tag.
- Review texts (`review.r_desc`), payment data (`customer_payment`, bronze only) and the clickstream: personal, not yet assessed.
- Bronze files in Cloud Storage: policy tags exist only on BigQuery columns, so bronze is protected by bucket IAM alone.

## Known gap

Every account in the project holds `datacatalog.categories.fineGrainedGet` at project level, so today the tags above are configured but not enforced for anyone. Verified by reading the tagged columns: no refusal.
