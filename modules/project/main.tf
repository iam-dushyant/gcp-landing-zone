resource "google_project" "this" {
    name = var.project_id
    project_id = var.project_id
    folder_id = var.folder_id
    billing_account = var.billing_account
    auto_create_network = false
    deletion_policy = "PREVENT"
    labels = var.labels
}

resource "google_project_service" "this" {
    for_each = toset(var.apis)
    project = google_project.this.project_id
    service = each.value
    disable_on_destroy = false
}

resource "google_billing_budget" "this" {
    count = var.budget_gpt == null ? 0 : 1
    billing_account = var.billing_account
    display_name = "${var.project_id} budget"

    budget_filter {
        projects = ["projects/${google_project.this.number}"]
    }

    amount {
        specified_amount {
            currency_code = "GBP"
            units = tostring(var.budget_gpt)
        }
    }

    threshold_rules { threshold_percent = 0.5 }
    threshold_rules { threshold_percent = 0.9 }
    threshold_rules { threshold_percent = 1.0 }
}

