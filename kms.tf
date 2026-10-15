resource "google_kms_key_ring" "lz" {
    for_each = local.sec
    name     = "lz-keyring"
    location = var.region
    depends_on = [google_project_service.apis]
}

resource "google_kms_crypto_key" "data" {
    name = "prod-data"
    key_ring = google_kms_key_ring.lz.id
    rotation_period = "7776000s"
}

data "google_storage_project_service_account" "prod_gcs" {
    project = google_project.p["prod"].project_id
    depends_on = [google_project_service.apis]
}

resource "google_kms_crypto_key_iam_member" "prod-gcs" {
    crypto_key_id = google_kms_crypto_key.data.id
    role = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
    member = "serviceAccount:${data.google_storage_project_service_account.prod_gcs.email_address}"
}

resource "google_storage_bucket" "prod_data" {
    project = google_project.p["prod-app"].project_id
    name = "${var.prefix}-prod-data"
    location = var.region
    uniform_bucket_level_access = true
    public_access_prevention = "enforced"
    force_destroy = true
    encryption {
        default_kms_key_name = google_kms_crypto_key.data.id
    }
    depends_on = [google_kms_crypto_key_iam_member.prod-gcs]
}