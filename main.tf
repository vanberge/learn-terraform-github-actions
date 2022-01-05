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

resource "google_compute_network" "vpc" {
  name                    = "${var.GCP_VPC}-shared"
  project                 = var.GCP_PROJECT
  auto_create_subnetworks = "false"
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "vpc_subnetwork_private" {
  name = "${var.GCP_VPC}-shared-sn"

  project       = var.GCP_PROJECT
  region        = "us-central1"
  network       = google_compute_network.vpc.self_link
  ip_cidr_range = "10.0.0.0/24"
}

resource "google_compute_network" "k8s_vpc" {
  name                    = "${var.GCP_VPC}-k8s"
  project                 = var.GCP_PROJECT
  auto_create_subnetworks = "false"
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "k8s_vpc_subnetwork_private" {
  name          = "${var.GCP_VPC}-k8s"
  project       = var.GCP_PROJECT
  region        = "us-central1"
  network       = google_compute_network.k8s_vpc.self_link
  ip_cidr_range = "10.0.0.0/24"

  secondary_ip_range = [
    {
      range_name    = "${var.GCP_VPC}-k8s-services"
      ip_cidr_range = "10.0.1.0/24"
    },
    {
      range_name    = "${var.GCP_VPC}-k8s-pods"
      ip_cidr_range = "10.99.0.0/23"
    }
  ]
}

resource "random_pet" "vm" {}

resource "google_compute_instance" "vm_instance" {
  #name         = "${random_pet.vm.id}-vm" // use a var but keep this cus it's fun
  name         = "${var.GCP_VM_BASENAME}-vm"
  machine_type = "f1-micro"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }

  network_interface {
    # A default network is created for all GCP projects
    subnetwork = google_compute_subnetwork.vpc_subnetwork_private.self_link
    access_config {
    }
  }
}

resource "google_container_cluster" "primary" {
  name                     = "${var.GCP_VM_BASENAME}-gke"
  location                 = "us-central1"
  remove_default_node_pool = true
  initial_node_count       = 1
  network                  = var.GCP_VPC
  subnetwork               = "${var.GCP_VPC}-k8s"
  ip_allocation_policy {
    cluster_secondary_range_name  = "${var.GCP_VPC}-k8s-pods"
    services_secondary_range_name = "${var.GCP_VPC}-k8s-services"
  }
}

resource "google_container_node_pool" "primary_preemptible_nodes" {
  name       = "${google_container_cluster.primary.name}-nodepool"
  location   = "us-central1"
  cluster    = google_container_cluster.primary.name
  node_count = 2

  node_config {
    preemptible  = false
    machine_type = "e2-micro"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}