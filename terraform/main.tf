# ── Resource Group ──────────────────────────────────────────────────────────
resource "azurerm_resource_group" "cv" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    project = "cloud-resume-challenge"
    owner   = "Vincent Le Laverda"
  }
}

# ── Storage Account ──────────────────────────────────────────────────────────
resource "azurerm_storage_account" "cv" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.cv.name
  location                 = azurerm_resource_group.cv.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # ── Static website hosting ──────────────────────────────────────────────────
  static_website {
    index_document     = "index.html"
    error_404_document = "index.html"
  }

  # ── Transit security ────────────────────────────────────────────────────────
  enable_https_traffic_only = true
  min_tls_version           = "TLS1_2"

  # ── Encryption at rest ──────────────────────────────────────────────────────
  # Enables a second layer of AES-256 encryption at the infrastructure level.
  # Must be set at creation — cannot be changed after deployment.
  infrastructure_encryption_enabled = true

  # ── Public access ───────────────────────────────────────────────────────────
  # Required for Azure Storage static websites: the $web container blobs must
  # be publicly readable. Explicitly documented to justify the exception.
  public_network_access_enabled   = true
  allow_nested_items_to_be_public = true

  # ── Cross-tenant replication ────────────────────────────────────────────────
  # Prevent Azure from replicating data to storage accounts in other AAD tenants.
  cross_tenant_replication_enabled = false

  # ── Shared key access ───────────────────────────────────────────────────────
  # Kept enabled: Terraform and GitHub Actions CI/CD both need the storage key
  # to upload blobs. Disable and switch to Azure AD RBAC if you add a service
  # principal with Storage Blob Data Contributor role in a future hardening pass.
  shared_access_key_enabled = true

  # ── Blob soft-delete & versioning ──────────────────────────────────────────
  blob_properties {
    delete_retention_policy {
      days = 7 # Recover accidentally deleted blobs for up to 7 days
    }
    versioning_enabled = true
  }

  tags = {
    project = "cloud-resume-challenge"
    owner   = "Vincent Le Laverda"
  }
}

# ── Upload HTML pages into the $web container ────────────────────────────────
resource "azurerm_storage_blob" "index" {
  name                   = "index.html"
  storage_account_name   = azurerm_storage_account.cv.name
  storage_container_name = "$web"
  type                   = "Block"
  source                 = "${path.module}/../index.html"
  content_type           = "text/html"
  content_md5            = filemd5("${path.module}/../index.html")
}

resource "azurerm_storage_blob" "how_i_was_built" {
  name                   = "how-i-was-built.html"
  storage_account_name   = azurerm_storage_account.cv.name
  storage_container_name = "$web"
  type                   = "Block"
  source                 = "${path.module}/../how-i-was-built.html"
  content_type           = "text/html"
  content_md5            = filemd5("${path.module}/../how-i-was-built.html")
}

resource "azurerm_storage_blob" "counter_js" {
  name                   = "counter.js"
  storage_account_name   = azurerm_storage_account.cv.name
  storage_container_name = "$web"
  type                   = "Block"
  source                 = "${path.module}/../counter.js"
  content_type           = "application/javascript"
  content_md5            = filemd5("${path.module}/../counter.js")
}
