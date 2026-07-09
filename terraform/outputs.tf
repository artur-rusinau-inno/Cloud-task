output "buckets_urls" {
  value = [for bucket in google_storage_bucket.created_buckets : bucket.url]
}

output "cloud_function_service_bucket_url" {
  value = local.gcf_bucket.url
}

output "cloud_function_url" {
  value = local.cloud_func.url
}

output "bigquery_dataset_url" {
  value = local.bigquery_dataset.self_link
}

output "bigquery_table_url" {
  value = local.bigquery_table.self_link
}

output "service_account_detailed_permissions" {
  value = {
    for x in concat(
      [for k, v in google_storage_bucket_iam_member.bucket_permissions : { sa = v.member, access = "BUCKET: ${v.bucket} >>>> ROLE: ${v.role}" }],
      [for k, v in google_secret_manager_secret_iam_member.secret_permissions : { sa = v.member, access = "SECRET: ${v.secret_id} >>>> ROLE: ${v.role}" }],
      [for k, v in google_bigquery_dataset_iam_member.bigquery_dataset_permissions : { sa = v.member, access = "DATASET :${v.dataset_id} >>>> ROLE: ${v.role}" }],
      [for k, v in google_project_iam_member.bigquery_job_permissions : { sa = v.member, access = "PROJECT LEVEL ROLE: ${v.role}" }],
      [for k, v in google_cloud_run_service_iam_member.run_service_permissions : { sa = v.member, access = "FUNCTION: ${v.service} >>>> ROLE: ${v.role}" }]
    ) : replace(x.sa, "serviceAccount:", "") => x.access...
  }
}

output "airflow_uid" {
  value = local.airflow_uid
}

output "airflow_system_running_on" {
  value = local.is_windows ? "windows" : "unix"
}
