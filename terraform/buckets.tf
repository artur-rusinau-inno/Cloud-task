resource "google_storage_bucket" "created_buckets" {
  for_each                    = toset(["bronze", "silver"])
  name                        = "${var.project_id}-${each.value}-${var.environment}"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = false
  public_access_prevention    = "enforced"
  labels = {
    environment = var.environment
    ownership   = "data-engineering"
    layer       = each.value
  }
}
