"""
Tests for the visitor counter Azure Function.

Strategy: mock the entire azure-data-tables client chain so no real
CosmosDB connection is made. We test the three meaningful branches:

  1. Counter exists     → incremented and returned
  2. Counter not found  → created at 1 and returned
  3. CosmosDB error     → 500 returned with error JSON
"""

import json
import unittest
from unittest.mock import MagicMock, patch

import azure.functions as func
from azure.core.exceptions import ResourceNotFoundError

# The module under test — imported AFTER mocking env vars so the
# module-level code doesn't crash on missing credentials.
import os
os.environ.setdefault("COSMOS_ACCOUNT_NAME", "test-account")
os.environ.setdefault("COSMOS_ACCOUNT_KEY",  "dGVzdA==")  # base64 placeholder

import function_app  # noqa: E402  (import after env setup)


# ── Helpers ───────────────────────────────────────────────────────────────────

def _make_request() -> func.HttpRequest:
    """Build a minimal GET HttpRequest (no body, no params needed)."""
    return func.HttpRequest(
        method="GET",
        url="https://func-stvincentcv.azurewebsites.net/api/visitor-counter",
        headers={},
        params={},
        route_params={},
        body=b"",
    )


def _mock_table_client(get_entity_side_effect=None, get_entity_return=None):
    """
    Return a mock table_client wired to the desired behaviour:
      - get_entity_side_effect  : exception class to raise (e.g. ResourceNotFoundError)
      - get_entity_return       : dict to return on a successful get
    """
    table_client = MagicMock()

    if get_entity_side_effect is not None:
        table_client.get_entity.side_effect = get_entity_side_effect(
            message="Entity not found",
            response=MagicMock(status_code=404),
        )
    elif get_entity_return is not None:
        table_client.get_entity.return_value = dict(get_entity_return)

    return table_client


# ── Tests ─────────────────────────────────────────────────────────────────────

class TestVisitorCounter(unittest.TestCase):

    # ── patch target: wherever function_app imports TableServiceClient ────────
    PATCH_TSC = "function_app.TableServiceClient"

    # ── 1. Existing counter ───────────────────────────────────────────────────

    @patch(PATCH_TSC)
    def test_increments_existing_count(self, mock_tsc_class):
        """
        When an entity already exists with count=41, the function must:
          - call update_entity with count=42
          - return HTTP 200 with {"count": 42}
        """
        existing_entity = {
            "PartitionKey": "main",
            "RowKey": "counter",
            "count": 41,
        }
        table_client = _mock_table_client(get_entity_return=existing_entity)
        mock_tsc_class.return_value.get_table_client.return_value = table_client

        response = function_app.visitor_counter(_make_request())

        # Status code
        self.assertEqual(response.status_code, 200)

        # Body
        body = json.loads(response.get_body())
        self.assertEqual(body["count"], 42)

        # Side-effects
        table_client.update_entity.assert_called_once()
        table_client.create_entity.assert_not_called()

        # CORS header
        self.assertEqual(response.headers.get("Access-Control-Allow-Origin"), "*")

    # ── 2. First ever visit ───────────────────────────────────────────────────

    @patch(PATCH_TSC)
    def test_creates_counter_on_first_visit(self, mock_tsc_class):
        """
        When no entity exists (ResourceNotFoundError), the function must:
          - call create_entity with count=1
          - return HTTP 200 with {"count": 1}
        """
        table_client = _mock_table_client(
            get_entity_side_effect=ResourceNotFoundError
        )
        mock_tsc_class.return_value.get_table_client.return_value = table_client

        response = function_app.visitor_counter(_make_request())

        self.assertEqual(response.status_code, 200)

        body = json.loads(response.get_body())
        self.assertEqual(body["count"], 1)

        # create_entity must have been called with the right structure
        call_args = table_client.create_entity.call_args[0][0]
        self.assertEqual(call_args["PartitionKey"], "main")
        self.assertEqual(call_args["RowKey"],       "counter")
        self.assertEqual(call_args["count"],        1)

        table_client.update_entity.assert_not_called()

    # ── 3. CosmosDB error ─────────────────────────────────────────────────────

    @patch(PATCH_TSC)
    def test_returns_500_on_db_error(self, mock_tsc_class):
        """
        When TableServiceClient itself raises an unexpected exception,
        the function must return HTTP 500 with an error JSON body —
        never crash or expose the stack trace.
        """
        mock_tsc_class.side_effect = Exception("simulated connection failure")

        response = function_app.visitor_counter(_make_request())

        self.assertEqual(response.status_code, 500)

        body = json.loads(response.get_body())
        self.assertIn("error", body)


if __name__ == "__main__":
    unittest.main()
