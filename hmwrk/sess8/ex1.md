# Session 8 — Exercise 1: declare what you already built

LUBERNE Féliz — written as a group. Terraform 1.17.0, configuration in `scriptes/l08/terraform/`. We pointed it at the real resources we made by hand: the lesson 2 bucket `gs://data-engineering-i2-feliz` (10,664 objects) and the lesson 4 dataset `l04_fl`, never applying a plan that destroyed or replaced anything.

## The provider version

`.terraform.lock.hcl` pinned **hashicorp/google 8.8.0**, the newest release allowed by our constraint `~> 8.3`.

## Before importing

```text
Plan: 2 to add, 0 to change, 0 to destroy.
```

Terraform wanted to create both resources: its state was empty, so anything in the code it had never recorded looked new to it. Applying that plan would have failed with "already exists". The plan also showed `deletion_policy = "DELETE"` on both: with this provider version, a `terraform destroy` would really delete the bucket and the dataset.

## After importing

With one `import` block per resource (`data-engineering-i2-feliz` for the bucket, `projects/data-engineering-i2/datasets/l04_fl` for the dataset), applying and planning again gave:

```text
No changes. Your infrastructure matches the configuration.
```

Our description matched the real resources first time, including the three lifecycle rules on `bronze/` and the seven-day soft delete.

## Breaking it from the outside

We first added a label with gcloud (`--update-labels=owner=feliz`). The plan still said **No changes**: since provider 5, Terraform only manages the labels written in the code, and ours declares none. It had seen the label all the same: `terraform plan -refresh-only` reported "Objects have changed outside of Terraform" with `+ "owner" = "feliz"` in `effective_labels`. A change made outside Terraform goes unnoticed whenever it touches something the code does not describe.

We then changed something the code does describe: the Nearline rule, from 30 to 45 days, with `gcloud storage buckets update --lifecycle-file`. This time:

```text
  # google_storage_bucket.bronze will be updated in-place
  ~ resource "google_storage_bucket" "bronze" {
      ~ lifecycle_rule {
          - condition {
              - age            = 45 -> null
              - matches_prefix = ["bronze/"] -> null
            }
          + condition {
              + age            = 30
              + matches_prefix = ["bronze/"]
            }
        }
    }

Plan: 0 to add, 1 to change, 0 to destroy.
```

Terraform never uses the word "drift": it says "will be updated in-place", exactly as if we had edited the file ourselves.

It proposes to move the bucket back to 30 days, towards the configuration, because it treats the code as the truth and the real resource as a deviation to correct.

## Our decision

We overwrote, because the 45-day rule was a change made for the exercise with no business reason, while 30 days is the decision we took and argued in lesson 2. Had it been a fix made during an incident, we would have adopted it, because silently deleting somebody's fix is worse than an untidy configuration.

`terraform apply` of the saved plan gave `Apply complete! Resources: 0 added, 1 changed, 0 destroyed.`, the bucket's rule read 30 days again, and the next plan said `No changes`.

## State off the laptop

We created `gs://data-engineering-i2-feliz-tfstate` by hand (europe-west1, uniform access, public access blocked, versioning on), added a `backend "gcs"` block with prefix `l08`, and ran `terraform init -migrate-state`. The plan still said `No changes`, and the state is in the bucket:

```text
9502  2026-10-22T17:48:37Z  gs://data-engineering-i2-feliz-tfstate/l08/default.tfstate
```

`.terraform/`, `terraform.tfstate`, `terraform.tfstate.backup` and `terraform.tfvars` are ignored by git; `git status` offers only the `.tf` files and `.terraform.lock.hcl`.
