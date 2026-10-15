terraform {
    required_version = ">= 1.6"
    required_providers {
        google = {
            source  = "hashicorp/google"
            version = "~> 6.0"
        }
    }
    backend "gcs" {
        bucket      = "d-fyi-lz-seed-tfstate"
        prefix      = "landing-zone"
        impersonate_service_account = "terraform@d-fyi-lz-seed.iam.gserviceaccount.com"
    }
}

provider "google" {
    impersonate_service_account = var.tf_sa
    region                     = "europe-west2"
    billing_project             = var.seed_project
    user_project_override         = true
}