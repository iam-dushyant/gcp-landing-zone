resource "google_folder" "f" {
    for_each = toset(["common", "non_prod", "prod"])
    display_name = each.key
    parent = "organizations/${var.org_id}"
}

locals {
    projects = {
        net-host = {folder = "common", apis = ["compute.googleapis.com"]}
        common-sec = {folder = "common", apis = ["logging.googleapis.com", "cloudkms.googleapis.com", "storage.googleapis.com"]}
        non-prod-app = {folder = "non_prod", apis = ["compute.googleapis.com", "storage.googleapis.com"]}
        prod-app = {folder = "prod", apis = ["compute.googleapis.com", "storage.googleapis.com"]}
    }
    project_apis = flatten([
        for k, p in local.projects : [for a in p.apis : {key = k, api = a}]
    ])
}

resource "google_project" "p" {
    for_each = local.projects
    name = "${var.prefix}-${each.key}"
    project_id = "${var.prefix}-${each.key}"
    folder_id = google_folder.f[each.value.folder].name
    billing_account = var.billing_account
    auto_create_network = false
    deletion_policy = "DELETE"
    labels = {env = each.value.folder, owner = "platform"}
}

resource "google_project_service" "apis" {
    for_each = {for x in local.project_apis : "${x.key}/${x.api}" => x}
    project = google_project.p[each.value.key].project_id
    service = each.value.api
    disable_on_destroy = false
}