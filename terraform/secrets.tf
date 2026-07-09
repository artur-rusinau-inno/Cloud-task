resource "google_secret_manager_secret" "weather_api_key" {
  secret_id = "weather-api-key"

  replication {
    auto {}
  }

  labels = {
    environment = var.environment
    owner       = "data-engineering"
  }
}

resource "google_secret_manager_secret_version" "weather_api_key_value" {
  secret      = google_secret_manager_secret.weather_api_key.id
  secret_data = var.tomorrow_api_key
}
