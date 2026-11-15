#!/usr/bin/env bash
# Opens the "vibe-coded" pull request: a search feature written the way an AI
# assistant often writes it when nobody asks for guardrails. It is meant to FAIL:
#   - hardcoded token        -> gitleaks (secrets job) + ruff S105
#   - f-string SQL           -> CodeQL SQL injection alert + ruff S608
#   - old requests pin       -> dependency review + pip-audit (known CVEs)
#   - unused import, no tests -> ruff F401, coverage below 85%
# The token is random and fake, generated at run time, so no secret-like
# string is ever committed to main.
set -euo pipefail
BRANCH=vibe/order-search
git switch main && git pull --ff-only
git switch -c "$BRANCH"
FAKE_TOKEN="vibe_$(python3 -c 'import secrets; print(secrets.token_hex(20))')"
FAKE_TOKEN="$FAKE_TOKEN" python3 - <<'PY'
import os, pathlib
p = pathlib.Path("app/main.py")
s = p.read_text()
s = s.replace("import uuid\n", "import uuid\n\nimport requests\n", 1)
s = s.replace(
    "app = FastAPI(",
    f'ADMIN_TOKEN = "{os.environ["FAKE_TOKEN"]}"\n\napp = FastAPI(',
    1,
)
feature = '''@app.get("/orders/search")
def search_orders(item: str, token: str = "") -> list:
    if token != ADMIN_TOKEN:
        raise HTTPException(status_code=401, detail="bad token")
    with closing(db()) as conn:
        rows = conn.execute(f"SELECT * FROM orders WHERE item LIKE '%{item}%'").fetchall()
    return [dict(r) for r in rows]


'''
anchor = '@app.get("/orders/{order_id}")'
s = s.replace(anchor, feature + anchor, 1)
p.write_text(s)
req = pathlib.Path("app/requirements.txt")
req.write_text(req.read_text() + "requests==2.31.0\n")
PY
git add app/main.py app/requirements.txt
git commit -m "Add order search (generated with AI, shipped as-is)"
git push -u origin "$BRANCH"
gh pr create --base main --head "$BRANCH" \
  --title "Add order search endpoint" \
  --body "Vibe-coded with an AI assistant in 30 seconds. It works on my machine. Ship it?"
