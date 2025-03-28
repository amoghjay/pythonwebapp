import pytest
from fastapi.testclient import TestClient
import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from main import app
from unittest.mock import patch

client = TestClient(app)

@patch("boto3.Session")
def test_healthz(mock_boto):
    from main import app  # Mocked so it won't break due to missing AWS profile
    assert app is not None


def test_healthz_success():
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.text == ""
    assert "Cache-Control" in response.headers
    assert response.headers["Cache-Control"] == "no-cache, no-store, must-revalidate"
    assert "Pragma" in response.headers
    assert response.headers["Pragma"] == "no-cache"

def test_healthz_with_query_params():
    response = client.get("/healthz?param=test")
    assert response.status_code == 400
    assert "Cache-Control" in response.headers
    assert response.headers["Cache-Control"] == "no-cache, no-store, must-revalidate"
    assert "Pragma" in response.headers
    assert response.headers["Pragma"] == "no-cache"

@pytest.mark.parametrize("method", ["POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"])
def test_healthz_method_not_allowed(method):
    response = client.request(method, "/healthz")
    assert response.status_code == 405
    assert "Cache-Control" in response.headers
    assert response.headers["Cache-Control"] == "no-cache, no-store, must-revalidate"
    assert "Pragma" in response.headers
    assert response.headers["Pragma"] == "no-cache"

def test_healthz_database_failure(mocker):
    mocker.patch("routers.health.models.HealthCheck", side_effect=Exception("Database error"))
    response = client.get("/healthz")
    assert response.status_code == 503
    assert "Cache-Control" in response.headers
    assert response.headers["Cache-Control"] == "no-cache, no-store, must-revalidate"
    assert "Pragma" in response.headers
    assert response.headers["Pragma"] == "no-cache"
