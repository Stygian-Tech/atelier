variable "project_id" {
  type = string
}

variable "environment" {
  type = string
}

variable "kms_location" {
  type = string
}

variable "provider_cache_bucket_name" {
  type = string
}

variable "durable_bucket_name" {
  type = string
}

variable "workload_identity_issuer_uri" {
  type     = string
  default  = null
  nullable = true
}

variable "workload_identity_allowed_audiences" {
  type    = list(string)
  default = []
}

variable "workload_identity_subject" {
  type     = string
  default  = null
  nullable = true
}
