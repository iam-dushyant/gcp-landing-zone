resource "google_folder" "f" {
    for_each = toset(["common", "non_prod", "prod"])
    display_name = each.key
    parent = "organizations/${var.org_id}"
}

locals {
    projects = {
        for f in fileset("${path.module}/projects", "*.yaml") :
        trimsuffix(f, ".yaml") => yamldecode(file("${path.module}/projects/${f}"))
    }
}

module "project" {
    for_each = local.projects
    source = "./modules/project"
    project_id = "${var.prefix}-${each.key}"
    folder_id = google_folder.f[each.value.folder].name
    billing_account = var.billing_account
    apis = each.value.apis
    labels = {
        env = each.value.folder,
        owner = each.value.owner
    }
}