<#
.SYNOPSIS
    Update the Job Search Tracker to the latest published build and redeploy.

.DESCRIPTION
    Run from the deploy folder:  ./update.ps1

    This assumes the deploy folder is a CLONE of your distribution repo (the one
    holding docker-compose.yml + images/*.tar + these scripts — compiled
    artifacts only, no source). It will:
      1. git pull the latest published artifacts (fast-forward only).
      2. Reload the refreshed app images (docker load).
      3. Recreate the containers (docker compose up -d) — your data volume is kept.
      4. Wait for the app to answer and report the URL.

    Newer images may carry newer database migrations; the backend's Flyway runs
    them automatically on start. Your tracked data is preserved across updates.

    Nothing here pulls or builds source. If this folder is not a git checkout,
    the script explains how to update manually (drop in the new images/ + compose
    and re-run bootstrap.ps1).
#>
[CmdletBinding()]
param(
    [switch]$NoBrowser,
    [switch]$Prune   # also remove dangling images left behind by the update
)

$ErrorActionPreference = 'Stop'
$Here        = $PSScriptRoot
$ComposeFile = Join-Path $Here 'docker-compose.yml'
$ImagesDir   = Join-Path $Here 'images'
$EnvFile     = Join-Path $Here '.env'

function Step($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "    $m" -ForegroundColor Green }
function Warn($m) { Write-Host "    $m" -ForegroundColor Yellow }
function Info($m) { Write-Host "    $m" -ForegroundColor Gray }

# Compose args: prefer the .env bootstrap wrote (chosen host ports) if present.
$composeArgs = @('-f', $ComposeFile)
if (Test-Path $EnvFile) { $composeArgs = @('--env-file', $EnvFile) + $composeArgs }

# ---- 1. pull latest published artifacts --------------------------------------
Step 'Fetching the latest published build (git pull)'
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Warn 'git is not installed, so this folder cannot self-update.'
    Info 'Install Git (or replace images/ + docker-compose.yml manually), then re-run.'
    exit 1
}
git -C $Here rev-parse --is-inside-work-tree *> $null
if ($LASTEXITCODE -ne 0) {
    Warn 'This deploy folder is not a git checkout, so there is nothing to pull.'
    Info 'To update manually: replace the images/*.tar and docker-compose.yml with the'
    Info 'newer ones, then run ./bootstrap.ps1 again. (Updates expect this folder to be'
    Info 'a clone of your distribution repo.)'
    exit 1
}
git -C $Here pull --ff-only
if ($LASTEXITCODE -ne 0) {
    Warn 'git pull could not fast-forward (local changes or diverged history).'
    Info 'Resolve manually:  git -C "<this folder>" status   then re-run ./update.ps1'
    exit 1
}
Ok 'up to date with the published build'

# ---- 2. ensure Docker is running ---------------------------------------------
Step 'Checking Docker'
function Test-DockerUp { try { docker info *> $null; return $true } catch { return $false } }
if (-not (Test-DockerUp)) {
    Warn 'Docker engine is not reachable. Start Docker Desktop and re-run ./update.ps1.'
    exit 1
}
Ok 'Docker engine reachable'

# ---- 3. reload refreshed images ----------------------------------------------
Step 'Loading updated app images'
if (Test-Path $ImagesDir) {
    Get-ChildItem (Join-Path $ImagesDir '*.tar') | ForEach-Object {
        Info ("docker load < {0}" -f $_.Name)
        docker load -i $_.FullName | Out-Null
        if ($LASTEXITCODE -ne 0) { Warn ("failed to load {0}" -f $_.Name) }
    }
    Ok 'images loaded'
} else {
    Warn "No images/ folder at $ImagesDir — recreating with whatever images are present."
}

# ---- 4. recreate the stack ---------------------------------------------------
Step 'Redeploying (docker compose up -d)'
docker compose @composeArgs up -d
if ($LASTEXITCODE -ne 0) { Warn 'docker compose up failed — see output above.'; exit 1 }

if ($Prune) {
    Step 'Pruning dangling images'
    docker image prune -f | Out-Null
    Ok 'removed dangling images'
}

# ---- 5. wait + report --------------------------------------------------------
$WebPort = 8088
if (Test-Path $EnvFile) {
    $line = (Get-Content -LiteralPath $EnvFile | Where-Object { $_ -match '^WEB_PORT=' } | Select-Object -First 1)
    if ($line) { $WebPort = ($line -split '=', 2)[1].Trim() }
}
$AppUrl = "http://localhost:$WebPort"

Step 'Waiting for the app to answer'
$up = $false
for ($i = 0; $i -lt 40; $i++) {
    Start-Sleep 3
    try { if ((Invoke-WebRequest "$AppUrl" -UseBasicParsing -TimeoutSec 3).StatusCode -eq 200) { $up = $true; break } } catch {}
}
if ($up) { Ok "Updated and running at $AppUrl" }
else { Warn "App didn't answer yet — give it a minute, then open $AppUrl (check: docker compose logs -f backend)" }

if (-not $NoBrowser -and $up) { Start-Process $AppUrl }

Write-Host ''
Write-Host '====================================================================' -ForegroundColor Cyan
Write-Host ' Update complete.' -ForegroundColor Cyan
Write-Host "  - App:        $AppUrl" -ForegroundColor White
Write-Host '  - Logs:       docker compose logs -f backend' -ForegroundColor White
Write-Host '  - Teardown:   ./teardown.ps1' -ForegroundColor White
Write-Host '====================================================================' -ForegroundColor Cyan
