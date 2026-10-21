# Guardrails checked against terraform plan, before apply
# Run: terraform show -json tfplan > plan.json && conftest test plan.json -p policy

package main

import rego.v1

# Resources being created or changed by this plan
changing contains rc if {
    some rc in input.resource_changes
    some action in rc.change.actions
    action in {"create", "update"}
}

basic_roles := {"roles/owner", "roles/editor", "roles/viewer"}

is_iam_grant(rc) if {
    startswith(rc.type, "google_")
    regex.match(`_iam_(member|binding)`, rc.type)
}

# 1. Every project carries ownership and environment labels (costs and accountability)
deny contains msg if {
    some rc in changing
    rc.type == "google_project"
    some label in ["owner", "env"]
    not rc.change.after.labels[label]
    msg := sprintf("%s: projects must have '%s' label", [rc.address, label])
}

# 2. No basic roles, for anyone
deny contains msg if {
    some rc in changing
    is_iam_grant(rc)
    rc.change.after.role in basic_roles
    msg := sprintf("%s: basic role %s is not allowed, use a predefined role", [rc.address, rc.change.after.role])
}

# 3. Access goes to groups or service accounts, never named to people
deny contains msg if {
    some rc in changing
    is_iam_grant(rc)
    startswith(rc.change.after.member, "user:")
    msg := sprintf("%s: grant to %s; grant to a group instead", [rc.address, rc.change.after.member])
}

# 4. No firewall rule may ALLOW ingress from the whole internet
deny contains msg if {
    some rc in changing
    rc.type == "google_compute_firewall"
    rc.change.after.direction == "INGRESS"
    count(rc.change.after.allow) > 0
    "0.0.0.0/0" in rc.change.after.source_ranges
    msg := sprintf("%s: allows ingress from 0.0.0.0/0", [rc.address])
}

# 5. Buckets are private and use uniform access
deny contains msg if {
    some rc in changing
    rc.type == "google_storage_bucket"
    rc.change.after.public_access_prevention != "enforced"
    msg := sprintf("%s: public_access_prevention must be \"enforced\"", [rc.address])
}

deny contains msg if {
    some rc in changing
    rc.type == "google_storage_bucket"
    rc.change.after.uniform_bucket_level_access != true
    msg := sprintf("%s: uniform_bucket_level_access must be true", [rc.address])
}

# 6. Production buckets must be encrypted with a customer-managed key
deny contains msg if {
    some rc in changing
    rc.type == "google_storage_bucket"
    contains(rc.change.after.name, "prod")
    count(object.get(rc.change.after, "encryption", [])) == 0
    msg := sprintf("%s: production buckets must use a customer-managed encryption key", [rc.address])
}

precious := {"google_project", "google_kms_crypto_key", "google_logging_project_bucket_config", "google_folder"}

warn contains msg if {
    some rc in input.resource_changes
    "delete" in rc.change.actions
    rc.type in precious
    msg := sprintf("%s will be DESTROYED, check this is intended", [rc.address])
}