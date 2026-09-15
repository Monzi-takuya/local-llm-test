#!/usr/bin/env bash
# Phase 11: stop l4-27b. Keeps the boot disk (GGUF). Does not delete.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=env.sh
source "$ROOT/env.sh"

zone="$(gcp_instance_zone)"
if [[ -z "$zone" ]]; then
  echo "missing instance: ${INSTANCE}" >&2
  exit 1
fi

gcloud compute instances stop "$INSTANCE" --project="$PROJECT" --zone="$zone"
gcloud compute instances describe "$INSTANCE" \
  --project="$PROJECT" --zone="$zone" --format='yaml(status,zone)'
