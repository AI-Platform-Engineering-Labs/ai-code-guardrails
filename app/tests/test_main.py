from fastapi.testclient import TestClient

from main import app

client = TestClient(app)


def test_healthz():
    assert client.get("/healthz").json()["status"] == "ok"


def test_create_and_get_order():
    created = client.post("/orders", json={"item": "chai", "quantity": 2})
    assert created.status_code == 201
    fetched = client.get(f"/orders/{created.json()['id']}")
    assert fetched.status_code == 200
    assert fetched.json()["item"] == "chai"


def test_missing_order_is_404():
    assert client.get("/orders/does-not-exist").status_code == 404


def test_rejects_bad_quantity():
    assert client.post("/orders", json={"item": "tea", "quantity": 0}).status_code == 422
