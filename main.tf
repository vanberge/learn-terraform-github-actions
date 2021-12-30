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
    organization = "${TF_ORG}"

    workspaces {
      name = "${TF_WORKSPACE}"
    }
  }
}

provider "google" {
  project = "${GCP_PROJECT}"
  region  = "us-central1"
  zone    = "us-central1-a"
}

resource "random_pet" "vm" {}

resource "google_compute_instance" "vm_instance" {
  name         = "${GCP_VM_BASENAME}-${random_pet.vm.id}"
  machine_type = "f1-micro"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }

  network_interface {
    # A default network is created for all GCP projects
    network = google_compute_network.vpc_network.self_link
    access_config {
    }
  }
}

resource "google_compute_network" "vpc_network" {
  name                    = "${GCP_VPC}"
  auto_create_subnetworks = "true"
}