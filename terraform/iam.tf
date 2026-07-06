##################################
# Сервисный аккаунт для cloud func
resource "google_service_account" "function_sa" {
  account_id = "weather-fetcher-sa-${var.environment}"
  project    = var.project_id
}

# Разрешаем cloud func писать в бронзу
resource "google_storage_bucket_iam_member" "bronze_write" {
  bucket = google_storage_bucket.created_buckets["bronze"].name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.function_sa.email}"
}

# Разрешаем cloud func читать ключ от tomorrow.io
resource "google_secret_manager_secret_iam_member" "secret_read" {
  secret_id = google_secret_manager_secret.weather_api_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.function_sa.email}"
}

# Разрешаем функции вызывать саму себя по таймеру
resource "google_cloud_run_service_iam_member" "scheduler_invoke" {
  project  = var.project_id
  location = var.region
  service  = google_cloudfunctions2_function.weather_fetcher.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.function_sa.email}"
}

##########################################
# Сервисный аккаунт для локального airflow
resource "google_service_account" "airflow_sa" {
  account_id = "airflow-runner-sa-${var.environment}"
  project    = var.project_id
}

# Разрешаем локальному airflow читать из бронзы
resource "google_storage_bucket_iam_member" "airflow_bronze_read" {
  bucket = google_storage_bucket.created_buckets["bronze"].name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.airflow_sa.email}"
}

# Разрешаем локальному airflow писать/удалять в сильвере
resource "google_storage_bucket_iam_member" "airflow_silver_admin" {
  bucket = google_storage_bucket.created_buckets["silver"].name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.airflow_sa.email}"
}

# Разрешаем локальному airflow писать в BigQuery
resource "google_project_iam_member" "airflow_bq_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.airflow_sa.email}"
}

# Разрешаем локальному airflow ранить джобы в BigQuery
resource "google_project_iam_member" "airflow_bq_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.airflow_sa.email}"
}


#####################################
# Создаём ключ для локального airflow
resource "google_service_account_key" "airflow_sa_key" {
  service_account_id = google_service_account.airflow_sa.name
}

# Сохраняем ключ в terraform/keys
resource "local_sensitive_file" "gcp_key" {
  content  = base64decode(google_service_account_key.airflow_sa_key.private_key)
  filename = "${path.module}/keys/gcp-airflow-key.json"
}
