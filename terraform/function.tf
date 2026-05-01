# ── App Service Plan (Consumption) ───────────────────────────────────────────
#
# The Consumption plan (Y1) is Azure Functions' serverless tier:
#   - $0 for the first 1 million executions/month (always free)
#   - Scales to zero when idle — no minimum cost
#   - Perfect for a CV site with occasional visitors
#
resource "azurerm_service_plan" "cv" {
  name                = "asp-${var.storage_account_name}"
  resource_group_name = azurerm_resource_group.cv.name
  location            = azurerm_resource_group.cv.location
  os_type             = "Linux"
  sku_name            = "Y1" # Consumption plan
}

# ── Azure Function App ────────────────────────────────────────────────────────
#
# A Function App is the container that runs our Python HTTP function.
# It reuses the existing Storage Account for its own internal state
# (function definitions, logs) — no extra storage resource needed.
#
# The function is triggered by HTTP requests from the visitor counter JS.
# It reads and increments the count in CosmosDB, then returns the new count.
#
resource "azurerm_linux_function_app" "cv" {
  name                = "func-${var.storage_account_name}"
  resource_group_name = azurerm_resource_group.cv.name
  location            = azurerm_resource_group.cv.location

  # Reuse the existing storage account for function app state
  storage_account_name       = azurerm_storage_account.cv.name
  storage_account_access_key = azurerm_storage_account.cv.primary_access_key
  service_plan_id            = azurerm_service_plan.cv.id

  site_config {
    application_stack {
      python_version = "3.11"
    }

    # CORS handled in Python code via Access-Control-Allow-Origin: *
    # Platform-level CORS is left open to avoid blocking any origin.
    cors {
      allowed_origins = ["*"]
    }
  }

  # Environment variables available inside the Python function
  app_settings = {
    # CosmosDB Table API — using account name + key instead of connection string.
    # connection_strings[0] returns a SQL/DocumentDB URI which is incompatible
    # with the azure-data-tables SDK. We construct the Table endpoint manually.
    "COSMOS_ACCOUNT_NAME"      = azurerm_cosmosdb_account.cv.name
    "COSMOS_ACCOUNT_KEY"       = azurerm_cosmosdb_account.cv.primary_key
    "FUNCTIONS_WORKER_RUNTIME" = "python"
  }

  tags = {
    project = "cloud-resume-challenge"
    owner   = "Vincent Le Laverda"
  }
}
