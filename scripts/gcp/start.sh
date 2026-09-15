#!/usr/bin/env bash
# Phase 12: start a stopped l4-27b. Does not create a new VM.
# Billing resumes while RUNNING (~$1.10/h). Stop after the session.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=env.sh
source "$ROOT/env.sh"

zone="$(gcp_instance_zone)"
if [[ -z "$zone" ]]; then
  echo "missing instance: ${INSTANCE}. create first (scripts/gcp/create.sh)." >&2
  exit 1
fi

status="$(gcloud compute instances describe "$INSTANCE" \
  --project="$PROJECT" --zone="$zone" --format='value(status)')"

case "$status" in
  RUNNING)
    echo "already RUNNING: ${INSTANCE} zone=${zone}" >&2
    ;;
  STOPPING)
    echo "still STOPPING: ${INSTANCE}. wait, then rerun." >&2
    exit 1
    ;;
  STAGING|PROVISIONING)
    echo "already coming up: ${INSTANCE} status=${status}" >&2
    ;;
  TERMINATED|SUSPENDED)
    gcloud compute instances start "$INSTANCE" --project="$PROJECT" --zone="$zone"
    ;;
  *)
    echo "unexpected status=${status} for ${INSTANCE}. do not start." >&2
    exit 1
    ;;
esac

gcloud compute instances describe "$INSTANCE" \
  --project="$PROJECT" --zone="$zone" --format='yaml(status,zone)'
