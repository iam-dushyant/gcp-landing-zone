import {
  to = module.project["prod-app"].google_project.this
  id = "d-fyi-lz-prod-app"
}

import {
  to = google_org_policy_policy.bool["storage.uniformBucketLevelAccess"]
  id = "organizations/358442967069/policies/storage.uniformBucketLevelAccess"
}

import {
  to = google_org_policy_policy.domain_sharing
  id = "organizations/358442967069/policies/iam.allowedPolicyMemberDomains"
}