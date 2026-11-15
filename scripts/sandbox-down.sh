#!/usr/bin/env bash
# After a session: remove the sandbox credentials from GitHub.
# (KodeKloud recycles the Azure resources itself.)
set -euo pipefail
REPO="${1:?usage: sandbox-down.sh <owner/repo>}"
gh secret delete AZURE_CREDENTIALS -R "$REPO" --env production || true
echo "Sandbox credentials removed from $REPO."
