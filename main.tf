variable "project" {
  default = "k8s-from-scratch-0-422016"
}

variable "region" {
  default = "us-central1"
}

variable "zone" {
  default = "us-central1-f"
}

variable "n_workers" {
  default = 2
}

variable "bootdisk" {
  default = "debian-cloud/debian-12-arm64"
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
  name                    = "terraform-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "kubernetes" {
  name          = "kubernetes"
  ip_cidr_range = "10.240.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc_network.id
}

resource "google_compute_address" "vpc_network" {
  name   = "kubernetes-the-hard-way"
  region = var.region
}

resource "google_compute_firewall" "external" {
  name = "allow-external"
  allow {
    ports    = ["22"]
    protocol = "tcp"
  }
  allow {
    ports    = ["6443"]
    protocol = "tcp"
  }
  allow {
    protocol = "icmp"
  }
  direction     = "INGRESS"
  network       = google_compute_network.vpc_network.id
  priority      = 1000
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ssh"]
}

resource "google_compute_firewall" "internal" {
  name = "allow-internal"
  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }
  direction     = "INGRESS"
  network       = google_compute_network.vpc_network.id
  priority      = 1000
  source_ranges = ["10.240.0.0/24", "10.200.0.0/16"]
}

################################################
# Compute
resource "google_compute_instance" "jumpbox" {
  name         = "jumpbox"
  machine_type = "t2a-standard-1"
  zone         = var.zone
  tags         = ["kubernetes-the-hard-way", "controller", "ssh"]

  boot_disk {
    auto_delete = true
    initialize_params {
      image = var.bootdisk
      size  = 10
    }
  }

  can_ip_forward = true
  network_interface {
    subnetwork = google_compute_subnetwork.kubernetes.id
    access_config {
    }
    network_ip = "10.240.0.10"
  }

  metadata = {
    enable-oslogin = "true"
  }

  service_account {
    email  = "788297811658-compute@developer.gserviceaccount.com"
    scopes = ["https://www.googleapis.com/auth/devstorage.read_only", "https://www.googleapis.com/auth/logging.write", "https://www.googleapis.com/auth/monitoring.write", "https://www.googleapis.com/auth/service.management.readonly", "https://www.googleapis.com/auth/servicecontrol", "https://www.googleapis.com/auth/trace.append"]
  }
}

resource "google_compute_instance" "server" {
  name         = "server"
  machine_type = "t2a-standard-1"
  zone         = var.zone
  tags         = ["kubernetes-the-hard-way", "server", "ssh"]

  boot_disk {
    auto_delete = true
    initialize_params {
      image = var.bootdisk
      size  = 20
    }
  }

  can_ip_forward = true
  network_interface {
    subnetwork = google_compute_subnetwork.kubernetes.id
    access_config {
    }
    network_ip = "10.240.0.11"
  }

  metadata = {
    enable-oslogin = "true"
  }

  service_account {
    email  = "788297811658-compute@developer.gserviceaccount.com"
    scopes = ["https://www.googleapis.com/auth/devstorage.read_only", "https://www.googleapis.com/auth/logging.write", "https://www.googleapis.com/auth/monitoring.write", "https://www.googleapis.com/auth/service.management.readonly", "https://www.googleapis.com/auth/servicecontrol", "https://www.googleapis.com/auth/trace.append"]
  }
}

resource "google_compute_instance" "workers" {
  count = var.n_workers

  name         = "worker-${count.index}"
  machine_type = "t2a-standard-1"
  zone         = var.zone
  tags         = ["kubernetes-the-hard-way", "worker", "ssh"]

  boot_disk {
    auto_delete = true
    initialize_params {
      image = var.bootdisk
      size  = 20
    }
  }

  can_ip_forward = true
  network_interface {
    subnetwork = google_compute_subnetwork.kubernetes.id
    access_config {
    }
    network_ip = "10.240.0.2${count.index}"
  }

  metadata = {
    enable-oslogin = "true"
    pod-cidr       = "10.200.${count.index}.0/24"
  }

  service_account {
    email  = "788297811658-compute@developer.gserviceaccount.com"
    scopes = ["https://www.googleapis.com/auth/devstorage.read_only", "https://www.googleapis.com/auth/logging.write", "https://www.googleapis.com/auth/monitoring.write", "https://www.googleapis.com/auth/service.management.readonly", "https://www.googleapis.com/auth/servicecontrol", "https://www.googleapis.com/auth/trace.append"]
  }
}