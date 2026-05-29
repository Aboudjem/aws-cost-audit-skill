#!/usr/bin/env bash
# inventory-regions.sh — Read-only multi-region inventory hunt.
#
# Loops over every region returned by `aws ec2 describe-regions` (or a
# --regions subset) and runs a battery of read-only describe-*/list-* calls,
# saving JSON per region+resource into the output dir. This is the "hunt list"
# that feeds find-idle.sh and a human review.
#
# NO mutations. NO --apply. NO hardcoded account/region.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
. "$HERE/_lib.sh"

usage() {
  cat <<'EOF'
Usage: inventory-regions.sh [--output DIR] [--regions "r1 r2 ..."] [--all-opted-in]

Read-only. Enumerates regions and dumps a per-region resource inventory.

Options:
  --output DIR     Output directory (default: ./cost-audit-out or $OUT_DIR)
  --regions "..."  Space-separated region list to scan (default: all from
                   describe-regions). Quote the list.
  --all-opted-in   Include opt-in regions that are not yet enabled
                   (--all-regions on describe-regions). Default: enabled only.
  -h, --help       Show this help

Per region it captures (read-only):
  EC2 instances, EBS volumes, EBS snapshots (self-owned), unused EIPs,
  ALB/NLB load balancers, target groups, NAT gateways, RDS instances,
  RDS manual snapshots, ElastiCache clusters, CloudWatch log groups.
EOF
}

OUT_DIR="$(default_out_dir)"
REGIONS_ARG=""
ALL_REGIONS_FLAG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --output) OUT_DIR="$2"; shift 2;;
    --regions) REGIONS_ARG="$2"; shift 2;;
    --all-opted-in) ALL_REGIONS_FLAG="--all-regions"; shift;;
    -h|--help) usage; exit 0;;
    *) die "Unknown argument: $1 (see --help)";;
  esac
done

preflight
ensure_dir "$OUT_DIR"

# Discover regions unless caller supplied them. describe-regions needs *some*
# region to call against; use the resolved region purely as the API endpoint.
if [ -n "$REGIONS_ARG" ]; then
  REGIONS="$REGIONS_ARG"
else
  EP_REGION="$(resolve_region "")"
  info "Discovering regions via describe-regions (endpoint: $EP_REGION)..."
  # shellcheck disable=SC2086
  REGIONS="$(aws ec2 describe-regions $ALL_REGIONS_FLAG --region "$EP_REGION" \
              --query 'Regions[].RegionName' --output text)"
fi

[ -n "$REGIONS" ] || die "No regions to scan."
info "Account:    $(account_id)"
info "Output dir: $OUT_DIR"
info "Regions:    $REGIONS"

# Save a query's JSON, tolerating per-service failures (e.g. service not
# available in a region) without aborting the whole run.
dump() {
  local region="$1" name="$2"; shift 2
  local dir="$OUT_DIR/inventory/$region"
  ensure_dir "$dir"
  local out="$dir/${name}.json"
  if aws "$@" --region "$region" --output json > "$out" 2>"$out.err"; then
    rm -f "$out.err"
  else
    warn "  [$region] $name failed (service may be unavailable here) — see $out.err"
  fi
}

for R in $REGIONS; do
  info "=== Region: $R ==="

  dump "$R" ec2-instances ec2 describe-instances \
    --query 'Reservations[].Instances[].{id:InstanceId,type:InstanceType,state:State.Name,launch:LaunchTime}'

  dump "$R" ebs-volumes ec2 describe-volumes \
    --query 'Volumes[].{id:VolumeId,type:VolumeType,size:Size,state:State,attachments:Attachments[].InstanceId}'

  dump "$R" ebs-snapshots ec2 describe-snapshots --owner-ids self \
    --query 'Snapshots[].{id:SnapshotId,volume:VolumeId,size:VolumeSize,start:StartTime}'

  dump "$R" eips ec2 describe-addresses \
    --query 'Addresses[].{alloc:AllocationId,ip:PublicIp,assoc:AssociationId,instance:InstanceId}'

  dump "$R" load-balancers elbv2 describe-load-balancers \
    --query 'LoadBalancers[].{arn:LoadBalancerArn,name:LoadBalancerName,type:Type,state:State.Code,created:CreatedTime}'

  dump "$R" target-groups elbv2 describe-target-groups \
    --query 'TargetGroups[].{arn:TargetGroupArn,name:TargetGroupName,proto:Protocol,lbs:LoadBalancerArns}'

  dump "$R" nat-gateways ec2 describe-nat-gateways \
    --query 'NatGateways[].{id:NatGatewayId,state:State,vpc:VpcId,subnet:SubnetId}'

  dump "$R" rds-instances rds describe-db-instances \
    --query 'DBInstances[].{id:DBInstanceIdentifier,class:DBInstanceClass,engine:Engine,status:DBInstanceStatus,storage:AllocatedStorage}'

  dump "$R" rds-snapshots rds describe-db-snapshots --snapshot-type manual \
    --query 'DBSnapshots[].{id:DBSnapshotIdentifier,size:AllocatedStorage,created:SnapshotCreateTime}'

  dump "$R" elasticache elasticache describe-cache-clusters \
    --query 'CacheClusters[].{id:CacheClusterId,node:CacheNodeType,engine:Engine,status:CacheClusterStatus}'

  dump "$R" log-groups logs describe-log-groups \
    --query 'logGroups[].{name:logGroupName,retentionDays:retentionInDays,storedBytes:storedBytes}'
done

info "Done. Inventory under: $OUT_DIR/inventory/<region>/"
