# Bootstrap

Terraform needs somewhere to store its state and an identity to run as before it can build anything. Those can't be created by the same Terraform that depends on them, so they are created once, by hand, with the commands below. Everything after this is Terraform.

**What this creates**

| Resource | Purpose |
|---|---|
| `<prefix>-seed` project | Holds state and the Terraform identity, outside the landing-zone folders so `terraform destroy` can never delete them |
| `gs://<prefix>-seed-tfstate` bucket | Remote Terraform state, versioned |
| `terraform@<prefix>-seed` service account | The only identity that applies changes; people impersonate it, no keys |

## Prerequisites

- A Google Cloud organisation (Cloud Identity Free + a verified domain)
- Your admin user has Organization Administrator, Organization Policy Administrator, Folder Admin, Project Creator, Billing Account Administrator, Access Context Manager Admin and Logging Admin
- A billing account with a budget alert
- Groups `gcp-platform-admins@<domain>` (you in it) and `gcp-developers@<domain>`
- `gcloud` and Terraform >= 1.6

## 1. Log in as the admin user

```bash
gcloud auth login                         # pick admin@<domain>
gcloud auth application-default login     # same account; tick "Select all" on the consent screen
gcloud auth list                          # admin@<domain> must be active
```

## 2. Set variables

```bash
export ORG_ID=$(gcloud organizations list --format='value(ID)')
export BILLING=<billing-account-id>       # gcloud billing accounts list
export PREFIX=<unique-lowercase-prefix>
export SEED=${PREFIX}-seed
export ADMIN=admin@<domain>
```

## 3. Seed project and APIs

```bash
gcloud projects create $SEED --organization=$ORG_ID
gcloud billing projects link $SEED --billing-account=$BILLING
gcloud services enable cloudresourcemanager.googleapis.com cloudbilling.googleapis.com \
  iam.googleapis.com iamcredentials.googleapis.com serviceusage.googleapis.com \
  orgpolicy.googleapis.com logging.googleapis.com cloudkms.googleapis.com \
  accesscontextmanager.googleapis.com compute.googleapis.com storage.googleapis.com \
  --project=$SEED
```

## 4. State bucket

```bash
gcloud storage buckets create gs://${SEED}-tfstate --project=$SEED \
  --location=europe-west2 --uniform-bucket-level-access
gcloud storage buckets update gs://${SEED}-tfstate --versioning
```

## 5. Terraform service account

```bash
gcloud iam service-accounts create terraform --project=$SEED --display-name="Landing zone Terraform"
export TF_SA=terraform@${SEED}.iam.gserviceaccount.com

for ROLE in roles/resourcemanager.folderAdmin roles/resourcemanager.projectCreator \
  roles/orgpolicy.policyAdmin roles/compute.xpnAdmin roles/logging.configWriter \
  roles/accesscontextmanager.policyAdmin roles/iam.organizationRoleViewer; do
  gcloud organizations add-iam-policy-binding $ORG_ID \
    --member=serviceAccount:$TF_SA --role=$ROLE --condition=None
done
gcloud billing accounts add-iam-policy-binding $BILLING \
  --member=serviceAccount:$TF_SA --role=roles/billing.user
gcloud storage buckets add-iam-policy-binding gs://${SEED}-tfstate \
  --member=serviceAccount:$TF_SA --role=roles/storage.objectAdmin
gcloud iam service-accounts add-iam-policy-binding $TF_SA --project=$SEED \
  --member=user:$ADMIN --role=roles/iam.serviceAccountTokenCreator
```

## 6. Point Terraform at it

In `versions.tf`, set the backend `bucket` to `<prefix>-seed-tfstate` and `impersonate_service_account` to `terraform@<prefix>-seed.iam.gserviceaccount.com` (backends can't read variables). Set `prefix`, `seed_project` and `tf_sa` in `terraform.tfvars` to match.

```bash
terraform init
```

## Verify

```bash
gcloud storage ls gs://${SEED}-tfstate --impersonate-service-account=$TF_SA   # works = impersonation OK
```

## Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| `iam.serviceAccounts.getAccessToken denied ... (or it may not exist)` on `terraform init` | Service account email in `versions.tf` doesn't match your prefix, or ADC is logged in as a different Google account | Fix the email; check ADC with `curl -s "https://oauth2.googleapis.com/tokeninfo?access_token=$(gcloud auth application-default print-access-token)"` and re-login as admin |
| `Scope has changed from ... to "userinfo.email openid"` | Cloud Platform permission not ticked on the consent screen | Re-run `gcloud auth application-default login` and tick **Select all** |
| Same 403 right after granting Token Creator | IAM propagation | Wait 5 to 10 minutes |
