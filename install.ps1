#requires -version 5
<#
.SYNOPSIS
  AWS Cost Audit multi-CLI installer (PowerShell mirror of install.sh).

.DESCRIPTION
  Symlinks the aws-cost-audit skill into a target AI coding CLI's skills
  directory. This is a skill-only plugin: there is no MCP server. The skill
  shells out to the AWS CLI (read-only by default) and runs inside whichever
  CLI loads it.

  This is the legacy symlink path only. install.sh on macOS and Linux now
  delegates to the Vercel skills CLI by default (npx skills add) and keeps the
  symlink logic behind --legacy; PowerShell users get the symlink logic, or can
  run the skills CLI directly:
    npx --yes skills@1.5.23 add Aboudjem/aws-cost-audit-skill -a github-copilot -g -y
  See docs/editors.md for the agent code for each editor.

  Creating symlinks on Windows needs Developer Mode enabled or an elevated
  shell. If symlink creation fails, copy skills/aws-cost-audit into your CLI's
  skills directory by hand.

.EXAMPLE
  ./install.ps1 copilot
  ./install.ps1 all -Update
  ./install.ps1 codex -Uninstall

.NOTES
  Platforms: gemini codex opencode pi vibe vscode copilot trae
             openclaw antigravity hermes cline kimi  (or: all)
  Skill-directory conventions change between CLI releases; verify your CLI's
  current skills path if a link does not resolve.
#>
param(
  [Parameter(Position = 0)][string]$Platform,
  [switch]$Update,
  [switch]$Uninstall,
  [switch]$Help
)

$ErrorActionPreference = 'Stop'

$RepoUrl  = 'https://github.com/Aboudjem/aws-cost-audit-skill.git'
$CloneDir = if ($env:AWS_COST_AUDIT_HOME) { $env:AWS_COST_AUDIT_HOME } else { Join-Path $HOME '.aws-cost-audit' }
$Skills   = @('aws-cost-audit')
$AllIds   = @('gemini','codex','opencode','pi','vibe','vscode','copilot','trae','openclaw','antigravity','hermes','cline','kimi')

function Show-Usage {
  @"
AWS Cost Audit installer

Usage:
  ./install.ps1 <platform> [-Update | -Uninstall]

Platforms:
  $($AllIds -join ' ')
  all   apply to every platform above

Options:
  -Update     pull the latest skill and relink
  -Uninstall  remove the symlinks for <platform>
  -Help       show this help

This is a skill-only plugin (no MCP server). It requires the AWS CLI configured
with read access to the account you want to audit (ReadOnlyAccess is enough).
"@ | Write-Output
}

function Get-PlatformTarget([string]$Id) {
  switch ($Id) {
    { $_ -in 'gemini','codex','opencode','pi' } { return @{ Dir = (Join-Path $HOME '.agents/skills');     Style = 'per-skill' } }
    'vibe'        { return @{ Dir = (Join-Path $HOME '.vibe/skills');               Style = 'per-skill' } }
    { $_ -in 'vscode','copilot' } { return @{ Dir = (Join-Path $HOME '.copilot/skills'); Style = 'per-skill' } }
    'trae'        { return @{ Dir = (Join-Path $HOME '.trae/skills');               Style = 'per-skill' } }
    'openclaw'    { return @{ Dir = (Join-Path $HOME '.openclaw/skills');           Style = 'folder' } }
    'antigravity' { return @{ Dir = (Join-Path $HOME '.gemini/antigravity/skills'); Style = 'folder' } }
    'hermes'      { return @{ Dir = (Join-Path $HOME '.hermes/skills');             Style = 'folder' } }
    'cline'       { return @{ Dir = (Join-Path $HOME '.cline/skills');              Style = 'folder' } }
    'kimi'        { return @{ Dir = (Join-Path $HOME '.kimi/skills');               Style = 'folder' } }
    default       { return $null }
  }
}

function Resolve-Root {
  if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot 'skills'))) {
    return $PSScriptRoot
  }
  if (Test-Path (Join-Path $CloneDir '.git')) {
    git -C $CloneDir pull --ff-only --quiet 2>$null | Out-Null
  }
  else {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
      throw 'git is required to install without a local checkout.'
    }
    git clone --depth 1 $RepoUrl $CloneDir 2>$null | Out-Null
  }
  return $CloneDir
}

function New-Link([string]$LinkPath, [string]$TargetPath) {
  $dir = Split-Path -Parent $LinkPath
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  if (Test-Path $LinkPath) { Remove-Item $LinkPath -Force -Recurse -ErrorAction SilentlyContinue }
  New-Item -ItemType SymbolicLink -Path $LinkPath -Target $TargetPath | Out-Null
  Write-Output "linked $LinkPath -> $TargetPath"
}

function Install-One([string]$Root, $Spec) {
  if ($Spec.Style -eq 'folder') {
    New-Link (Join-Path $Spec.Dir 'aws-cost-audit') (Join-Path $Root 'skills/aws-cost-audit')
  }
  else {
    foreach ($s in $Skills) {
      New-Link (Join-Path $Spec.Dir $s) (Join-Path $Root "skills/$s")
    }
  }
}

function Uninstall-One($Spec) {
  if ($Spec.Style -eq 'folder') {
    $p = Join-Path $Spec.Dir 'aws-cost-audit'
    if (Test-Path $p) { Remove-Item $p -Force -Recurse; Write-Output "removed $p" }
  }
  else {
    foreach ($s in $Skills) {
      $p = Join-Path $Spec.Dir $s
      if (Test-Path $p) { Remove-Item $p -Force -Recurse; Write-Output "removed $p" }
    }
  }
}

if ($Help -or -not $Platform) { Show-Usage; if ($Help) { exit 0 } else { exit 1 } }

$ids = if ($Platform -eq 'all') { $AllIds } else { @($Platform) }

$root = $null
if (-not $Uninstall) {
  $root = Resolve-Root
  Write-Output "aws-cost-audit checkout: $root"
}

foreach ($id in $ids) {
  $spec = Get-PlatformTarget $id
  if ($null -eq $spec) {
    Write-Warning "unknown platform: $id (use -Help for the list)."
    continue
  }
  if ($Uninstall) { Uninstall-One $spec } else { Install-One $root $spec }
}
