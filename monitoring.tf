# Central observability in the security project.

# 1. One metrics scope: common-sec can see metrics from the workload projects.
resource "google_monitoring_monitored_project" "apps" {
  for_each      = toset(["nonprod-app", "prod-app", "net-host"])
  metrics_scope = "locations/global/metricsScopes/${local.sec}"
  name          = module.project[each.key].project_id
  depends_on    = [module.project]
}

resource "google_monitoring_notification_channel" "email" {
  project      = local.sec
  display_name = "Platform team email"
  type         = "email"
  labels       = { email_address = var.alert_email }
  depends_on   = [module.project]
}

# 2. Detect governance changes from the central audit bucket.
#    Bucket-scoped log-based metrics count entries in org-audit, wherever they came from.
locals {
  governance_metrics = {
    org-policy-changes = "protoPayload.serviceName=\"orgpolicy.googleapis.com\" AND protoPayload.methodName:(\"Create\" OR \"Update\" OR \"Delete\")"
    org-iam-changes    = "protoPayload.methodName=\"SetIamPolicy\" AND resource.type=(\"organization\" OR \"folder\")"
    perimeter-changes  = "protoPayload.serviceName=\"accesscontextmanager.googleapis.com\" AND NOT protoPayload.methodName:(\"Get\" OR \"List\")"
  }
}

resource "google_logging_metric" "governance" {
  for_each    = local.governance_metrics
  project     = local.sec
  name        = each.key
  bucket_name = google_logging_project_bucket_config.audit.id
  filter      = each.value
  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
  }
}

resource "google_monitoring_alert_policy" "governance" {
  for_each     = local.governance_metrics
  project      = local.sec
  display_name = "Governance change: ${each.key}"
  combiner     = "OR"

  conditions {
    display_name = "${each.key} > 0"
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.governance[each.key].name}\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "0s"
      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_SUM"
        cross_series_reducer = "REDUCE_SUM"
      }
      trigger { count = 1 }
    }
  }

  documentation {
    content   = "A guardrail-level change (${each.key}) was made. If it did not come from the pipeline, investigate in the org-audit bucket."
    mime_type = "text/markdown"
  }
  notification_channels = [google_monitoring_notification_channel.email.id]
}

# 3. A dashboard: VM CPU across every project in the scope, plus blocked traffic.
resource "google_monitoring_dashboard" "platform" {
  project = local.sec
  dashboard_json = jsonencode({
    displayName = "Landing zone overview"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          width = 6, height = 4
          widget = {
            title = "VM CPU utilisation (all projects)"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter      = "metric.type=\"compute.googleapis.com/instance/cpu/utilization\" resource.type=\"gce_instance\""
                    aggregation = { alignmentPeriod = "60s", perSeriesAligner = "ALIGN_MEAN" }
                  }
                }
                plotType = "LINE"
              }]
            }
          }
        },
        {
          xPos = 6, width = 6, height = 4
          widget = {
            title = "Governance changes (count)"
            xyChart = {
              dataSets = [for k in keys(local.governance_metrics) : {
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter      = "metric.type=\"logging.googleapis.com/user/${k}\""
                    aggregation = { alignmentPeriod = "300s", perSeriesAligner = "ALIGN_SUM" }
                  }
                }
                plotType = "STACKED_BAR"
              }]
            }
          }
        },
      ]
    }
  })
  depends_on = [google_logging_metric.governance]
}
