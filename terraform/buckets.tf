resource "google_storage_bucket" "created_buckets" {
  for_each                    = toset(["bronze", "silver"])
  name                        = "${var.project_id}-${each.value}-${var.environment}"
  location                    = var.region
  public_access_prevention    = "enforced"
  force_destroy               = false
  uniform_bucket_level_access = true
  labels = {
    environment = var.environment
    ownership   = "data-engineering"
    layer       = each.value
  }
}

resource "google_storage_bucket" "gcf_source_bucket" {
  name                        = "${var.project_id}-gcf-source-${var.environment}"
  location                    = var.region
  public_access_prevention    = "enforced"
  force_destroy               = false
  uniform_bucket_level_access = true
  versioning {
    enabled = true
  }
  labels = {
    environment = var.environment
    ownership   = "data-engineering"
  }
}
