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