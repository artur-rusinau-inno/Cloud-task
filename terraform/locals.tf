locals {
  is_windows       = strcontains(abspath(path.module), ":")
  airflow_uid      = local.is_windows ? "50000" : data.external.user_id[0].result.uid
  bronze_bucket    = google_storage_bucket.created_buckets["bronze"]
  silver_bucket    = google_storage_bucket.created_buckets["silver"]
  gcf_bucket       = google_storage_bucket.gcf_source_bucket
  bigquery_dataset = google_bigquery_dataset.weather_gold_dataset
  bigquery_table   = google_bigquery_table.weather_gold_table
  cloud_func       = google_cloudfunctions2_function.weather_fetcher
}

data "external" "user_id" {
  count   = local.is_windows ? 0 : 1
  program = ["bash", "${path.module}/scripts/uid.sh"]
}

