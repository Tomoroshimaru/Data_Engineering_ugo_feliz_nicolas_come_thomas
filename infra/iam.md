# Access to the bronze bucket

Bucket `gs://data-engineering-i2-toes-futcn`, project `data-engineering-i2`.
Uniform bucket-level access is on, so these bindings are the only access
control: there are no per-object ACLs. Public access prevention is enforced.

## What is applied

Read with `gcloud storage buckets get-iam-policy gs://data-engineering-i2-toes-futcn`
on 2026-10-20: four role bindings, six principal–role pairs. They are the
defaults Google Cloud adds to every new bucket; we have added none.

| Principal | Role | Scope | Why |
|---|---|---|---|
| `projectOwner:data-engineering-i2` | `roles/storage.legacyBucketOwner` | Bucket | Default. Owners of the project manage the bucket |
| `projectEditor:data-engineering-i2` | `roles/storage.legacyBucketOwner` | Bucket | Default. Editors of the project manage the bucket |
| `projectOwner:data-engineering-i2` | `roles/storage.legacyObjectOwner` | Every object | Default. Owners read, write and delete objects |
| `projectEditor:data-engineering-i2` | `roles/storage.legacyObjectOwner` | Every object | Default. Editors read, write and delete objects |
| `projectViewer:data-engineering-i2` | `roles/storage.legacyBucketReader` | Bucket | Default. Viewers list the bucket |
| `projectViewer:data-engineering-i2` | `roles/storage.legacyObjectReader` | Every object | Default. Viewers read every object |

## What is wrong with it

`data-engineering-i2` is shared by the whole class, so **every student who is an
editor of the project can read, overwrite and delete our bronze**, not only
the five of us. We cannot list who those editors are: reading the project's IAM
policy needs a permission none of us has. Bronze's promise ("nothing that
arrived is lost") currently depends on nobody else making a mistake.

## What we want instead (not applied yet)

| Principal | Role | Scope | Why |
|---|---|---|---|
| The five group members, by account | `roles/storage.objectAdmin` | This bucket | We land and replay loads |
| The lesson 3 ingestion service account | `roles/storage.objectCreator` | This bucket | Writes new loads, cannot delete or overwrite |
| The lesson 5 dbt service account | `roles/storage.objectViewer` | This bucket | Reads bronze, cannot change it |

Removing the project-wide bindings and adding these needs the members' account
emails and a project administrator to create the service accounts (our
accounts cannot: `iam.serviceAccounts.create` is denied). Lesson 8 writes this
table as Terraform.
