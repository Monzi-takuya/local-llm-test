#!/usr/bin/env bash
# Phase 11: delete l4-27b AND its boot disk. Do not run unless a person asked.
# One-shot verification keeps the disk; this is for later teardown.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=env.sh
source "$ROOT/env.sh"

zone="$(gcp_instance_zone)"
if [[ -z "$zone" ]]; then
  echo "missing instance: ${INSTANCE}" >&2
  exit 1
fi

if [[ "${I_MEAN_DELETE:-}" != "yes" ]]; then
  echo "refusing delete. set I_MEAN_DELETE=yes if a person asked to destroy ${INSTANCE}." >&2
  exit 2
fi

gcloud compute instances delete "$INSTANCE" \
  --project="$PROJECT" --zone="$zone" --delete-disks=all --quiet
