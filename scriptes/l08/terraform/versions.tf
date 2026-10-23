terraform {
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.3"
    }
  }

  # State lives in a versioned bucket made by hand: it cannot create itself.
  backend "gcs" {
    bucket = "data-engineering-i2-feliz-tfstate"
    prefix = "l08"
  }
}
