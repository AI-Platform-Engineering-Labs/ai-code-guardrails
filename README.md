# vibe-to-prod

Demo repo for the CNCG talk **“From Vibe Coding to Production: Guardrails for AI-Written Code”** (21 Nov 2026).

An AI assistant can write a feature in 30 seconds. This repo shows the guardrails that decide whether that code reaches production: every pull request runs lint, tests with a coverage gate, secret scanning, dependency checks and CodeQL, needs a code-owner review, and every deploy to Azure App Service waits for a human approval and a smoke test.

```
app/                 orders-api (FastAPI + SQLite) and its tests
.github/workflows/   guardrails.yml (lint, tests, secrets, dependencies), codeql.yml, deploy.yml
.github/             copilot-instructions.md, PR template with AI disclosure, CODEOWNERS, dependabot.yml
scripts/             setup-repo.sh (once), sandbox-up.sh / sandbox-down.sh (each KodeKloud session),
                     make-vibe-pr.sh (the bad PR), make-fixed-pr.sh (the good PR)
```

## The guardrails

| Layer | Guardrail | Catches in the demo |
| --- | --- | --- |
| Before you type | `copilot-instructions.md` | Steers Copilot away from the mistakes below |
| On push | Secret scanning push protection | Real provider keys (GitHub, Azure, AWS…) |
| On every PR | `lint`: ruff with bandit rules | Hardcoded token, f-string SQL, unused import |
| | `tests`: pytest, 90% coverage gate | Feature shipped with no tests |
| | `secrets`: gitleaks | Hardcoded token |
| | `dependencies`: dependency review + pip-audit | `requests==2.31.0` with known CVEs |
| | CodeQL (security-extended) | SQL injection |
| | Ruleset: code-owner review, all checks green | Merging around the checks |
| On deploy | `production` environment approval + smoke test | Shipping without a human, or shipping a broken app |

## One-time setup (about 10 minutes)

1. Create a **public** repo named `vibe-to-prod` on GitHub (public = CodeQL, secret scanning and dependency review are free).
2. Push this folder to it:
   ```bash
   git init -b main && git add . && git commit -m "Initial commit"
   git remote add origin https://github.com/<you>/vibe-to-prod.git && git push -u origin main
   ```
3. `scripts/setup-repo.sh <you>/vibe-to-prod`
4. Wait for the first `guardrails` and `codeql` runs on main to go green (CodeQL needs a baseline on main).

## Each KodeKloud Azure playground session (about 3 minutes)

The playground gives you one resource group and a service principal with a client secret, and recycles everything when the session ends. It does not allow role assignments or federated credentials, so the deploy uses a client secret stored as a GitHub **environment** secret (OIDC is the better choice on a real subscription).

```bash
export ARM_CLIENT_ID=... ARM_CLIENT_SECRET=... ARM_TENANT_ID=... ARM_SUBSCRIPTION_ID=... RESOURCE_GROUP=kml_rg_main_...
scripts/sandbox-up.sh <you>/vibe-to-prod
gh workflow run deploy -R <you>/vibe-to-prod   # approve it in the Actions tab
```
After the session: `scripts/sandbox-down.sh <you>/vibe-to-prod`.

## Run of show (7 minutes on stage)

| When | Action |
| --- | --- |
| T-60 min | Start the playground, run `sandbox-up.sh`, deploy main once, open the app URL |
| T-45 min | `scripts/make-vibe-pr.sh` then `scripts/make-fixed-pr.sh` (CodeQL takes a few minutes) |
| 1. The vibe (1 min) | In VS Code, ask Copilot Chat for “an endpoint to search orders by item name”. Show how fast it is. Then open the prepared **vibe PR**: “this is what that looks like when nobody checks it”. |
| 2. Red checks (2 min) | Walk the failures: gitleaks finds the token, CodeQL flags SQL injection, dependency review flags `requests` CVEs, ruff flags 4 issues, coverage 88.9% < 90%. Merge button is blocked. |
| 3. The fix (2 min) | On the CodeQL alert, show **Copilot Autofix**’s suggested patch. Open the **fixed PR**: all green, tests include an injection attempt. |
| 4. Gated deploy (2 min) | Merge (admin bypass for the review, say why), approve the `production` deployment, show the smoke test pass and call `/orders/search` with the token header. |

## Fallbacks

- CodeQL slow: both PRs are opened 45 minutes early, so results are already there.
- Sandbox expired mid-talk: show the last successful deploy run and its URL screenshot.
- No network: the recorded rehearsal linked from the last slide.
