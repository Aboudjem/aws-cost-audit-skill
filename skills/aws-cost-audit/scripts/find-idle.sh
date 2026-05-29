#!/usr/bin/env bash
# find-idle.sh — Read-only finder for common cost-waste candidates in ONE region.
#
# Surfaces (prints a candidates table, deletes NOTHING):
#   - Unassociated Elastic IPs (billed while idle)
#   - Unattached EBS volumes (status=available)
#   - Idle ALBs/NLBs (no listeners) and empty target groups (no registered targets)
#   - CloudWatch log groups with no retention set (never expire)
#   - gp2 EBS volumes (candidates for gp3 migration)
#
# NO mutations. NO --apply. Run inventory-regions.sh first for a wider sweep.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
. "$HERE/_lib.sh"

usage() {
  cat <<'EOF'
Usage: find-idle.sh [--region REGION] [--output DIR]

Read-only. Prints idle/waste candidates for a single region. No deletes.

Options:
  --region REGION  Region to scan. Falls back to $AWS_REGION /
                   $AWS_DEFAULT_REGION / `aws configure get region`.
  --output DIR     If set, also writes a candidates JSON/TSV there.
  -h, --help       Show this help

This script only reads. Confirm any finding is truly idle (check CloudWatch
metrics / owners / dependencies) before acting with the gated scripts.
EOF
}

REGION_ARG=""
OUT_DIR=""
while [ $# -gt 0 ]; do
  case "$1" in
    --region) REGION_ARG="$2"; shift 2;;
    --output) OUT_DIR="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) die "Unknown argument: $1 (see --help)";;
  esac
done

preflight
REGION="$(resolve_region "$REGION_ARG")"
info "Account: $(account_id)"
info "Region:  $REGION"
[ -n "$OUT_DIR" ] && ensure_dir "$OUT_DIR"

section() { printf '\n=== %s ===\n' "$1"; }

# 1) Unassociated EIPs (no AssociationId)
section "Unassociated Elastic IPs (billed while idle)"
aws ec2 describe-addresses --region "$REGION" \
  --query 'Addresses[?AssociationId==`null`].{AllocationId:AllocationId,PublicIp:PublicIp,Domain:Domain}' \
  --output table || warn "describe-addresses failed"

# 2) Unattached EBS volumes (status=available)
section "Unattached EBS volumes (status=available)"
aws ec2 describe-volumes --region "$REGION" \
  --filters Name=status,Values=available \
  --query 'Volumes[].{VolumeId:VolumeId,Type:VolumeType,SizeGiB:Size,AZ:AvailabilityZone,Created:CreateTime}' \
  --output table || warn "describe-volumes failed"

# 3a) Load balancers with NO listeners (likely idle / orphaned)
section "Load balancers with zero listeners (idle candidates)"
LB_LINES="$(aws elbv2 describe-load-balancers --region "$REGION" \
  --query 'LoadBalancers[].[LoadBalancerArn,LoadBalancerName,Type]' \
  --output text 2>/dev/null || true)"
if [ -z "$LB_LINES" ]; then
  echo "(no load balancers)"
else
  printf '%-50s %-20s %s\n' "NAME" "TYPE" "LISTENERS"
  while IFS=$'\t' read -r arn name type; do
    [ -z "$arn" ] && continue
    cnt="$(aws elbv2 describe-listeners --load-balancer-arn "$arn" --region "$REGION" \
            --query 'length(Listeners)' --output text 2>/dev/null || echo "?")"
    if [ "$cnt" = "0" ]; then
      printf '%-50s %-20s %s  <-- IDLE (no listeners)\n' "$name" "$type" "$cnt"
    fi
  done <<< "$LB_LINES"
fi

# 3b) Target groups with NO registered targets
section "Target groups with zero registered targets (empty TGs)"
TG_LINES="$(aws elbv2 describe-target-groups --region "$REGION" \
  --query 'TargetGroups[].[TargetGroupArn,TargetGroupName]' \
  --output text 2>/dev/null || true)"
if [ -z "$TG_LINES" ]; then
  echo "(no target groups)"
else
  while IFS=$'\t' read -r tgarn tgname; do
    [ -z "$tgarn" ] && continue
    n="$(aws elbv2 describe-target-health --target-group-arn "$tgarn" --region "$REGION" \
          --query 'length(TargetHealthDescriptions)' --output text 2>/dev/null || echo "?")"
    if [ "$n" = "0" ]; then
      printf '  EMPTY  %s\n' "$tgname"
    fi
  done <<< "$TG_LINES"
fi

# 4) Log groups with no retention set (retentionInDays absent => never expire)
section "CloudWatch log groups with NO retention (never expire)"
aws logs describe-log-groups --region "$REGION" \
  --query 'logGroups[?retentionInDays==`null`].{LogGroup:logGroupName,StoredBytes:storedBytes}' \
  --output table || warn "describe-log-groups failed"

# 5) gp2 volumes (gp3 migration candidates — usually cheaper + faster)
section "gp2 EBS volumes (candidates for gp3 migration)"
aws ec2 describe-volumes --region "$REGION" \
  --filters Name=volume-type,Values=gp2 \
  --query 'Volumes[].{VolumeId:VolumeId,SizeGiB:Size,State:State,AZ:AvailabilityZone}' \
  --output table || warn "describe-volumes (gp2) failed"

# Optional machine-readable export
if [ -n "$OUT_DIR" ]; then
  info "Writing JSON candidate dumps to $OUT_DIR ..."
  aws ec2 describe-addresses --region "$REGION" \
    --query 'Addresses[?AssociationId==`null`]' --output json > "$OUT_DIR/idle-eips.json" 2>/dev/null || true
  aws ec2 describe-volumes --region "$REGION" --filters Name=status,Values=available \
    --output json > "$OUT_DIR/idle-volumes.json" 2>/dev/null || true
  aws ec2 describe-volumes --region "$REGION" --filters Name=volume-type,Values=gp2 \
    --output json > "$OUT_DIR/gp2-volumes.json" 2>/dev/null || true
  aws logs describe-log-groups --region "$REGION" \
    --query 'logGroups[?retentionInDays==`null`]' --output json > "$OUT_DIR/logs-never-expire.json" 2>/dev/null || true
fi

printf '\nNote: these are CANDIDATES only. Verify each is truly idle (metrics, owners,\n'
printf 'dependencies) before using the gated scripts to act. Nothing was changed.\n'
