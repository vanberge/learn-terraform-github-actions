terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "3.5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.0.1"
    }
  }
  required_version = ">= 1.1.0"

  cloud {
    organization = "evb-sandbox"

    workspaces {
      name = "evb-gcp-sandbox"
    }
  }
}
variable "GCP_PROJECT" {
  description = "GCP Project to utilize"
  type        = string
}

variable "GCP_VM_BASENAME" {
  description = "GCP Base VM name"
  type        = string
}

variable "GCP_VPC" {
  description = "GCP VPC network"
  type        = string
}

provider "google" {
  project = var.GCP_PROJECT
  region  = "us-central1"
  zone    = "us-central1-a"
}

resource "random_pet" "vm" {}

resource "google_compute_instance" "vm_instance" {
  name         = "${random_pet.vm.id}-vm"
  machine_type = "f1-micro"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }

  network_interface {
    # A default network is created for all GCP projects
    network = google_compute_subnetwork.vpc_subnetwork.self_link
    access_config {
    }
  }
}

resource "google_compute_subnetwork" "vpc_subnetwork" {
  name          = "${var.GCP_VPC}-ss"
  ip_cidr_range = "10.0.0.0/24"
  region        = "us-central1"
  network       = var.GCP_VPC
}

resource "google_compute_subnetwork" "vpc_subnetwork_k8s" {
  name          = "${var.GCP_VPC}-k8s"
  ip_cidr_range = "10.1.0.0/24"
  region        = "us-central1"
  network       = var.GCP_VPC
  secondary_ip_range {
    range_name    = "${var.GCP_VPC}-k8s-services"
    ip_cidr_range = "10.2.0.0/24"
  }
  secondary_ip_range {
    range_name    = "${var.GCP_VPC}-k8s-pods"
    ip_cidr_range = "10.99.0.0/23"
  }
}