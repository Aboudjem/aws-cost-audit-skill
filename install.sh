#!/usr/bin/env bash
#
# AWS Cost Audit multi-CLI installer.
#
# Installs the aws-cost-audit skill into a target AI coding CLI. This is a
# skill-only plugin: there is no MCP server. The skill shells out to the AWS CLI
# (read-only by default) and runs inside whichever CLI loads it.
#
# By default this delegates to the Vercel skills CLI, which knows the current
# skills directory for every agent it supports and keeps up as those move:
#
#   npx --yes skills@<pinned> add Aboudjem/aws-cost-audit-skill -a <agent> -g -y
#
# Pass --legacy to use the original symlink logic instead, which needs no npx
# and no network beyond the git clone. It is also the automatic fallback when
# npx is not on PATH.
#
# Usage:
#   ./install.sh <platform> [--update | --uninstall] [--legacy] [--project]
#   curl -fsSL https://raw.githubusercontent.com/Aboudjem/aws-cost-audit-skill/main/install.sh | bash -s <platform>
#
# Platforms: gemini codex opencode pi vibe vscode copilot trae
#            openclaw antigravity hermes cline kimi   (or: all)
#
# Skill-directory conventions change between CLI releases. The legacy table
# below is a snapshot; verify your CLI's current skills path if a link does not
# resolve, or use the default path, which asks the skills CLI instead.
#
set -euo pipefail

REPO_URL="https://github.com/Aboudjem/aws-cost-audit-skill.git"
CLONE_DIR="${AWS_COST_AUDIT_HOME:-$HOME/.aws-cost-audit}"
SKILLS=(aws-cost-audit)
ALL_IDS=(gemini codex opencode pi vibe vscode copilot trae openclaw antigravity hermes cline kimi)
# Pinned so a CLI release cannot change this installer's behaviour without a
# deliberate bump here. Verified against `npx --yes skills@1.5.23 add --help`
# and the supported-agents table at https://github.com/vercel-labs/skills
SKILLS_CLI="skills@1.5.23"
REPO_SLUG="Aboudjem/aws-cost-audit-skill"
SKILL_NAME="aws-cost-audit"

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
  install.sh <platform> [--update | --uninstall] [--legacy] [--project]
  curl -fsSL https://raw.githubusercontent.com/Aboudjem/aws-cost-audit-skill/main/install.sh | bash -s <platform>

Platforms:
  ${ALL_IDS[*]}
  all   apply to every platform above

Options:
  --update     reinstall the current version of the skill
  --uninstall  remove the skill for <platform>
  --legacy     use the original symlink logic instead of the skills CLI
  --project    install into the current directory instead of your user profile
               (default path only; the legacy path is always user-level)
  -h, --help   show this help

By default this delegates to the Vercel skills CLI:
  npx --yes $SKILLS_CLI add $REPO_SLUG -a <agent> -g -y
If npx is not on PATH it falls back to the legacy symlink logic automatically.

This is a skill-only plugin (no MCP server). It requires the AWS CLI configured
with read access to the account you want to audit (ReadOnlyAccess is enough).
EOF
}

# platform_agent <id> -> the skills CLI agent code on stdout (empty if unknown).
# Every code below was checked against the supported-agents table in the
# vercel-labs/skills README and against `npx --yes skills@1.5.23 add --help`.
platform_agent() {
  case "$1" in
    gemini)         printf '%s\n' "gemini-cli" ;;
    codex)          printf '%s\n' "codex" ;;
    opencode)       printf '%s\n' "opencode" ;;
    pi)             printf '%s\n' "pi" ;;
    vibe)           printf '%s\n' "mistral-vibe" ;;
    vscode|copilot) printf '%s\n' "github-copilot" ;;
    trae)           printf '%s\n' "trae" ;;
    openclaw)       printf '%s\n' "openclaw" ;;
    antigravity)    printf '%s\n' "antigravity" ;;
    hermes)         printf '%s\n' "hermes-agent" ;;
    cline)          printf '%s\n' "cline" ;;
    kimi)           printf '%s\n' "kimi-code-cli" ;;
    *)              printf '%s\n' "" ;;
  esac
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

# Install or remove through the skills CLI. Args: <agent-code> <action> <scope-flag>
delegate_one() {
  local agent="$1" action="$2" scope="$3"
  case "$action" in
    install|update)
      if npx --yes "$SKILLS_CLI" add "$REPO_SLUG" -a "$agent" $scope -s "$SKILL_NAME" -y; then
        ok "installed $SKILL_NAME for $agent"
      else
        warn "skills CLI failed for $agent; try --legacy"
        return 1
      fi
      ;;
    uninstall)
      if npx --yes "$SKILLS_CLI" remove -a "$agent" $scope -s "$SKILL_NAME" -y; then
        info "removed $SKILL_NAME for $agent"
      else
        warn "skills CLI could not remove $SKILL_NAME for $agent"
        return 1
      fi
      ;;
  esac
}

main() {
  local platform="" action="install" arg
  local MODE="${MODE:-delegate}" SCOPE="${SCOPE:--g}"
  for arg in "$@"; do
    case "$arg" in
      --update)    action="update" ;;
      --uninstall) action="uninstall" ;;
      --legacy)    MODE="legacy" ;;
      --project)   SCOPE="" ;;
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

  if [ "$MODE" = "delegate" ] && ! command -v npx >/dev/null 2>&1; then
    warn "npx not found; falling back to the legacy symlink path."
    MODE="legacy"
  fi

  local id agent
  if [ "$MODE" = "delegate" ]; then
    for id in "${ids[@]}"; do
      agent="$(platform_agent "$id")"
      if [ -z "$agent" ]; then
        warn "unknown platform: $id (run --help for the list)."
        continue
      fi
      delegate_one "$agent" "$action" "$SCOPE" || true
    done
    return 0
  fi

  local root="" spec dir style
  if [ "$action" != "uninstall" ]; then
    root="$(resolve_root)"
    info "aws-cost-audit checkout: $root"
  fi

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
