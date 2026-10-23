# What we built by hand in lessons 2 and 4, written down.
# Every value below was read from the real resource first (gcloud / bq show).

# Lesson 2: the bronze bucket.
resource "google_storage_bucket" "bronze" {
  name                        = "${var.project_id}-${var.owner}"
  location                    = "EUROPE-WEST1"
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "inherited"

  # Who pays for this, read from the billing export (lesson 9).
  labels = {
    team        = var.owner
    environment = "dev"
    pipeline    = "bronze"
    lesson      = "l02"
  }

  soft_delete_policy {
    retention_duration_seconds = 604800 # 7 days, Google's default
  }

  # Bronze keeps everything; it only moves to cheaper classes as it ages.
  lifecycle_rule {
    condition {
      age            = 30
      matches_prefix = ["bronze/"]
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  lifecycle_rule {
    condition {
      age            = 90
      matches_prefix = ["bronze/"]
    }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }

  lifecycle_rule {
    condition {
      age            = 365
      matches_prefix = ["bronze/"]
    }
    action {
      type          = "SetStorageClass"
      storage_class = "ARCHIVE"
    }
  }
}

# Lesson 4: the warehouse dataset.
resource "google_bigquery_dataset" "warehouse" {
  dataset_id = "l04_fl"
  location   = var.region

  labels = {
    team        = var.owner
    environment = "dev"
    pipeline    = "warehouse"
    lesson      = "l04"
  }
}
