output "created_buckets" {
  description = "Created buckets"
  value       = [for bucket in google_storage_bucket.created_buckets : bucket.name]
}

output "created_buckets_urls" {
  description = "Created buckets urls"
  value       = [for bucket in google_storage_bucket.created_buckets : bucket.url]
}
