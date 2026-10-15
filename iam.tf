locals {
    admin_roles = [
        "roles/resourcemanager.folderAdmin",
        "roles/compute.admin",
        "roles/storage.admin",
        "roles/iam.serviceAccountAdmin",
        "roles/iam.serviceAccountKeyAdmin",
        "roles/iam.serviceAccountUser",
        "roles/compute.osAdminLogin",
        "roles/iap.tunnelResourceAccessor",
        "roles/logging.viewer",
        "roles/logging.viewAccessor",
    ]
    admin_bindings = {for x in setproduct(keys(google_folder.f), local.admin_roles) : "${x[0]}/${x[1]}" => x}
}

resource "google_folder_iam_member" "admin" {
    for_each = local.admin_bindings
    folder = google_folder.f[each.value[0]].name
    role = each.value[1]
    member = "group:platform-admins@${var.domain}"
}

resource "google_folder_iam_member" "dev_nonprod" {
    for_each = toset(["roles/compute.instanceAdmin.v1", "roles/storage.admin"])
    folder = google_folder.f["non_prod"].name
    role = each.key
    member = "group:developers@${var.domain}"
}

resource "google_folder_iam_member" "dev_prod_readonly" {
    for_each = toset(["roles/compute.viewer", "roles/storage.objectViewer"])
    folder = google_folder.f["prod"].name
    role = each.key
    member = "group:developers@${var.domain}"
}