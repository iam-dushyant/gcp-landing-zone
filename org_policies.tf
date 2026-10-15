locals {
    boolean_policies = [
        "iam.disableServiceAccountKeyCreation",
        "compute.requireOsLogin",
        "compute.skipDefaultNetworkCreation",
        "compute.uniformBucketLevelAccess",
        "compute.publicAccessPrevention",
    ]
}

resource "google_org_policy_policy" "bool" {
    for_each = toset(local.boolean_policies)
    name = "organizations/${var.org_id}/policies/${each.key}"
    parent = "organizations/${var.org_id}"
    spec {
        rules {
            enforce = "TRUE"
        }
    }
}

resource "google_org_policy_policy" "locations" {
    name = "organizations/${var.org_id}/policies/gcp.resourceLocations"
    parent = "organizations/${var.org_id}"
    spec {
        rules {
            values {
                allowed_values = ["in:europe-west2-locations"]
            }
        }
    }
}

resource "google_org_policy_policy" "no_external_ip" {
    name = "organizations/${var.org_id}/policies/compute.vmExternalIpAccess"
    parent = "organizations/${var.org_id}"
    spec {
        rules {
            deny_all = "TRUE"
        }
    }
}

resource "google_org_policy_policy" "domain_sharing" {
    name = "organizations/${var.org_id}/policies/iam.allowedPolicyMemberDomains"
    parent = "organizations/${var.org_id}"
    spec {
        rules {
            values {
                allowed_values = [var.customer_id]
            }
        }
    }
    depends_on = [google_project_iam_member.sink_writer, google_kms_crypto_key_iam_member.prod_gcs]
}