resource "google_storage_bucket" "gcf_source_bucket" {
  name                        = "${var.project_id}-gcf-source-${var.environment}"
  location                    = var.region
  project                     = var.project_id
  force_destroy               = true
  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true
}

resource "terraform_data" "prepare_src" {
  triggers_replace = {
    main_md5   = md5(file("${path.module}/../cloud_funcs/weather_fetcher/main.py"))
    req_md5    = md5(file("${path.module}/../cloud_funcs/weather_fetcher/requirements.txt"))
    config_md5 = md5(file("${path.module}/../core_settings/core_settings.py"))
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<EOT
      rm -rf ${path.module}/.tmp_src && \
      mkdir -p ${path.module}/.tmp_src && \
      cp -r ${path.module}/../cloud_funcs/weather_fetcher/* ${path.module}/.tmp_src/ && \
      cp -r ${path.module}/../core_settings ${path.module}/.tmp_src/
    EOT
  }
}

data "archive_file" "function_zip" {
  type        = "zip"
  source_dir  = "${path.module}/.tmp_src"
  output_path = "${path.module}/files/weather_fetcher.zip"

  depends_on = [terraform_data.prepare_src]
}

resource "google_storage_bucket_object" "zip_object" {
  name   = "weather_fetcher_${data.archive_file.function_zip.output_md5}.zip"
  bucket = google_storage_bucket.gcf_source_bucket.name
  source = data.archive_file.function_zip.output_path
}

resource "google_cloudfunctions2_function" "weather_fetcher" {
  name     = "${var.project_id}-tomorrow-io-api-fetcher"
  location = var.region
  build_config {
    runtime     = "python313"
    entry_point = "fetch_weather_to_bronze"
    source {
      storage_source {
        bucket = google_storage_bucket.gcf_source_bucket.name
        object = google_storage_bucket_object.zip_object.name
      }
    }
  }
  service_config {
    max_instance_count    = 1
    available_memory      = "256Mi"
    timeout_seconds       = 60
    service_account_email = google_service_account.function_sa.email

    ingress_settings = "ALLOW_ALL"

    environment_variables = {
      ENV                = var.environment
      BRONZE_BUCKET_NAME = google_storage_bucket.created_buckets["bronze"].name
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
  project          = var.project_id
  region           = var.region

  http_target {
    http_method = "GET"

    uri = google_cloudfunctions2_function.weather_fetcher.service_config[0].uri

    oidc_token {
      service_account_email = google_service_account.function_sa.email
      audience              = google_cloudfunctions2_function.weather_fetcher.service_config[0].uri
    }
  }
}
