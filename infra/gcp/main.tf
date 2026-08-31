module "atelier_data" {
  count  = var.enable_resources ? 1 : 0
  source = "./modules/atelier-data"

  project_id                          = var.project_id
  environment                         = var.environment
  kms_location                        = var.kms_location
  provider_cache_bucket_name          = var.provider_cache_bucket_name
  durable_bucket_name                 = var.durable_bucket_name
  workload_identity_issuer_uri        = var.workload_identity_issuer_uri
  workload_identity_allowed_audiences = var.workload_identity_allowed_audiences
  workload_identity_subject           = var.workload_identity_subject
}
