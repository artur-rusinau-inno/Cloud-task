variable "environment" {
  type    = string
  default = "dev"
  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "Environment must be either dev, stage or prod"
  }
}

variable "region" {
  type    = string
  default = "europe-central2"
  validation {
    condition     = (startswith(var.region, "europe-") && length(var.region) > 7 && length(var.region) < 20) || contains(["EU", "EUR4", "EUR5", "EUR7", "EUR8"], var.region)
    error_message = "Due to GDPR region must be Europe only (e.g. europe-central2, EU, EUR7)"
  }
}

variable "project_id" {
  type = string
  validation {
    condition     = length(var.project_id) >= 6 && length(var.project_id) <= 30
    error_message = "Project ID must be from 6 to 30 symbols"
  }
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]+[a-z0-9]$", var.project_id))
    error_message = "Project ID must start from letter, end with letter/number, can contain letters, numbers and hyphens. Must be in lower case"
  }
}

variable "tomorrow_api_key" {
  type      = string
  sensitive = true
  validation {
    condition     = length(var.tomorrow_api_key) == 32
    error_message = "Weather API key must be exact 32 symbols long"
  }
  validation {
    condition     = can(regex("^[a-zA-Z0-9]+$", var.tomorrow_api_key))
    error_message = "Weather API key can contain only letters and numbers"
  }
}

variable "pip_additional_requirements" {
  type    = string
  default = "apache-airflow-providers-google"
}
