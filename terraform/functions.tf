resource "local_file" "files_directory_create" {
  content  = ""
  filename = "${path.module}/files/.gitkeep"
}

data "archive_file" "function_zip" {
  type        = "zip"
  output_path = "${path.module}/files/weather_fetcher.zip"
  depends_on  = [local_file.files_directory_create]
  source {
    content  = file("${path.module}/../cloud_funcs/weather_fetcher/main.py")
    filename = "main.py"
  }
  source {
    content  = file("${path.module}/../cloud_funcs/weather_fetcher/requirements.txt")
    filename = "requirements.txt"
  }
  source {
    content  = file("${path.module}/../core_settings/core_settings.py")
    filename = "core_settings/core_settings.py"
  }
  source {
    content  = file("${path.module}/../core_settings/__init__.py")
    filename = "core_settings/__init__.py"
  }
}

resource "google_storage_bucket_object" "zip_object" {
  name   = "weather_fetcher.zip"
  bucket = google_storage_bucket.gcf_source_bucket.name
  source = data.archive_file.function_zip.output_path
}

resource "google_cloudfunctions2_function" "weather_fetcher" {
  name     = "${var.project_id}-tomorrow-io-api-fetcher"
  location = var.region
  build_config {
    runtime     = "python312"
    entry_point = "fetch_weather_to_bronze"
    source {
      storage_source {
        bucket     = local.gcf_bucket.name
        object     = google_storage_bucket_object.zip_object.name
        generation = google_storage_bucket_object.zip_object.generation
      }
    }
  }
  service_config {
    max_instance_count    = 1
    available_memory      = "256Mi"
    timeout_seconds       = 60
    service_account_email = local.sa_cloud_func.email

    ingress_settings = "ALLOW_ALL"

    environment_variables = {
      PROJECT_ID         = var.project_id
      BRONZE_BUCKET_NAME = local.bronze_bucket.name
      SILVER_BUCKET_NAME = local.silver_bucket.name
      BIGQUERY_DATASET   = local.bigquery_dataset.dataset_id
      BIGQUERY_TABLE     = local.bigquery_table.table_id
    }
    secret_environment_variables {
      key        = "TOMORROW_API_KEY"
      project_id = var.project_id
      secret     = google_secret_manager_secret.weather_api_key.secret_id
      version    = "1"
    }
  }
}

resource "google_cloud_scheduler_job" "weather_fetcher_trigger" {
  name             = "weather_fetcher_trigger-${var.environment}"
  schedule         = "*/10 * * * *"
  time_zone        = "Etc/UTC"
  attempt_deadline = "180s"

  http_target {
    http_method = "GET"

    uri = local.cloud_func.service_config[0].uri

    oidc_token {
      service_account_email = local.sa_cloud_func.email
      audience              = local.cloud_func.service_config[0].uri
    }
  }
}
