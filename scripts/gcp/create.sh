#!/usr/bin/env bash
# Phase 11: create Tokyo g2-standard-8 (L4) with no external IP.
# Tries zones a → b → c. Does not go to other regions.
# Billing starts when the instance is RUNNING (~$1.10/h). Stop after the bench.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=env.sh
source "$ROOT/env.sh"

if [[ -n "$(gcp_instance_zone)" ]]; then
  echo "already exists: ${INSTANCE} in $(gcp_instance_zone)" >&2
  exit 1
fi

last_err=""
for zone in "${ZONES[@]}"; do
  echo "try ${INSTANCE} in ${zone}" >&2
  if gcloud compute instances create "$INSTANCE" \
    --project="$PROJECT" \
    --zone="$zone" \
    --machine-type="$MACHINE_TYPE" \
    --maintenance-policy=TERMINATE \
    --boot-disk-size="$BOOT_DISK_GB" \
    --boot-disk-type=pd-balanced \
    --image-family="$IMAGE_FAMILY" \
    --image-project="$IMAGE_PROJECT" \
    --no-address \
    --tags="$NETWORK_TAG"
  then
    echo "created ${INSTANCE} zone=${zone}" >&2
    echo "$zone"
    exit 0
  else
    last_err=$?
    echo "create failed in ${zone} (exit ${last_err})" >&2
  fi
done

echo "all Tokyo zones failed. do not try other regions. last exit=${last_err}" >&2
exit "${last_err:-1}"
