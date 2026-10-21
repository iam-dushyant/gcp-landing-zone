variable "project_id" {
  description = "Globally unique project ID"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Project ID must be 6-30 chars, with lowercase letters, numbers, and hyphens."
  }
}

variable "folder_id" {
  description = "Parent folder ID for the project"
  type        = string
}

variable "billing_account" {
  description = "Billing account ID for the project"
  type        = string
}

variable "apis" {
  description = "List of APIs (services) to enable for the project"
  type        = list(string)
  default     = []
  validation {
    condition     = alltrue([for a in var.apis : endswith(a, ".googleapis.com")])
    error_message = "Should end with .googleapis.com"
  }
}

variable "labels" {
  description = "Labels to apply to the project"
  type        = map(string)
  validation {
    condition     = contains(keys(var.labels), "owner") && contains(keys(var.labels), "env")
    error_message = "Labels must contain 'owner' and 'env' keys."
  }
}

variable "budget_gpt" {
  description = "Monthly budget with 50%, 90% and 100% threshold alerts."
  type        = number
  default     = null
}