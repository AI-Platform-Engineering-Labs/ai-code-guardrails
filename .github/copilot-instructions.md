# Rules for AI-written code in this repo

Copilot: follow these rules when generating or changing code here.

- Never put secrets, tokens or passwords in code. Read them from environment variables (App Service app settings).
- Always use parameterized SQL (`?` placeholders). Never build SQL with f-strings or string concatenation.
- Validate every input with Pydantic models or FastAPI `Query`/`Header` constraints.
- Every new endpoint gets pytest tests in `app/tests/`, including an unauthorized case and a malicious-input case.
- Do not add a dependency unless it is used. Pin exact versions and prefer the latest release.
- Compare secrets with `secrets.compare_digest`, never `==`.
- Keep the code passing `ruff check`, `ruff format --check` and `pytest` (90% coverage gate).
