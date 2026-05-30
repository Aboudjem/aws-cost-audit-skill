#!/usr/bin/env bash
# delete-unattached-ebs.sh: Gated deletion of an unattached EBS volume.
#
# SAFETY ORDER OF OPERATIONS:
#   1. Require the volume status to be 'available' (i.e. NOT attached).
#   2. Take a snapshot FIRST and wait for it to complete (the rollback path).
#   3. Save a rollback artifact (volume metadata + snapshot id).
#   4. Only then, on --apply AND explicit confirmation, delete the volume.
#
# Default is DRY-RUN. Deleting a volume is destructive; the snapshot is your
# restore point (create a new volume from the snapshot to recover).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
. "$HERE/_lib.sh"

usage() {
  cat <<'EOF'
Usage: delete-unattached-ebs.sh --volume-id vol-XXXX [--region REGION]
            [--output DIR] [--no-snapshot] [--apply] [--yes]

Deletes an UNATTACHED EBS volume after snapshotting it. DRY-RUN unless --apply.

Required:
  --volume-id ID    EBS volume id. Must have status 'available' (unattached).

Options:
  --region REGION   Region (else $AWS_REGION / config).
  --output DIR      Rollback artifact dir (default ./cost-audit-out or $OUT_DIR).
  --no-snapshot     Skip the safety snapshot (NOT recommended; refused unless
                    combined with --apply and --yes).
  --apply           Actually snapshot + delete (omit for dry-run).
  --yes             Skip interactive confirm.
  -h, --help        Show this help

Rollback: by default a snapshot is taken before deletion and its id recorded in
the rollback artifact. Recover with:
  aws ec2 create-volume --snapshot-id snap-XXXX --availability-zone AZ --region REGION
EOF
}

VOL_ID=""
REGION_ARG=""
OUT_DIR="$(default_out_dir)"
NO_SNAPSHOT=0
APPLY=0
ASSUME_YES=0

while [ $# -gt 0 ]; do
  case "$1" in
    --volume-id) VOL_ID="$2"; shift 2;;
    --region) REGION_ARG="$2"; shift 2;;
    --output) OUT_DIR="$2"; shift 2;;
    --no-snapshot) NO_SNAPSHOT=1; shift;;
    --apply) APPLY=1; shift;;
    --yes) ASSUME_YES=1; shift;;
    -h|--help) usage; exit 0;;
    *) die "Unknown argument: $1 (see --help)";;
  esac
done

[ -n "$VOL_ID" ] || die "--volume-id is required (see --help)"

preflight
REGION="$(resolve_region "$REGION_ARG")"
ensure_dir "$OUT_DIR"
mutate_banner
info "Region: $REGION  Volume: $VOL_ID"

# Inspect the volume.
VOL_JSON="$(aws ec2 describe-volumes --volume-ids "$VOL_ID" --region "$REGION" \
  --query 'Volumes[0].{id:VolumeId,state:State,size:Size,az:AvailabilityZone,type:VolumeType,attachments:Attachments}' \
  --output json)" || die "Volume $VOL_ID not found in $REGION."
echo "$VOL_JSON"

STATE="$(printf '%s' "$VOL_JSON" | { command -v jq >/dev/null 2>&1 && jq -r '.state' || sed -n 's/.*"state": *"\([^"]*\)".*/\1/p'; })"
AZ="$(printf '%s' "$VOL_JSON" | { command -v jq >/dev/null 2>&1 && jq -r '.az' || sed -n 's/.*"az": *"\([^"]*\)".*/\1/p'; })"

# HARD GATE: must be unattached.
if [ "$STATE" != "available" ]; then
  die "Refusing: volume state is '$STATE', expected 'available' (unattached). This script will not touch attached volumes."
fi

# Save rollback metadata BEFORE any mutation.
TS="$(date -u +%Y%m%dT%H%M%SZ)"
ROLLBACK="$OUT_DIR/rollback-ebs-delete-${VOL_ID}-${TS}.json"

if [ "$APPLY" != "1" ]; then
  printf '%s\n' "$VOL_JSON" > "$ROLLBACK"
  info "Rollback metadata saved: $ROLLBACK"
  echo "DRY-RUN plan:"
  if [ "$NO_SNAPSHOT" = "1" ]; then
    echo "  (--no-snapshot set) would SKIP snapshot"
  else
    echo "  1) aws ec2 create-snapshot --volume-id $VOL_ID --region $REGION (wait for completed)"
  fi
  echo "  2) aws ec2 delete-volume --volume-id $VOL_ID --region $REGION"
  info "DRY-RUN complete. Re-run with --apply to execute."
  exit 0
fi

# --apply path.
SNAP_ID="(skipped)"
if [ "$NO_SNAPSHOT" = "1" ]; then
  warn "--no-snapshot set: NO restore point will exist after deletion."
  confirm "Delete $VOL_ID WITHOUT a snapshot (unrecoverable)?"
else
  info "Creating safety snapshot first..."
  SNAP_ID="$(aws ec2 create-snapshot --volume-id "$VOL_ID" --region "$REGION" \
    --description "pre-delete safety snapshot of $VOL_ID ($TS)" \
    --query 'SnapshotId' --output text)"
  info "Snapshot started: $SNAP_ID, waiting for completion..."
  aws ec2 wait snapshot-completed --snapshot-ids "$SNAP_ID" --region "$REGION"
  info "Snapshot $SNAP_ID completed."
fi

# Write rollback artifact (now including snapshot id).
{
  echo "{"
  echo "  \"region\": \"$REGION\","
  echo "  \"volumeId\": \"$VOL_ID\","
  echo "  \"availabilityZone\": \"$AZ\","
  echo "  \"snapshotId\": \"$SNAP_ID\","
  echo "  \"capturedAt\": \"$(_ts)\","
  echo "  \"volume\": $VOL_JSON"
  echo "}"
} > "$ROLLBACK"
info "Rollback artifact saved: $ROLLBACK"

confirm "Delete EBS volume $VOL_ID in ${REGION}? (snapshot: $SNAP_ID)"
aws ec2 delete-volume --volume-id "$VOL_ID" --region "$REGION"
info "DONE. Volume $VOL_ID deleted."
[ "$SNAP_ID" != "(skipped)" ] && info "Recover with: aws ec2 create-volume --snapshot-id $SNAP_ID --availability-zone $AZ --region $REGION"
info "Rollback data in $ROLLBACK"
