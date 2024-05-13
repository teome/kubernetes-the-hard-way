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
    email  = var.compute_service_account_email
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
    email  = var.compute_service_account_email
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
    email  = var.compute_service_account_email
    scopes = ["https://www.googleapis.com/auth/devstorage.read_only", "https://www.googleapis.com/auth/logging.write", "https://www.googleapis.com/auth/monitoring.write", "https://www.googleapis.com/auth/service.management.readonly", "https://www.googleapis.com/auth/servicecontrol", "https://www.googleapis.com/auth/trace.append"]
  }
}