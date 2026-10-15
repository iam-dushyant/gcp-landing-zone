locals { sec = google_project.p["common-sec"].project_id }

resource "google_logging_project_bucket_config" "audit" {
    project = local.sec
    location = var.region
    bucket_id = "org-audit"
    retention_days = 30
    depends_on = [google_project_service.apis]
}

resource "google_logging_organization_sink" "audit" {
    name = "org-audit-sink"
    org_id = var.org_id
    include_children = true
    destination = "logging.googleapis.com/projects/${local.sec}/locations/${var.region}/buckets/org-audit"
    filter = "logName:\"cloudaudit.googleapis.com\""
    depends_on = [google_logging_project_bucket_config.audit]
}

resource "google_project_iam_member" "sink_writer" {
    project = local.sec
    role = "roles/logging.bucketWriter"
    member = google_logging_organization_sink.audit.writer_identity
}