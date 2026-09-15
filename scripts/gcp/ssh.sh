#!/usr/bin/env bash
# Phase 11: IAP SSH into l4-27b (no external IP).
# Extra args go to ssh. Example: scripts/gcp/ssh.sh -- -L 8080:127.0.0.1:8080
# Or a remote command: scripts/gcp/ssh.sh --command='nvidia-smi'

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=env.sh
source "$ROOT/env.sh"

zone="$(gcp_instance_zone)"
if [[ -z "$zone" ]]; then
  echo "missing instance: ${INSTANCE}" >&2
  exit 1
fi

exec gcloud compute ssh "$INSTANCE" \
  --project="$PROJECT" \
  --zone="$zone" \
  --tunnel-through-iap \
  "$@"
