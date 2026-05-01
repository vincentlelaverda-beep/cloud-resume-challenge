variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastasia"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-cloud-cv"
}

variable "storage_account_name" {
  description = "Storage account name (3-24 chars, lowercase letters and numbers only)"
  type        = string
  default     = "stvincentcv"
}

variable "domain_name" {
  description = "Your custom domain (e.g. vincentlelaverda.com)"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID — found in the Cloudflare dashboard, right sidebar of your domain"
  type        = string
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token — create at: My Profile → API Tokens. Never commit this value."
  type        = string
  sensitive   = true  # Terraform will never print this in logs or plan output
}

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID — found in the dashboard right sidebar of any domain"
  type        = string
  default     = ""
}
