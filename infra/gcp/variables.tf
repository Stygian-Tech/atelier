variable "enable_resources" {
  description = "Explicit approval gate. Keep false until the target environment is approved."
  type        = bool
  default     = false
}

variable "project_id" {
  description = "Dedicated Google Cloud project ID for one Atelier environment."
  type        = string
}

variable "environment" {
  description = "Atelier environment name."
  type        = string

  validation {
    condition     = contains(["development", "production"], var.environment)
    error_message = "environment must be development or production"
  }
}

variable "region" {
  description = "Default regional API location."
  type        = string
  default     = "us-central1"
}

variable "kms_location" {
  description = "KMS location matching the US multi-region storage buckets."
  type        = string
  default     = "us"
}

variable "provider_cache_bucket_name" {
  description = "Globally unique bucket name for expiring encrypted provider cache."
  type        = string
}

variable "durable_bucket_name" {
  description = "Globally unique bucket name for encrypted attachments and exports."
  type        = string
}

variable "workload_identity_issuer_uri" {
  description = "Optional reviewed runtime OIDC issuer. Null leaves workload identity disabled."
  type        = string
  default     = null
  nullable    = true
}

variable "workload_identity_allowed_audiences" {
  description = "Expected audiences for the optional runtime OIDC issuer."
  type        = list(string)
  default     = []
}

variable "workload_identity_subject" {
  description = "Exact OIDC subject allowed to impersonate the runtime service account."
  type        = string
  default     = null
  nullable    = true
}
