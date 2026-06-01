# install.ps1 — link this dot-opencode repo into ~/.config/opencode (Windows).
#
# Symlinks each config item into the OpenCode global config dir, leaving the dir
# itself real so OpenCode can still write runtime state. Real files already in
# place are backed up to <name>.bak.<timestamp> first.
#
# Symlinks on Windows need Developer Mode (Settings > For developers) or an
# elevated shell. If neither is available, pass -Copy to copy instead.
#
# Usage:
#   ./install.ps1            # symlink (preferred)
#   ./install.ps1 -Copy      # copy instead of symlink
#
param([switch]$Copy)
$ErrorActionPreference = "Stop"

$Repo   = Split-Path -Parent $MyInvocation.MyCommand.Path
$Target = if ($env:OPENCODE_CONFIG_DIR) { $env:OPENCODE_CONFIG_DIR } else { Join-Path $HOME ".config/opencode" }
$Items  = @("opencode.jsonc","tui.json","AGENTS.md","package.json","commands","agents","plugins","guidelines","guides","scripts","themes")
$Stamp  = Get-Date -Format "yyyyMMdd-HHmmss"
$Mode   = if ($Copy) { "copy" } else { "link" }

New-Item -ItemType Directory -Force -Path $Target | Out-Null
Write-Host "dot-opencode -> $Target  (mode: $Mode)"

foreach ($item in $Items) {
  $src = Join-Path $Repo $item
  $dst = Join-Path $Target $item
  if (-not (Test-Path $src)) { continue }

  if (Test-Path $dst) {
    $existing = Get-Item $dst -Force
    if ($existing.LinkType) {
      Remove-Item $dst -Force -Recurse
    } else {
      Move-Item $dst "$dst.bak.$Stamp"
      Write-Host "  backed up existing $item -> $item.bak.$Stamp"
    }
  }

  if ($Copy) {
    Copy-Item $src $dst -Recurse
    Write-Host "  copied  $item"
  } else {
    New-Item -ItemType SymbolicLink -Path $dst -Target $src | Out-Null
    Write-Host "  linked  $item"
  }
}

# Restore the plugin SDK so safety.js can import @opencode-ai/plugin.
Push-Location $Target
try {
  if (Get-Command bun -ErrorAction SilentlyContinue) {
    bun install; Write-Host "  bun install: ok"
  } elseif (Get-Command npm -ErrorAction SilentlyContinue) {
    npm install; Write-Host "  npm install: ok"
  } else {
    Write-Host "  NOTE: neither bun nor npm found — run 'bun install' in $Target so the plugin resolves."
  }
} finally { Pop-Location }

Write-Host "Done. Restart OpenCode to load the new config and plugin."
