terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.110"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Cloudflare authenticates via API token.
# Store it as an environment variable — never hardcode it:
#   export CLOUDFLARE_API_TOKEN="your-token-here"
#
# Create a token at: Cloudflare Dashboard → My Profile → API Tokens
# Required permissions: Zone → DNS → Edit, Zone → Zone Settings → Edit
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
