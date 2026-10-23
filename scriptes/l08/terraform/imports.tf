# Adopt what already exists instead of creating it again.
# The id has a different shape for each service.

import {
  to = google_storage_bucket.bronze
  id = "data-engineering-i2-feliz"
}

import {
  to = google_bigquery_dataset.warehouse
  id = "projects/data-engineering-i2/datasets/l04_fl"
}
