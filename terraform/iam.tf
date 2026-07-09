locals {
  service_account_names = toset(["airflow", "cloud-func"])
  sa_airflow            = google_service_account.service_accounts["airflow"]
  sa_cloud_func         = google_service_account.service_accounts["cloud-func"]
  bucket_permissions = {
    bronze_editor = {
      sa     = local.sa_cloud_func.email
      bucket = local.bronze_bucket.name
      role   = "roles/storage.objectCreator"
    }

    bronze_reader = {
      sa     = local.sa_airflow.email
      bucket = local.bronze_bucket.name
      role   = "roles/storage.objectViewer"
    }

    silver_admin = {
      sa     = local.sa_airflow.email
      bucket = local.silver_bucket.name
      role   = "roles/storage.objectAdmin"
    }
  }

  secret_permissions = {
    secret_reader = {
      sa        = local.sa_cloud_func.email
      secret_id = google_secret_manager_secret.weather_api_key.secret_id
      role      = "roles/secretmanager.secretAccessor"
    }
  }

  bigquery_dataset_permissions = {
    bq_editor = {
      sa         = local.sa_airflow.email
      dataset_id = google_bigquery_dataset.weather_gold_dataset.dataset_id
      role       = "roles/bigquery.dataEditor"
    }
  }

  bigquery_job_permissions = {
    bq_job_user = {
      sa   = local.sa_airflow.email
      role = "roles/bigquery.jobUser"
    }
  }

  run_service_permissions = {
    scheduler_invoke = {
      sa   = local.sa_cloud_func.email
      func = local.cloud_func.name
      role = "roles/run.invoker"
    }
  }
}


#####################################
resource "google_service_account_key" "airflow_sa_key" {
  service_account_id = local.sa_airflow.id
}

resource "local_sensitive_file" "gcp_key" {
  content  = base64decode(google_service_account_key.airflow_sa_key.private_key)
  filename = "${path.module}/keys/gcp-airflow-key.json"
}

###########################################################################################################


resource "google_service_account" "service_accounts" {
  for_each   = local.service_account_names
  account_id = "${each.value}-sa-${var.environment}"
}

resource "google_storage_bucket_iam_member" "bucket_permissions" {
  for_each = local.bucket_permissions
  member   = "serviceAccount:${each.value.sa}"
  role     = each.value.role
  bucket   = each.value.bucket
}

resource "google_secret_manager_secret_iam_member" "secret_permissions" {
  for_each  = local.secret_permissions
  member    = "serviceAccount:${each.value.sa}"
  role      = each.value.role
  secret_id = each.value.secret_id
}

resource "google_bigquery_dataset_iam_member" "bigquery_dataset_permissions" {
  for_each   = local.bigquery_dataset_permissions
  member     = "serviceAccount:${each.value.sa}"
  role       = each.value.role
  dataset_id = each.value.dataset_id
}

resource "google_project_iam_member" "bigquery_job_permissions" {
  for_each = local.bigquery_job_permissions
  project  = var.project_id
  member   = "serviceAccount:${each.value.sa}"
  role     = each.value.role
}

resource "google_cloud_run_service_iam_member" "run_service_permissions" {
  for_each = local.run_service_permissions
  member   = "serviceAccount:${each.value.sa}"
  role     = each.value.role
  service  = each.value.func
}
