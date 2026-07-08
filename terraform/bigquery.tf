resource "google_bigquery_dataset" "weather_gold_dataset" {
  dataset_id                 = "weather_gold"
  project                    = var.project_id
  location                   = var.region
  delete_contents_on_destroy = false
}

resource "google_bigquery_table" "weather_gold_table" {
  dataset_id          = google_bigquery_dataset.weather_gold_dataset.dataset_id
  table_id            = "realtime_weather"
  project             = var.project_id
  deletion_protection = true
  depends_on          = [google_bigquery_dataset.weather_gold_dataset]

  schema = file("${path.module}/../core_settings/bigquery_schema.json")
}

