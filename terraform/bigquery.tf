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

  schema = <<EOF
[
  {"name": "source_object", "type": "STRING", "mode": "REQUIRED"},
  {"name": "event_time", "type": "TIMESTAMP", "mode": "REQUIRED"},
  {"name": "location_name", "type": "STRING", "mode": "REQUIRED"},
  {"name": "location_lat", "type": "FLOAT64", "mode": "NULLABLE"},
  {"name": "location_lon", "type": "FLOAT64", "mode": "NULLABLE"},
  {"name": "location_type", "type": "STRING", "mode": "NULLABLE"},
  {"name": "ingested_at_utc", "type": "TIMESTAMP", "mode": "REQUIRED"},
  {"name": "weather_temperature", "type": "FLOAT64", "mode": "NULLABLE"},
  {"name": "weather_humidity", "type": "FLOAT64", "mode": "NULLABLE"},
  {"name": "weather_windSpeed", "type": "FLOAT64", "mode": "NULLABLE"},
  {"name": "weather_cloudCover", "type": "FLOAT64", "mode": "NULLABLE"},
  {"name": "weather_precipitationProbability", "type": "FLOAT64", "mode": "NULLABLE"}
]
EOF
}

