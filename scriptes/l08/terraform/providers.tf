# Credentials come from `gcloud auth application-default login`: no key file.
provider "google" {
  project = var.project_id
  region  = var.region
}
