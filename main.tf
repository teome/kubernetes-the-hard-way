variable "project" {
  default = "k8s-from-scratch-0-422016"
}

variable "region" {
  default = "us-central1"
}

variable "zone" {
  default = "us-central1-c"
}


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

resource "google_compute_network" "vpc_network" {
  name = "terraform-network"
  # auto_create_subnetworks = false
}

resource "google_compute_firewall" "ssh" {
  name = "allow-ssh"
  allow {
    ports    = ["22"]
    protocol = "tcp"
  }
  direction     = "INGRESS"
  network       = google_compute_network.vpc_network.id
  priority      = 1000
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ssh"]
}

resource "google_compute_instance" "vm_instance" {
  name         = "terraform-instance"
  machine_type = "e2-standard-4"
  zone         = var.zone
  tags         = ["web", "dev", "ssh"]

  boot_disk {
    auto_delete = true
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 40
    }
  }

  network_interface {
    network = google_compute_network.vpc_network.name
    access_config {
    }
  }

  metadata = {
    enable-oslogin = "true"
  }

  service_account {
    email  = "788297811658-compute@developer.gserviceaccount.com"
    scopes = ["https://www.googleapis.com/auth/devstorage.read_only", "https://www.googleapis.com/auth/logging.write", "https://www.googleapis.com/auth/monitoring.write", "https://www.googleapis.com/auth/service.management.readonly", "https://www.googleapis.com/auth/servicecontrol", "https://www.googleapis.com/auth/trace.append"]
  }

}