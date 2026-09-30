# tests/test-install-package-json.ps1: install.ps1 must COPY package.json, not link it.
# Needs symlink rights (Developer Mode or elevation) for the other items.
$ErrorActionPreference = "Stop"
$Repo = Split-Path -Parent $PSScriptRoot
$Tmp = Join-Path ([IO.Path]::GetTempPath()) ("dot-opencode-test-" + [guid]::NewGuid())
$env:OPENCODE_CONFIG_DIR = Join-Path $Tmp "opencode"
$env:PATH = (Join-Path $Tmp "nobin") + [IO.Path]::PathSeparator + $env:PATH   # no bun/npm on PATH
try {
  & (Join-Path $Repo "install.ps1") | Out-Null
  $pj = Get-Item (Join-Path $env:OPENCODE_CONFIG_DIR "package.json") -Force
  $oc = Get-Item (Join-Path $env:OPENCODE_CONFIG_DIR "opencode.jsonc") -Force
  $fail = 0
  if ($pj.LinkType) { Write-Host "FAIL: package.json is a $($pj.LinkType)"; $fail = 1 }
  if ((Get-FileHash $pj.FullName).Hash -ne (Get-FileHash (Join-Path $Repo "package.json")).Hash) { Write-Host "FAIL: package.json content differs"; $fail = 1 }
  if (-not $oc.LinkType) { Write-Host "FAIL: opencode.jsonc should still be a symlink"; $fail = 1 }
  if ($fail -eq 0) { Write-Host "PASS: package.json copied, other items linked" }
  exit $fail
} finally { Remove-Item $Tmp -Recurse -Force -ErrorAction SilentlyContinue }
