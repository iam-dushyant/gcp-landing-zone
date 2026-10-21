locals {
    host = module.project["net-host"].project_id
}

resource "google_compute_shared_vpc_host_project" "host" {
    project = local.host
    depends_on = [module.project]
}

resource "google_compute_network" "shared" {
    project = local.host
    name = "shared-vpc"
    auto_create_subnetworks = false
    routing_mode = "GLOBAL"
    depends_on = [module.project]
}

resource "google_compute_subnetwork" "env" {
    for_each = {non_prod = "10.10.0.0/24", prod = "10.10.1.0/24"}
    project = local.host
    network = google_compute_network.shared.id
    name = "${replace(each.key, "_", "-")}-subnet"
    region = var.region
    ip_cidr_range = each.value
    private_ip_google_access = true
    log_config {
        aggregation_interval = "INTERVAL_10_MIN"
        flow_sampling = 0.1
        metadata = "INCLUDE_ALL_METADATA"
    }
}

resource "google_compute_shared_vpc_service_project" "svc" {
    for_each = toset(["non-prod-app", "prod-app"])
    host_project = google_compute_shared_vpc_host_project.host.project
    service_project = module.project[each.key].project_id

}

resource "google_compute_firewall" "allow-iap-ssh" {
    project = local.host
    name = "allow-iap-ssh"
    network = google_compute_network.shared.id
    direction = "INGRESS"
    priority = 1000
    source_ranges = ["35.235.240.0/20"]
    allow {
        protocol = "tcp"
        ports = ["22"]
    }
}

resource "google_compute_firewall" "deny_all_ingress" {
    project = local.host
    name = "deny-all-ingress"
    network = google_compute_network.shared.id
    direction = "INGRESS"
    priority = 65000
    source_ranges = ["0.0.0.0/0"]
    deny {
        protocol = "all"
    }
    log_config {
        metadata = "INCLUDE_ALL_METADATA"
    }
}

resource "google_compute_subnetwork_iam_member" "dev_non_prod" {
    project = local.host
    region = var.region
    subnetwork = google_compute_subnetwork.env["non_prod"].name
    role = "roles/compute.networkUser"
    member = "group:developers@${var.domain}"
}
