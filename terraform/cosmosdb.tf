# ── CosmosDB Account ──────────────────────────────────────────────────────────
#
# CosmosDB is Azure's globally distributed NoSQL database.
# We use it to store the visitor counter — a single number that increments
# on each visit.
#
# Two capabilities are enabled:
#   - EnableTable : activates the Table API (key-value store, simple and cheap)
#   - EnableServerless : pay-per-request instead of provisioned throughput.
#     For a low-traffic CV site this costs essentially $0.
#
# ⚠️  free_tier_enabled and EnableServerless are mutually exclusive in Azure.
#     Serverless is the right choice here per the Cloud Resume Challenge spec.
#
resource "azurerm_cosmosdb_account" "cv" {
  name                = "cosmos-${var.storage_account_name}"
  location            = azurerm_resource_group.cv.location
  resource_group_name = azurerm_resource_group.cv.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  # Table API — simple key-value interface, no schema needed
  capabilities {
    name = "EnableTable"
  }

  # Serverless — no minimum cost, billed per operation
  capabilities {
    name = "EnableServerless"
  }

  # Session consistency: reads always see writes from the same session.
  # Sufficient for a visitor counter (strong consistency would cost more).
  consistency_policy {
    consistency_level = "Session"
  }

  # Single-region deployment — enough for a personal site
  geo_location {
    location          = azurerm_resource_group.cv.location
    failover_priority = 0
  }

  tags = {
    project = "cloud-resume-challenge"
    owner   = "Vincent Le Laverda"
  }
}

# ── CosmosDB Table ────────────────────────────────────────────────────────────
#
# A Table is a collection of entities (rows). Each entity has:
#   - PartitionKey : groups related entities (we use "main")
#   - RowKey       : unique ID within a partition (we use "counter")
#   - count        : our custom field holding the visitor count (integer)
#
resource "azurerm_cosmosdb_table" "visitor_count" {
  name                = "visitorcount"
  resource_group_name = azurerm_resource_group.cv.name
  account_name        = azurerm_cosmosdb_account.cv.name
}
