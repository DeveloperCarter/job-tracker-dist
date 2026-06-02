<#
.SYNOPSIS
    Stop (and optionally remove) the Job Search Tracker.

.DESCRIPTION
    Run from the deploy folder:  ./teardown.ps1

    Default (safe): stops and removes the app containers but KEEPS your data
    (the Postgres volume and your workspace files are untouched). Start again
    anytime with ./bootstrap.ps1 (or: docker compose up -d).

    Flags (destructive — each prompts before acting):
      -Volumes   also delete the database volume (your tracked postings/status).
                 Your workspace/ files on disk are NOT touched.
      -Images    also remove the app's Docker images (frees disk; bootstrap or
                 update reloads them from images/*.tar next time).
      -Yes       skip the confirmation prompts (for the destructive flags).

.EXAMPLE
    ./teardown.ps1                 # stop the app, keep all data
    ./teardown.ps1 -Volumes        # stop + delete tracked data (asks first)
    ./teardown.ps1 -Volumes -Images -Yes
#>
[CmdletBinding()]
param(
    [switch]$Volumes,
    [switch]$Images,
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'
$Here        = $PSScriptRoot
$ComposeFile = Join-Path $Here 'docker-compose.yml'
$EnvFile     = Join-Path $Here '.env'

function Step($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "    $m" -ForegroundColor Green }
function Warn($m) { Write-Host "    $m" -ForegroundColor Yellow }
function Info($m) { Write-Host "    $m" -ForegroundColor Gray }

function Confirm-Destructive([string]$prompt) {
    if ($Yes) { return $true }
    $ans = (Read-Host "$prompt [y/N]").Trim().ToLower()
    return ($ans -eq 'y' -or $ans -eq 'yes')
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Warn 'Docker is not installed — nothing to tear down.'
    exit 0
}

$composeArgs = @('-f', $ComposeFile)
if (Test-Path $EnvFile) { $composeArgs = @('--env-file', $EnvFile) + $composeArgs }

# Image names this stack uses (matches docker-compose.yml).
$AppImages = @('jobsearch-backend:local', 'jobsearch-web:local')

# ---- confirm destructive choices up front ------------------------------------
$dropVolumes = $false
if ($Volumes) {
    Warn 'You asked to DELETE the database volume — this erases your tracked'
    Warn 'postings, statuses and history. Your workspace/ files stay on disk.'
    if (Confirm-Destructive 'Permanently delete the tracked data?') { $dropVolumes = $true }
    else { Info 'Keeping the data volume.' }
}

# ---- bring the stack down ----------------------------------------------------
Step ('Stopping the app' + ($(if ($dropVolumes) { ' and deleting its data volume' } else { ' (data kept)' })))
if ($dropVolumes) {
    docker compose @composeArgs down -v
} else {
    docker compose @composeArgs down
}
if ($LASTEXITCODE -ne 0) { Warn 'docker compose down reported an error — see output above.' }
else { Ok 'app stopped' }

# ---- optionally remove images ------------------------------------------------
if ($Images) {
    if (Confirm-Destructive 'Also remove the app Docker images?') {
        Step 'Removing app images'
        foreach ($img in $AppImages) {
            docker image rm $img 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) { Ok "removed $img" } else { Info "not present: $img" }
        }
        Info 'bootstrap.ps1 / update.ps1 will reload them from images/*.tar next time.'
    }
}

Write-Host ''
Write-Host '====================================================================' -ForegroundColor Cyan
Write-Host ' Teardown complete.' -ForegroundColor Cyan
if ($dropVolumes) {
    Write-Host '  - Tracked data was DELETED. A fresh start creates an empty database.' -ForegroundColor White
} else {
    Write-Host '  - Your data was kept. Start again with:  ./bootstrap.ps1' -ForegroundColor White
}
Write-Host '====================================================================' -ForegroundColor Cyan
