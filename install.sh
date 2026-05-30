#!/usr/bin/env bash
#
# AWS Cost Audit multi-CLI installer.
#
# Symlinks the aws-cost-audit skill into a target AI coding CLI's skills
# directory so it is available in that CLI. This is a skill-only plugin: there
# is no MCP server. The skill shells out to the AWS CLI (read-only by default)
# and runs inside whichever CLI loads it.
#
# Usage:
#   ./install.sh <platform> [--update | --uninstall]
#   curl -fsSL https://raw.githubusercontent.com/Aboudjem/aws-cost-audit-skill/main/install.sh | bash -s <platform>
#
# Platforms: gemini codex opencode pi vibe vscode copilot trae
#            openclaw antigravity hermes cline kimi   (or: all)
#
# Skill-directory conventions change between CLI releases. The table below is
# mirrored from the Sniff installer; verify your CLI's current skills path if a
# link does not resolve.
#
set -euo pipefail

REPO_URL="https://github.com/Aboudjem/aws-cost-audit-skill.git"
CLONE_DIR="${AWS_COST_AUDIT_HOME:-$HOME/.aws-cost-audit}"
SKILLS=(aws-cost-audit)
ALL_IDS=(gemini codex opencode pi vibe vscode copilot trae openclaw antigravity hermes cline kimi)

c_red=""; c_grn=""; c_rst=""
if [ -t 1 ]; then
  c_red="$(printf '\033[31m')"; c_grn="$(printf '\033[32m')"
  c_rst="$(printf '\033[0m')"
fi
info() { printf '%s\n' "$*"; }
ok()   { printf '%s%s%s\n' "$c_grn" "$*" "$c_rst"; }
warn() { printf '%s%s%s\n' "$c_red" "$*" "$c_rst" >&2; }

usage() {
  cat <<EOF
AWS Cost Audit installer

Usage:
  install.sh <platform> [--update | --uninstall]
  curl -fsSL https://raw.githubusercontent.com/Aboudjem/aws-cost-audit-skill/main/install.sh | bash -s <platform>

Platforms:
  ${ALL_IDS[*]}
  all   apply to every platform above

Options:
  --update     pull the latest skill and relink
  --uninstall  remove the symlinks for <platform>
  -h, --help   show this help

This is a skill-only plugin (no MCP server). It requires the AWS CLI configured
with read access to the account you want to audit (ReadOnlyAccess is enough).
EOF
}

# platform_target <id> -> "dir|style" on stdout (empty if unknown).
platform_target() {
  case "$1" in
    gemini|codex|opencode|pi) printf '%s\n' "$HOME/.agents/skills|per-skill" ;;
    vibe)           printf '%s\n' "$HOME/.vibe/skills|per-skill" ;;
    vscode|copilot) printf '%s\n' "$HOME/.copilot/skills|per-skill" ;;
    trae)           printf '%s\n' "$HOME/.trae/skills|per-skill" ;;
    openclaw)       printf '%s\n' "$HOME/.openclaw/skills|folder" ;;
    antigravity)    printf '%s\n' "$HOME/.gemini/antigravity/skills|folder" ;;
    hermes)         printf '%s\n' "$HOME/.hermes/skills|folder" ;;
    cline)          printf '%s\n' "$HOME/.cline/skills|folder" ;;
    kimi)           printf '%s\n' "$HOME/.kimi/skills|folder" ;;
    *)              printf '%s\n' "" ;;
  esac
}

# Use a local checkout (script next to skills/) or clone/refresh one.
resolve_root() {
  local src dir
  src="${BASH_SOURCE[0]:-}"
  if [ -n "$src" ] && [ -f "$src" ]; then
    dir="$(cd "$(dirname "$src")" && pwd)"
    if [ -d "$dir/skills" ]; then
      printf '%s\n' "$dir"
      return 0
    fi
  fi
  if [ -d "$CLONE_DIR/.git" ]; then
    git -C "$CLONE_DIR" pull --ff-only --quiet >/dev/null 2>&1 || true
  else
    command -v git >/dev/null 2>&1 || { warn "git is required to install from a pipe."; exit 1; }
    git clone --depth 1 "$REPO_URL" "$CLONE_DIR" >/dev/null 2>&1
  fi
  printf '%s\n' "$CLONE_DIR"
}

link_one() {
  local root="$1" target="$2" style="$3" s
  mkdir -p "$target"
  if [ "$style" = "folder" ]; then
    ln -sfn "$root/skills/aws-cost-audit" "$target/aws-cost-audit"
    ok "linked $target/aws-cost-audit -> $root/skills/aws-cost-audit"
  else
    for s in "${SKILLS[@]}"; do
      ln -sfn "$root/skills/$s" "$target/$s"
      ok "linked $target/$s -> $root/skills/$s"
    done
  fi
}

unlink_one() {
  local target="$1" style="$2" s
  if [ "$style" = "folder" ]; then
    rm -f "$target/aws-cost-audit"
    info "removed $target/aws-cost-audit"
  else
    for s in "${SKILLS[@]}"; do
      rm -f "$target/$s"
      info "removed $target/$s"
    done
  fi
}

main() {
  local platform="" action="install" arg
  for arg in "$@"; do
    case "$arg" in
      --update)    action="update" ;;
      --uninstall) action="uninstall" ;;
      -h|--help)   usage; exit 0 ;;
      -*)          warn "unknown option: $arg"; usage; exit 1 ;;
      *)           platform="$arg" ;;
    esac
  done

  if [ -z "$platform" ]; then
    usage
    exit 1
  fi

  local ids=()
  if [ "$platform" = "all" ]; then
    ids=("${ALL_IDS[@]}")
  else
    ids=("$platform")
  fi

  local root=""
  if [ "$action" != "uninstall" ]; then
    root="$(resolve_root)"
    info "aws-cost-audit checkout: $root"
  fi

  local id spec dir style
  for id in "${ids[@]}"; do
    spec="$(platform_target "$id")"
    if [ -z "$spec" ]; then
      warn "unknown platform: $id (run --help for the list)."
      continue
    fi
    dir="${spec%%|*}"; style="${spec##*|}"
    case "$action" in
      install|update) link_one "$root" "$dir" "$style" ;;
      uninstall)      unlink_one "$dir" "$style" ;;
    esac
  done
}

main "$@"
