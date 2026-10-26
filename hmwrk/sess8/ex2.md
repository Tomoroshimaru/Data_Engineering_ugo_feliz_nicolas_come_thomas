# Session 8 — Exercise 2: review this pull request

LUBERNE Féliz — written as a group. The pull request adds `analytics.tf` and changes the CI workflow to `terraform apply -auto-approve`.

## 1. The review

In the order we would raise them.

| What | Why it matters | How bad |
|---|---|---|
| `google_service_account_key` creates a downloadable key | The private key is written into the Terraform state, in clear, in `albert-tfstate-g01`: anyone who can read the state can act as the service account for as long as the key lives, and keys do not expire. It cannot be taken back, only rotated after the fact. | blocker |
| `output "analytics_key"` exposes that key | Terraform refuses an output built from a sensitive value unless it is marked `sensitive = true`. We checked: `validate` passes, `plan` stops with "Output refers to sensitive values". The tempting fix, adding `sensitive = true`, still leaves the key in the state, and `terraform output -raw` prints it. | blocker |
| `roles/editor` on the service account, granted at project level | Editor can read, change and delete almost everything in the project, including the bronze bucket and the silver dataset. Combined with the key above, whoever holds the key holds the project. The job needs to write to one bucket and maybe read one dataset. | blocker |
| `terraform apply -auto-approve` in CI | Every run applies whatever the plan says, with nobody reading it. The first `-/+` on the exports bucket, combined with `force_destroy = true`, deletes its contents without a human ever seeing the line. Applies should run from a plan that was reviewed on the pull request. | blocker |
| `force_destroy = true` on the exports bucket | This is the flag that turns `terraform destroy`, or any change that forces a replacement, into silent deletion of every object. `main.tf` sets it to `false` on bronze, so the new file also contradicts the one next to it. | blocker |
| A second `provider "google"` block, without alias | All `.tf` files form one configuration, and `providers.tf` already declares the default Google provider. We rebuilt the directory and ran Terraform 1.17.0: `terraform validate` itself fails with "Duplicate provider configuration", so the claim that validate passes was not true against our repository, and nothing plans until one block is removed. | blocker |
| Project id `albert-de-g01` written in two places | `providers.tf` and every other file take `var.project_id`. This file cannot be used by another group, and in group g01's own repository it silently disagrees with the variable the day the variable changes: the IAM grant would land in a different project from the resources. | should fix |
| Bucket name `exports` | Bucket names are global across all of Google Cloud; `exports` is certainly taken, so the apply fails. `main.tf` names buckets `albert-bronze-${var.group}`; this one should follow the same pattern. Fixing the name later forces a replacement, which brings `force_destroy` into play. | should fix |
| `location = "EU"` | Every other resource is in `europe-west1`, the course's region and the one BigQuery reads from. `EU` is a multi-region: more expensive per GiB, and a location mismatch waiting for the first load into the europe-west1 dataset. | should fix |
| No `uniform_bucket_level_access` on the exports bucket | Bronze has it; without it, per-object ACLs are possible, so access to the exports can no longer be read from the bucket's IAM alone. | should fix |
| The service account gets no access to what it actually needs | Instead of editor at project level, it needs `roles/storage.objectCreator` on the exports bucket and `roles/bigquery.dataViewer` on the silver dataset, both granted on the resource, not the project. | should fix |
| `account_id = "analytics-job"`, no description, no labels | Fine in one project, but nothing says whose job this is or why it exists; a label with the group and a description would. | nitpick |

Outside this pull request, but visible while comparing: bronze has a lifecycle rule that **deletes** objects after 90 days, which breaks the promise that bronze keeps everything. That deserves its own issue.

## 2. The one we would block for

The service account key, together with `roles/editor`. Most of the other problems either stop the apply (duplicate provider, taken bucket name) or need a further event to do harm (`force_destroy` needs a destroy or a replacement). The key does its damage the moment it is created: it lands in the state and can be copied from there or from any log that prints it, and from then on whoever has it can edit or delete anything in the project, from anywhere, with no expiry. A deleted bucket is one bad day; a leaked editor key is a breach we might not discover for months, and it cannot be undone by reverting the PR.

## 3. What we would say to the author

> Thanks for picking this up — the structure is right and we can get it merged quickly. The one thing that has to change before anything else is the key: `google_service_account_key` puts a permanent credential in our state, and with `roles/editor` it can do anything in the project. Our project already denies key creation for that reason; the job should run *as* the service account through impersonation, with `roles/storage.objectCreator` on the exports bucket and `roles/bigquery.dataViewer` on silver instead of editor. Smaller things, in any order: drop the second `provider` block and use `var.project_id`, name the bucket `albert-exports-${var.group}` in `europe-west1` with `force_destroy = false` and uniform access like bronze, and keep CI on `plan` so we read the diff before applying.

## 4. The one that is not the assistant's fault

The service account key. Our lab project deliberately does not grant `roles/iam.serviceAccountKeyAdmin`: the course's own `variables.tf` explains that downloadable keys are the credential students would end up committing to a public repository. So `google_service_account_key` would fail to apply in our project whatever a reviewer said. Instead, the lab grants `roles/iam.serviceAccountTokenCreator`, so we impersonate the service account and get short-lived tokens, with nothing to store and nothing to leak.

The same is true, for the same kind of reason, of the `roles/editor` grant: the lab gives no student `roles/resourcemanager.projectIamAdmin`, because it would let them grant themselves owner, so project-level IAM bindings like this one cannot be applied by us either.
