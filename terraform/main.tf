terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.51.0"
    }
  }
}

provider "google" {
  # credentials = file("<path_to_service_account_key_file>")
  project = var.project
  region  = var.region
}
