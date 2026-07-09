terraform {
  required_version = "~> 1.15"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.39"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.9"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.9"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~>2.8"
    }
    external = {
      source  = "hashicorp/external"
      version = "~>2.4"
    }
  }
  backend "gcs" {
    bucket = "cloud-task-weather-tfstate-dev"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}




