# update.ps1 — pull the latest dot-opencode and refresh the install (Windows).
#
# With a symlink install, `git pull` alone makes most changes live. This wrapper
# refuses to pull over local edits, then re-links new items / reinstalls plugin
# deps (or re-copies, for a -Copy install). Run on each machine for updates.
#
# Usage:  ./update.ps1
$ErrorActionPreference = "Stop"

$Repo   = Split-Path -Parent $MyInvocation.MyCommand.Path
$Target = if ($env:OPENCODE_CONFIG_DIR) { $env:OPENCODE_CONFIG_DIR } else { Join-Path $HOME ".config/opencode" }
Push-Location $Repo
try {
  # Guard: never pull over uncommitted local edits.
  if (git status --porcelain) {
    Write-Host "x dot-opencode has uncommitted changes - commit or stash before updating:"
    git status --short
    exit 1
  }

  $branch = git rev-parse --abbrev-ref HEAD
  Write-Host "> git pull --ff-only ($branch)"
  git pull --ff-only
  if ($LASTEXITCODE -ne 0) { Write-Host "x pull failed (diverged?). Resolve manually."; exit 1 }

  # Fail fast on a malformed config rather than let OpenCode crash at startup.
  $py = Get-Command python3 -ErrorAction SilentlyContinue
  if (-not $py) { $py = Get-Command python -ErrorAction SilentlyContinue }
  if ($py) {
    & $py.Source (Join-Path $Repo "scripts/validate.py")
    if ($LASTEXITCODE -ne 0) { Write-Host "x config validation failed - fix the file above before launching OpenCode."; exit 1 }
  } else {
    Write-Host "  (python not found - skipping config check)"
  }

  # Copy-mode installs need a re-copy; symlink installs are already live.
  $agents = Join-Path $Target "AGENTS.md"
  $isCopy = (Test-Path $agents) -and -not (Get-Item $agents -Force).LinkType
  if ($isCopy) {
    Write-Host "> copy-mode install detected - re-copying into $Target"
    ./install.ps1 -Copy
  } else {
    Write-Host "ok symlink install - pulled changes are already live"
    ./install.ps1
  }
  Write-Host "ok done - restart OpenCode to load updates."
} finally { Pop-Location }
