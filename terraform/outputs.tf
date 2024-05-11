output "vpc_network_id" {
  value = google_compute_network.vpc_network.id
}

output "kubernetes_subnet_id" {
  value = google_compute_subnetwork.kubernetes.id
}