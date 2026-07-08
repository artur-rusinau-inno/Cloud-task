output "created_buckets_urls" {
  value = [for bucket in google_storage_bucket.created_buckets : bucket.url]
}

output "cloud_function_url" {
  value = google_cloudfunctions2_function.weather_fetcher.url
}

