terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    hcloud = {
      source = "terraform-providers/hcloud"
    }
    local = {
      source = "hashicorp/local"
    }
  }
  required_version = ">= 0.13"
}
