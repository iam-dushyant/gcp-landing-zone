variable "org_id" {type = string}
variable "billing_account" {type = string}
variable "prefix" {type = string}
variable "seed_project" {type = string}
variable "domain" {type = string}
variable "customer_id" {type = string}
variable "region" {
    type = string
    default = "europe-west2"
}