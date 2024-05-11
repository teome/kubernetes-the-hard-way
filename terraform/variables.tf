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