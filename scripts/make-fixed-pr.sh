#!/usr/bin/env bash
# Opens the corrected pull request: same feature, written inside the guardrails.
# Token from configuration, parameterized SQL, no unused dependency, and tests.
set -euo pipefail
BRANCH=fix/order-search
git switch main && git pull --ff-only
git switch -c "$BRANCH"
python3 - <<'PY'
import pathlib
p = pathlib.Path("app/main.py")
s = p.read_text()
s = s.replace("import os\n", "import os\nimport secrets\n", 1)
feature = '''@app.get("/orders/search")
def search_orders(item: str = Query(min_length=1, max_length=100), token: str = Header(default="")) -> list:
    expected = os.getenv("ADMIN_TOKEN", "")
    if not expected or not secrets.compare_digest(token, expected):
        raise HTTPException(status_code=401, detail="unauthorized")
    with closing(db()) as conn:
        rows = conn.execute("SELECT * FROM orders WHERE item LIKE ?", (f"%{item}%",)).fetchall()
    return [dict(r) for r in rows]


'''
anchor = '@app.get("/orders/{order_id}")'
s = s.replace(anchor, feature + anchor, 1)
s = s.replace("from fastapi import FastAPI, HTTPException", "from fastapi import FastAPI, Header, HTTPException, Query", 1)
p.write_text(s)
t = pathlib.Path("app/tests/test_search.py")
t.write_text('''from fastapi.testclient import TestClient

from main import app

client = TestClient(app)


def test_search_requires_token(monkeypatch):
    monkeypatch.setenv("ADMIN_TOKEN", "test-only-value")
    assert client.get("/orders/search", params={"item": "chai"}).status_code == 401


def test_search_finds_matching_orders(monkeypatch):
    monkeypatch.setenv("ADMIN_TOKEN", "test-only-value")
    client.post("/orders", json={"item": "masala chai", "quantity": 1})
    resp = client.get("/orders/search", params={"item": "chai"}, headers={"token": "test-only-value"})
    assert resp.status_code == 200
    assert any("chai" in o["item"] for o in resp.json())


def test_search_treats_sql_as_text(monkeypatch):
    monkeypatch.setenv("ADMIN_TOKEN", "test-only-value")
    resp = client.get("/orders/search", params={"item": "' OR '1'='1"}, headers={"token": "test-only-value"})
    assert resp.status_code == 200
    assert resp.json() == []
''')
PY
git add app/main.py app/tests/test_search.py
git commit -m "Add order search with guardrails: config token, parameterized SQL, tests"
git push -u origin "$BRANCH"
gh pr create --base main --head "$BRANCH" \
  --title "Add order search endpoint (guardrailed)" \
  --body "Same feature as the vibe-coded PR, fixed with help from Copilot Autofix and the review comments. Token comes from app settings; SQL is parameterized; tests cover auth and injection."
