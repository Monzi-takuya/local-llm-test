# Shared defaults for phase 11 GCP scripts. Source from the other scripts.
# Project is always passed explicitly so Cloud Run 本番と取り違えない。

PROJECT="${PROJECT:-monzi-sandbox}"
INSTANCE="${INSTANCE:-l4-27b}"
REGION="${REGION:-asia-northeast1}"
# G2 は機種に L4 が付く。--accelerator は vWS 用なので付けない。
MACHINE_TYPE="${MACHINE_TYPE:-g2-standard-8}"
IMAGE_FAMILY="${IMAGE_FAMILY:-common-cu129-ubuntu-2204-nvidia-580}"
IMAGE_PROJECT="${IMAGE_PROJECT:-deeplearning-platform-release}"
BOOT_DISK_GB="${BOOT_DISK_GB:-100}"
NETWORK_TAG="${NETWORK_TAG:-allow-iap-ssh}"
ZONES=(
  asia-northeast1-a
  asia-northeast1-b
  asia-northeast1-c
)

# Resolve zone of an existing instance (empty if missing).
gcp_instance_zone() {
  gcloud compute instances list \
    --project="$PROJECT" \
    --filter="name=${INSTANCE}" \
    --format='value(zone)'
}
