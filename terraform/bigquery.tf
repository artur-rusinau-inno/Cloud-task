resource "google_bigquery_dataset" "weather_gold_dataset" {
  dataset_id                 = "weather_gold"
  delete_contents_on_destroy = false
}

resource "google_bigquery_table" "weather_gold_table" {
  dataset_id          = local.bigquery_dataset.dataset_id
  table_id            = "realtime_weather"
  deletion_protection = true

  schema = file("${path.module}/../core_settings/bigquery_schema.json")
}

