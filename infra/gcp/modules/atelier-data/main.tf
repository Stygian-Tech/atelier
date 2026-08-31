locals {
  labels = {
    application = "atelier"
    environment = var.environment
    managed_by  = "terraform"
  }
  required_services = toset([
    "cloudkms.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "pubsub.googleapis.com",
    "storage.googleapis.com",
    "sts.googleapis.com",
  ])
  workload_identity_enabled = (
    var.workload_identity_issuer_uri != null &&
    var.workload_identity_subject != null &&
    length(var.workload_identity_allowed_audiences) > 0
  )
}

resource "google_project_service" "required" {
  for_each = local.required_services
  project  = var.project_id
  service  = each.value

  disable_on_destroy = false
}

resource "google_kms_key_ring" "atelier" {
  name     = "atelier-${var.environment}"
  location = var.kms_location
  project  = var.project_id

  depends_on = [google_project_service.required]
}

resource "google_kms_crypto_key" "provider_envelope" {
  name            = "provider-envelope"
  key_ring        = google_kms_key_ring.atelier.id
  rotation_period = "7776000s"

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_service_account" "runtime" {
  project      = var.project_id
  account_id   = "atelier-runtime-${var.environment == "production" ? "prod" : "dev"}"
  display_name = "Atelier ${title(var.environment)} runtime"

  depends_on = [google_project_service.required]
}

resource "google_kms_crypto_key_iam_member" "runtime" {
  crypto_key_id = google_kms_crypto_key.provider_envelope.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_service_account.runtime.email}"
}

data "google_storage_project_service_account" "gcs" {
  project = var.project_id

  depends_on = [google_project_service.required]
}

resource "google_kms_crypto_key_iam_member" "gcs" {
  crypto_key_id = google_kms_crypto_key.provider_envelope.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_storage_project_service_account.gcs.email_address}"
}

resource "google_storage_bucket" "provider_cache" {
  project                     = var.project_id
  name                        = var.provider_cache_bucket_name
  location                    = upper(var.kms_location)
  force_destroy               = false
  uniform_bucket_level_access = true
  labels                      = local.labels

  public_access_prevention = "enforced"

  encryption {
    default_kms_key_name = google_kms_crypto_key.provider_envelope.id
  }

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.required, google_kms_crypto_key_iam_member.gcs]
}

resource "google_storage_bucket" "durable" {
  project                     = var.project_id
  name                        = var.durable_bucket_name
  location                    = upper(var.kms_location)
  force_destroy               = false
  uniform_bucket_level_access = true
  labels                      = local.labels

  public_access_prevention = "enforced"

  encryption {
    default_kms_key_name = google_kms_crypto_key.provider_envelope.id
  }

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      days_since_noncurrent_time = 30
      num_newer_versions         = 3
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.required, google_kms_crypto_key_iam_member.gcs]
}

resource "google_storage_bucket_iam_member" "runtime_provider_cache" {
  bucket = google_storage_bucket.provider_cache.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_storage_bucket_iam_member" "runtime_durable" {
  bucket = google_storage_bucket.durable.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_pubsub_topic" "gmail" {
  project = var.project_id
  name    = "atelier-gmail-${var.environment}"
  labels  = local.labels

  message_retention_duration = "86400s"

  depends_on = [google_project_service.required]
}

resource "google_pubsub_topic_iam_member" "gmail_api_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.gmail.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:gmail-api-push@system.gserviceaccount.com"
}

resource "google_pubsub_subscription" "gmail_sync" {
  project = var.project_id
  name    = "atelier-gmail-sync-${var.environment}"
  topic   = google_pubsub_topic.gmail.id

  ack_deadline_seconds       = 60
  message_retention_duration = "604800s"
  retain_acked_messages      = false

  expiration_policy {
    ttl = "2678400s"
  }

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }
}

resource "google_pubsub_subscription_iam_member" "runtime_gmail_subscriber" {
  project      = var.project_id
  subscription = google_pubsub_subscription.gmail_sync.name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_iam_workload_identity_pool" "runtime" {
  count = local.workload_identity_enabled ? 1 : 0

  project                   = var.project_id
  workload_identity_pool_id = "atelier-${var.environment == "production" ? "prod" : "dev"}"
  display_name              = "Atelier ${title(var.environment)} runtime"

  depends_on = [google_project_service.required]
}

resource "google_iam_workload_identity_pool_provider" "runtime" {
  count = local.workload_identity_enabled ? 1 : 0

  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.runtime[0].workload_identity_pool_id
  workload_identity_pool_provider_id = "runtime-oidc"
  display_name                       = "Reviewed runtime OIDC"
  attribute_mapping = {
    "google.subject" = "assertion.sub"
  }

  oidc {
    issuer_uri        = var.workload_identity_issuer_uri
    allowed_audiences = var.workload_identity_allowed_audiences
  }
}

resource "google_service_account_iam_member" "workload_identity" {
  count = local.workload_identity_enabled ? 1 : 0

  service_account_id = google_service_account.runtime.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/${google_iam_workload_identity_pool.runtime[0].name}/subject/${var.workload_identity_subject}"
}
