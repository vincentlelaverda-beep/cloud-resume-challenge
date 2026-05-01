output "storage_origin_url" {
  description = "Direct Azure Storage URL (origin — do not share publicly)"
  value       = azurerm_storage_account.cv.primary_web_endpoint
}

output "website_url" {
  description = "Your public CV URL via Cloudflare (HTTPS enforced)"
  value       = "https://${var.domain_name}"
}

output "www_url" {
  description = "Your public CV URL with www prefix"
  value       = "https://www.${var.domain_name}"
}

output "storage_account_name" {
  description = "Storage account name (needed for CI/CD)"
  value       = azurerm_storage_account.cv.name
}

output "resource_group_name" {
  description = "Resource group name (needed for CI/CD)"
  value       = azurerm_resource_group.cv.name
}

output "function_url" {
  description = "Azure Function URL — paste this into counter.js as COUNTER_API_URL"
  value       = "https://${azurerm_linux_function_app.cv.default_hostname}/api/visitor-counter"
}

output "function_app_name" {
  description = "Function App name (needed for CI/CD deployment)"
  value       = azurerm_linux_function_app.cv.name
}
