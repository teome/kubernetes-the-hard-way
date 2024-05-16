variable "project" {
  default = "k8s-from-scratch-0-422016"
}

variable "compute_service_account_email" {
  default = "788297811658-compute@developer.gserviceaccount.com"
}
variable "region" {
  default = "us-central1"
}

variable "zone" {
  default = "us-central1-f"
}

variable "n_nodes" {
  default = 2
}

variable "bootdisk" {
  default = "debian-cloud/debian-11-arm64"
}