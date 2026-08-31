output "kms_key_resource" {
  value = google_kms_crypto_key.provider_envelope.id
}

output "provider_cache_bucket" {
  value = google_storage_bucket.provider_cache.name
}

output "durable_bucket" {
  value = google_storage_bucket.durable.name
}

output "gmail_pubsub_topic" {
  value = google_pubsub_topic.gmail.id
}

output "gmail_pull_subscription" {
  value = google_pubsub_subscription.gmail_sync.id
}

output "runtime_service_account" {
  value = google_service_account.runtime.email
}

output "workload_identity_provider" {
  value = try(google_iam_workload_identity_pool_provider.runtime[0].name, null)
}
