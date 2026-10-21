package main

import rego.v1

plan(rc) := {"resource_changes": [rc]}

change(type, after) := {
    "address": sprintf("%s.test", [type]),
    "type": type,
    "change": {"actions":["create"], "after": after}
}

test_project_without_owner_label_denied if {
    "google_project.test: projects must have 'owner' label" in deny with input as
        plan(change("google_project", {"labels": {"env": "prod"}}))
}

test_production_bucket_without_encryption_denied if {
    "google_storage_bucket.test: production buckets must use a customer-managed encryption key" in deny with input as
        plan(change("google_storage_bucket", {"name": "prod-data"}))
}