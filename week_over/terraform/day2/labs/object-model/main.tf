terraform {
  required_version = ">= 1.5.0, < 2.0.0"
}

variable "network_cidr" {
  description = "CIDR recorded by the practice network object."
  type        = string
  default     = "10.20.0.0/16"
}

variable "application_name" {
  description = "Name recorded by the practice application object."
  type        = string
  default     = "catalog-api"
}

locals {
  owner = "terraform-day2"
}

resource "terraform_data" "network" {
  input = {
    cidr  = var.network_cidr
    owner = local.owner
  }
}

resource "terraform_data" "application" {
  input = {
    name       = var.application_name
    network_id = terraform_data.network.id
    owner      = local.owner
  }
}
