#!/usr/bin/env bash
# Phase 12: IAP SSH local forward. No shell on the VM.
# WSL localhost:${LOCAL_PORT} -> VM 127.0.0.1:${REMOTE_PORT}
#
# Why SSH -L, not `gcloud compute start-iap-tunnel 8080`:
# IAP TCP to 8080 hits the VM NIC. llama-server binds 127.0.0.1, so that miss.
# SSH -L evaluates the dest on the remote, so 127.0.0.1:8080 works.
# Firewall stays tcp:22 from IAP only. Do not open 8080.
#
# Usage:
#   scripts/gcp/tunnel.sh
#   LOCAL_PORT=18080 scripts/gcp/tunnel.sh
# Stop: Ctrl+C. Then stop the VM (scripts/gcp/stop.sh).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=env.sh
source "$ROOT/env.sh"

LOCAL_PORT="${LOCAL_PORT:-8080}"
REMOTE_PORT="${REMOTE_PORT:-8080}"

zone="$(gcp_instance_zone)"
if [[ -z "$zone" ]]; then
  echo "missing instance: ${INSTANCE}" >&2
  exit 1
fi

echo "forward 127.0.0.1:${LOCAL_PORT} -> ${INSTANCE}:127.0.0.1:${REMOTE_PORT} (IAP SSH -N -L)" >&2
echo "open: http://127.0.0.1:${LOCAL_PORT}  (Windows mirrored: same URL)" >&2
echo "stop: Ctrl+C this process, then scripts/gcp/stop.sh" >&2

exec gcloud compute ssh "$INSTANCE" \
  --project="$PROJECT" \
  --zone="$zone" \
  --tunnel-through-iap \
  -- -N -L "${LOCAL_PORT}:127.0.0.1:${REMOTE_PORT}"
