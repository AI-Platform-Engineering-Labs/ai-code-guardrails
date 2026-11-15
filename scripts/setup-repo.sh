#!/usr/bin/env bash
# One-time GitHub setup: turns repo settings into guardrails.
# Usage: scripts/setup-repo.sh <owner/repo>   (needs: gh auth login, repo admin)
set -euo pipefail
REPO="${1:?usage: setup-repo.sh <owner/repo>}"
OWNER_LOGIN="$(gh api user --jq .login)"
OWNER_ID="$(gh api user --jq .id)"

echo "1/5 Secret scanning + push protection (on by default for public repos; enforced here)"
gh api -X PATCH "repos/$REPO" --input - >/dev/null <<JSON || echo "   (skipped: set it in Settings > Code security)"
{"security_and_analysis": {"secret_scanning": {"status": "enabled"},
 "secret_scanning_push_protection": {"status": "enabled"}}}
JSON

echo "2/5 Dependabot alerts"
gh api -X PUT "repos/$REPO/vulnerability-alerts" >/dev/null

echo "3/5 CODEOWNERS -> @$OWNER_LOGIN"
sed -i.bak "s/@OWNER/@$OWNER_LOGIN/" .github/CODEOWNERS && rm .github/CODEOWNERS.bak
git add .github/CODEOWNERS && git commit -m "Set code owner" && git push || true

echo "4/5 'production' environment: deploys wait for your approval"
gh api -X PUT "repos/$REPO/environments/production" --input - >/dev/null <<JSON
{"reviewers": [{"type": "User", "id": $OWNER_ID}], "prevent_self_review": false,
 "deployment_branch_policy": {"protected_branches": true, "custom_branch_policies": false}}
JSON

echo "5/5 Ruleset on main: PR + review + all guardrail checks + no new high CodeQL alerts"
# Repo admins may bypass, but only through a pull request. You are a solo
# maintainer, so on stage you merge with "bypass" and say so out loud. With a
# second account (a friend or co-organiser) as collaborator, remove the bypass.
gh api -X POST "repos/$REPO/rulesets" --input - >/dev/null <<'JSON'
{
  "name": "main-guardrails",
  "target": "branch",
  "enforcement": "active",
  "conditions": {"ref_name": {"include": ["~DEFAULT_BRANCH"], "exclude": []}},
  "bypass_actors": [{"actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "pull_request"}],
  "rules": [
    {"type": "deletion"},
    {"type": "non_fast_forward"},
    {"type": "pull_request", "parameters": {
      "required_approving_review_count": 1,
      "require_code_owner_review": true,
      "dismiss_stale_reviews_on_push": true,
      "require_last_push_approval": false,
      "required_review_thread_resolution": true}},
    {"type": "required_status_checks", "parameters": {
      "strict_required_status_checks_policy": false,
      "required_status_checks": [
        {"context": "lint"}, {"context": "tests"},
        {"context": "secrets"}, {"context": "dependencies"}]}},
    {"type": "code_scanning", "parameters": {"code_scanning_tools": [
      {"tool": "CodeQL", "security_alerts_threshold": "high_or_higher", "alerts_threshold": "errors"}]}}
  ]
}
JSON
echo "Done. Check Settings > Rules > Rulesets and Settings > Environments."
