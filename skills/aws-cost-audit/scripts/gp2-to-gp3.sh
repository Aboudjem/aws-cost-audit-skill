#!/usr/bin/env bash
# gp2-to-gp3.sh: Gated EBS gp2 -> gp3 conversion via modify-volume.
#
# gp3 is typically cheaper per GB than gp2 and decouples IOPS/throughput from
# size. The migration is online (no detach) and reversible (modify back to gp2).
# Default is DRY-RUN. Saves the volume's current type/IOPS/throughput as a
# rollback artifact before any change.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
. "$HERE/_lib.sh"

usage() {
  cat <<'EOF'
Usage: gp2-to-gp3.sh --volume-id vol-XXXX [--region REGION] [--iops N]
                     [--throughput N] [--output DIR] [--apply] [--yes]

Converts a gp2 EBS volume to gp3. DRY-RUN unless --apply. Reversible.

Required:
  --volume-id ID    The EBS volume id (e.g. vol-0abc...).

Options:
  --region REGION   Region (else $AWS_REGION / config).
  --iops N          Provisioned IOPS for gp3 (gp3 default is 3000 if omitted).
  --throughput N    Throughput MiB/s for gp3 (gp3 default is 125 if omitted).
  --output DIR      Rollback artifact dir (default ./cost-audit-out or $OUT_DIR).
  --apply           Actually modify the volume (omit for dry-run).
  --yes             Skip interactive confirm.
  -h, --help        Show this help

Rollback: the volume's prior VolumeType/Iops/Throughput is saved to a JSON
artifact. To revert: 'aws ec2 modify-volume --volume-id ID --volume-type gp2'.
A volume can only be modified once every 6 hours.
EOF
}

VOL_ID=""
REGION_ARG=""
IOPS=""
THROUGHPUT=""
OUT_DIR="$(default_out_dir)"
APPLY=0
ASSUME_YES=0

while [ $# -gt 0 ]; do
  case "$1" in
    --volume-id) VOL_ID="$2"; shift 2;;
    --region) REGION_ARG="$2"; shift 2;;
    --iops) IOPS="$2"; shift 2;;
    --throughput) THROUGHPUT="$2"; shift 2;;
    --output) OUT_DIR="$2"; shift 2;;
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

# Inspect current state.
CUR_JSON="$(aws ec2 describe-volumes --volume-ids "$VOL_ID" --region "$REGION" \
  --query 'Volumes[0].{type:VolumeType,size:Size,iops:Iops,throughput:Throughput,state:State}' \
  --output json)" || die "Volume $VOL_ID not found in $REGION."

CUR_TYPE="$(printf '%s' "$CUR_JSON" | { command -v jq >/dev/null 2>&1 && jq -r '.type' || sed -n 's/.*"type": *"\([^"]*\)".*/\1/p'; })"
info "Current type: $CUR_TYPE"
echo "$CUR_JSON"

if [ "$CUR_TYPE" = "gp3" ]; then
  info "Volume is already gp3. Nothing to do."
  exit 0
fi
if [ "$CUR_TYPE" != "gp2" ]; then
  warn "Volume type is '$CUR_TYPE', not gp2. Proceeding will still set it to gp3, review carefully."
fi

# Save rollback BEFORE mutating.
ROLLBACK="$OUT_DIR/rollback-gp2-to-gp3-${VOL_ID}-$(date -u +%Y%m%dT%H%M%SZ).json"
printf '%s\n' "$CUR_JSON" | save_rollback "$OUT_DIR" "$(basename "$ROLLBACK")" >/dev/null
info "Rollback artifact saved: $ROLLBACK"

# Build modify args.
MODIFY_ARGS=( ec2 modify-volume --volume-id "$VOL_ID" --volume-type gp3 --region "$REGION" )
[ -n "$IOPS" ]       && MODIFY_ARGS+=( --iops "$IOPS" )
[ -n "$THROUGHPUT" ] && MODIFY_ARGS+=( --throughput "$THROUGHPUT" )

if [ "$APPLY" != "1" ]; then
  echo "DRY-RUN would: aws ${MODIFY_ARGS[*]}"
  info "DRY-RUN complete. Re-run with --apply to convert."
  exit 0
fi

confirm "Convert $VOL_ID ($CUR_TYPE -> gp3) in ${REGION}?"
aws "${MODIFY_ARGS[@]}"
info "Modify requested. Track progress with:"
info "  aws ec2 describe-volumes-modifications --volume-ids $VOL_ID --region $REGION"
info "Rollback data in $ROLLBACK (revert with --volume-type gp2)."
