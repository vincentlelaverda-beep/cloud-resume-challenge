import json
import logging
import os

import azure.functions as func
from azure.data.tables import TableServiceClient
from azure.core.credentials import AzureNamedKeyCredential
from azure.core.exceptions import ResourceNotFoundError

# ── Function App ──────────────────────────────────────────────────────────────
# Azure Functions v2 Python programming model.
# A single file defines all functions using decorators.
# ─────────────────────────────────────────────────────────────────────────────
app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)


@app.route(route="visitor-counter", methods=["GET"])
def visitor_counter(req: func.HttpRequest) -> func.HttpResponse:
    """
    HTTP GET /api/visitor-counter

    Increments the visitor count in CosmosDB Table storage and returns
    the new count as JSON: { "count": 42 }

    CosmosDB Table entity structure:
        PartitionKey : "main"
        RowKey       : "counter"
        count        : <integer>
    """
    logging.info("Visitor counter function triggered.")

    # Build the CosmosDB Table API endpoint explicitly.
    # The Table API endpoint differs from the SQL/DocumentDB endpoint:
    #   Table : https://<account>.table.cosmos.azure.com
    #   SQL   : https://<account>.documents.azure.com  ← wrong for azure-data-tables
    account_name = os.environ["COSMOS_ACCOUNT_NAME"]
    account_key  = os.environ["COSMOS_ACCOUNT_KEY"]
    endpoint     = f"https://{account_name}.table.cosmos.azure.com"

    try:
        credential    = AzureNamedKeyCredential(account_name, account_key)
        table_service = TableServiceClient(endpoint=endpoint, credential=credential)
        table_client  = table_service.get_table_client("visitorcount")

        try:
            # Fetch existing counter entity
            entity = table_client.get_entity(
                partition_key="main",
                row_key="counter"
            )
            count = int(entity["count"]) + 1
            entity["count"] = count
            table_client.update_entity(entity)

        except ResourceNotFoundError:
            # First ever visit — create the counter entity
            count = 1
            table_client.create_entity({
                "PartitionKey": "main",
                "RowKey":       "counter",
                "count":        count,
            })

        return func.HttpResponse(
            body=json.dumps({"count": count}),
            mimetype="application/json",
            status_code=200,
            headers={"Access-Control-Allow-Origin": "*"},
        )

    except Exception as exc:
        logging.error("Error updating visitor count: %s", exc)
        return func.HttpResponse(
            body=json.dumps({"error": "Could not update visitor count"}),
            mimetype="application/json",
            status_code=500,
        )
