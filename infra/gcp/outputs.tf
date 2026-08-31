output "kms_key_resource" {
  value = try(module.atelier_data[0].kms_key_resource, null)
}

output "provider_cache_bucket" {
  value = try(module.atelier_data[0].provider_cache_bucket, null)
}

output "durable_bucket" {
  value = try(module.atelier_data[0].durable_bucket, null)
}

output "gmail_pubsub_topic" {
  value = try(module.atelier_data[0].gmail_pubsub_topic, null)
}

output "gmail_pull_subscription" {
  value = try(module.atelier_data[0].gmail_pull_subscription, null)
}

output "runtime_service_account" {
  value = try(module.atelier_data[0].runtime_service_account, null)
}

output "workload_identity_provider" {
  value = try(module.atelier_data[0].workload_identity_provider, null)
}
