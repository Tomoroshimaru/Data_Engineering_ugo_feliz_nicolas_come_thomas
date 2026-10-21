#!/usr/bin/env bash
# Usage (from anywhere): source scriptes/starter.sh
# Must be sourced, not executed, so the variables stay in your terminal.

ENV_FILE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "Missing $ENV_FILE: copy .env.example to .env and fill it in."
  unset ENV_FILE
  return 1 2>/dev/null || exit 1
fi

# Export every variable defined in .env
set -a
. "$ENV_FILE"
set +a
unset ENV_FILE

# Log in only if no account is active yet
if [ -z "$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null)" ]; then
  gcloud auth login
fi

if [ -n "$GCP_PROJECT_ID" ]; then
  gcloud config set project "$GCP_PROJECT_ID"
fi
