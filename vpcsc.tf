resource "google_access_context_manager_access_policy" "lz" {
    parent = "organizations/${var.org_id}"
    title  = "lz-policy"
}

resource "google_access_context_manager_service_parameter" "prod" {
    parent = "accessPolicies/${google_access_context_manager_access_policy.lz.name}"
    name = "accessPolicies/${google_access_context_manager_access_policy.lz.name}/servicePerimeters/prod_perimeter"
    title = "prod-perimeter"

    use_explicit_dry_run_spec = true
    spec {
        resources = ["projects/${google_project.p["prod-app"].number}"]
        restricted_services = ["storage.googleapis.com"]
    }
}