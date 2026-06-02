<#
.SYNOPSIS
    First-run setup for the Job Search Tracker (Windows). Installs prerequisites
    (with your consent), loads the app images, and starts everything.

.DESCRIPTION
    Run this from the folder it lives in:  ./bootstrap.ps1
    It will:
      1. Check what's already installed.
      2. Show you EXACTLY what it would install, and ask before doing anything.
      3. Install missing prerequisites via winget (each may raise a Windows UAC
         elevation prompt — that's the consented install).
      4. Optionally install + explain Tailscale (only if you opt in).
      5. Load the prebuilt Docker images and run `docker compose up`.
      6. Open the app at http://localhost:8088.

    Nothing is installed silently. Re-running is safe (it skips what's present).
#>
[CmdletBinding()]
param(
    [switch]$Yes,          # assume "yes" to the install prompt (still per-winget UAC)
    [switch]$NoBrowser,
    [switch]$Update,       # git pull the latest published build before starting
    [switch]$NoTailscale   # skip the optional Tailscale prompt (non-interactive redeploys)
)

$ErrorActionPreference = 'Stop'
$Here        = $PSScriptRoot
$ComposeFile = Join-Path $Here 'docker-compose.yml'
$ImagesDir   = Join-Path $Here 'images'
$SchemaFile  = Join-Path $Here 'schema.version'
$AppUrl      = 'http://localhost:8088'

function Step($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "    $m" -ForegroundColor Green }
function Warn($m) { Write-Host "    $m" -ForegroundColor Yellow }
function Info($m) { Write-Host "    $m" -ForegroundColor Gray }

# ---- prerequisites table -----------------------------------------------------
function Test-Soffice {
    if (Get-Command soffice -ErrorAction SilentlyContinue) { return $true }
    return (Test-Path 'C:\Program Files\LibreOffice\program\soffice.exe')
}

$Prereqs = @(
    @{ Name='Docker Desktop'; Id='Docker.DockerDesktop';            Test={ [bool](Get-Command docker  -ErrorAction SilentlyContinue) }; Why='runs the app' }
    @{ Name='Git';            Id='Git.Git';                         Test={ [bool](Get-Command git     -ErrorAction SilentlyContinue) }; Why='version control for the workflow' }
    @{ Name='Node.js LTS';    Id='OpenJS.NodeJS.LTS';               Test={ [bool](Get-Command node    -ErrorAction SilentlyContinue) }; Why='runs the workflow CLI (tracker.mjs)' }
    @{ Name='Python 3';       Id='Python.Python.3.12';              Test={ [bool](Get-Command python  -ErrorAction SilentlyContinue) }; Why='used by the document skills' }
    @{ Name='Pandoc';         Id='JohnMacFarlane.Pandoc';           Test={ [bool](Get-Command pandoc  -ErrorAction SilentlyContinue) }; Why='reads/writes .docx in the skills' }
    @{ Name='LibreOffice';    Id='TheDocumentFoundation.LibreOffice'; Test={ Test-Soffice };                                            Why='converts .docx -> .pdf (no MS Word needed)' }
)

# ---- optional: pull the latest published build (-Update) ---------------------
# Refreshes the compose file + image tarballs from your distribution repo, then
# the normal "load images" + "compose up" steps below pick up the new build.
if ($Update) {
    Step 'Updating to the latest published build (git pull)'
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Warn 'git is not installed yet — skipping update. (It will be offered below.)'
    } else {
        git -C $Here rev-parse --is-inside-work-tree *> $null
        if ($LASTEXITCODE -ne 0) {
            Warn 'This folder is not a git checkout — nothing to pull. Continuing with what is here.'
        } else {
            git -C $Here pull --ff-only
            if ($LASTEXITCODE -ne 0) { Warn 'git pull could not fast-forward — continuing with the current build.' }
            else { Ok 'pulled the latest published build' }
        }
    }
}

# ---- winget present? ---------------------------------------------------------
Step 'Checking for winget (Windows Package Manager)'
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Warn 'winget not found. Install "App Installer" from the Microsoft Store, then re-run this script.'
    Warn 'https://apps.microsoft.com/detail/9nblggh4nns1'
    exit 1
}
Ok 'winget available'

# ---- detect what's missing ---------------------------------------------------
Step 'Checking prerequisites'
$missing = @()
foreach ($p in $Prereqs) {
    if (& $p.Test) { Ok ("present : {0}" -f $p.Name) }
    else           { Warn ("missing : {0}  ({1})" -f $p.Name, $p.Why); $missing += $p }
}

# ---- consent + install -------------------------------------------------------
if ($missing.Count -gt 0) {
    Write-Host ''
    Write-Host 'The following will be installed via winget:' -ForegroundColor White
    foreach ($p in $missing) { Write-Host ("   - {0}   (winget id: {1})" -f $p.Name, $p.Id) }
    Write-Host ''
    Warn 'Each install may show a Windows UAC elevation prompt. Nothing installs without your click.'
    $go = $Yes
    if (-not $go) {
        $ans = (Read-Host 'Install these now? [y/N]').Trim().ToLower()
        $go = ($ans -eq 'y' -or $ans -eq 'yes')
    }
    if (-not $go) { Warn 'Skipped installs. The app may not start until prerequisites are present.'; }
    else {
        foreach ($p in $missing) {
            Step ("Installing {0}" -f $p.Name)
            winget install --id $p.Id -e --source winget --accept-package-agreements --accept-source-agreements
            if ($LASTEXITCODE -ne 0) { Warn ("winget returned $LASTEXITCODE for {0} — you may need to install it manually." -f $p.Name) }
            else { Ok ("installed {0}" -f $p.Name) }
        }
        Warn 'If Docker Desktop was just installed, Windows may need a REBOOT (and WSL2 enabled) before Docker can run.'
    }
}
else { Ok 'all prerequisites already present' }

# ---- optional: Tailscale -----------------------------------------------------
if ($NoTailscale) {
    Info 'Skipping the Tailscale step (-NoTailscale).'
} else {
Step 'Tailscale (optional) — reach the tracker from your phone/iPad'
Info 'Tailscale is a free, secure private network. Install it on your PC and phone,'
Info 'sign in to the same account on both, and your phone can open this app at'
Info 'http://<your-pc-name>.ts.net:8088 from anywhere — nothing exposed publicly.'
$tsInstalled = [bool](Get-Command tailscale -ErrorAction SilentlyContinue)
if ($tsInstalled) { Ok 'Tailscale already installed.' }
else {
    $ans = (Read-Host 'Install Tailscale now? [y/N]').Trim().ToLower()
    if ($ans -eq 'y' -or $ans -eq 'yes') {
        Step 'Installing Tailscale'
        winget install --id tailscale.tailscale -e --source winget --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -eq 0) {
            Ok 'Tailscale installed.'
            Info 'Next: launch Tailscale, sign in, install the Tailscale app on your phone with the'
            Info 'same account, then browse to  http://<your-pc-name>.ts.net:8088  on the phone.'
            Info 'Find your PC name with:  tailscale status'
        } else { Warn 'Tailscale install did not complete — see https://tailscale.com/download' }
    } else { Info 'Skipped. You can install it later from https://tailscale.com/download' }
}
}

# ---- ensure Docker is running ------------------------------------------------
Step 'Ensuring Docker is running'
function Test-DockerUp { try { docker info *> $null; return $true } catch { return $false } }
if (-not (Test-DockerUp)) {
    $dd = 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
    if (Test-Path $dd) {
        Info 'Starting Docker Desktop and waiting for the engine...'
        Start-Process $dd
        for ($i = 0; $i -lt 36; $i++) { Start-Sleep 5; if (Test-DockerUp) { break } }
    }
    if (-not (Test-DockerUp)) {
        Warn 'Docker engine is not reachable. If you just installed Docker Desktop, REBOOT,'
        Warn 'make sure WSL2 / virtualization is enabled, start Docker Desktop, then re-run this script.'
        exit 1
    }
}
Ok 'Docker engine reachable'

# ---- load prebuilt images ----------------------------------------------------
Step 'Loading app images'
if (-not (Test-Path $ImagesDir)) { Warn "No images/ folder at $ImagesDir"; exit 1 }
Get-ChildItem (Join-Path $ImagesDir '*.tar') | ForEach-Object {
    Info ("docker load < {0}" -f $_.Name)
    docker load -i $_.FullName | Out-Null
    if ($LASTEXITCODE -ne 0) { Warn ("failed to load {0}" -f $_.Name) }
}
Ok 'images loaded'

# ---- choose host ports (avoid collisions with anything already running) -------
# The app publishes a web port (browser) and an API port (host-side CLI + health).
# Defaults are 8088 / 8080; if either is taken (e.g. a separate dev server holds
# 8080) we pick the next free port and record the choice in .env, which compose
# reads for ${WEB_PORT} / ${BACKEND_PORT}. Nothing collides, no manual edits.
# On a re-run / redeploy we REUSE the ports already chosen in .env so they stay
# stable (and don't drift just because our own running stack is holding them).
Step 'Selecting host ports'
function Test-PortFree([int]$p) {
    try { $l = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $p); $l.Start(); $l.Stop(); return $true }
    catch { return $false }
}
function Get-FreePort([int]$start) {
    for ($p = $start; $p -lt ($start + 50); $p++) { if (Test-PortFree $p) { return $p } }
    return 0
}
$EnvFile = Join-Path $Here '.env'
$WebPort = 0
$BackendPort = 0
if (Test-Path $EnvFile) {
    foreach ($line in Get-Content -LiteralPath $EnvFile) {
        if ($line -match '^WEB_PORT=(\d+)')     { $WebPort = [int]$Matches[1] }
        if ($line -match '^BACKEND_PORT=(\d+)') { $BackendPort = [int]$Matches[1] }
    }
}
if ($WebPort -gt 0 -and $BackendPort -gt 0) {
    Info 'Reusing the host ports already chosen in .env.'
} else {
    $WebPort     = Get-FreePort 8088
    $BackendPort = Get-FreePort 8080
    if ($BackendPort -eq $WebPort) { $BackendPort = Get-FreePort ($WebPort + 1) }
    if ($WebPort -eq 0 -or $BackendPort -eq 0) { Warn 'Could not find free host ports near 8088 / 8080.'; exit 1 }
    if ($WebPort -ne 8088)     { Warn ("Port 8088 is busy — using {0} for the app instead." -f $WebPort) }
    if ($BackendPort -ne 8080) { Warn ("Port 8080 is busy — using {0} for the API instead." -f $BackendPort) }
    @("WEB_PORT=$WebPort", "BACKEND_PORT=$BackendPort") | Set-Content -LiteralPath $EnvFile -Encoding ascii
}
$AppUrl = "http://localhost:$WebPort"
Ok ("web -> {0}   |   api -> http://localhost:{1}" -f $AppUrl, $BackendPort)

# ---- bring up Postgres first + verify schema compatibility -------------------
# This stack runs under its own compose project (jobsearch-tracker) with isolated,
# uniquely-named containers and volume, so it never collides with a separate dev
# copy. Start ONLY the database first, so we can read its Flyway history before the
# backend tries to migrate: a volume left over from a NEWER build would make the
# packaged (older) backend's Flyway refuse to start — caught below with a clear note.
Step 'Starting the database'
docker compose --env-file $EnvFile -f $ComposeFile up -d postgres
if ($LASTEXITCODE -ne 0) { Warn 'docker compose up (postgres) failed — see output above.'; exit 1 }

# Resolve the actual container id from compose (name is project-scoped, not fixed).
$DbCid = (docker compose -f $ComposeFile ps -q postgres 2>$null | Select-Object -First 1)
if (-not $DbCid) { Warn 'Could not find the database container after starting it.'; Info 'Check: docker compose logs postgres'; exit 1 }

Step 'Waiting for the database to be ready'
$dbReady = $false
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep 2
    docker exec $DbCid pg_isready -U jobsearch -d jobsearch *> $null
    if ($LASTEXITCODE -eq 0) { $dbReady = $true; break }
}
if (-not $dbReady) { Warn 'Database did not become ready in time.'; Info 'Check: docker compose logs postgres'; exit 1 }
Ok 'Database ready'

Step 'Checking schema version'
$expected = $null
if (Test-Path $SchemaFile) { $expected = [int]((Get-Content -LiteralPath $SchemaFile -Raw).Trim()) }
# Read the highest applied migration; empty/absent table => fresh DB.
$dbVerRaw = docker exec $DbCid psql -U jobsearch -d jobsearch -tAc `
    "select coalesce(max(version::numeric),0) from flyway_schema_history where success" 2>$null
$dbVer = 0
if ($LASTEXITCODE -eq 0 -and $dbVerRaw) { [void][int]::TryParse(($dbVerRaw | Out-String).Trim(), [ref]$dbVer) }

if ($null -eq $expected) {
    Info 'No schema.version shipped with this package — skipping schema check.'
} elseif ($dbVer -eq 0) {
    Ok ("Fresh database — the app will create schema v{0} on first start." -f $expected)
} elseif ($dbVer -gt $expected) {
    Warn ("Existing data is at schema v{0}, but this package only understands v{1}." -f $dbVer, $expected)
    Warn 'This is an OLDER package than the data — starting it could fail or risk your data.'
    Info 'Use a newer package, or reset the data with:  docker compose down -v  (deletes tracked data).'
    $ans = (Read-Host 'Start the app anyway? [y/N]').Trim().ToLower()
    if ($ans -ne 'y' -and $ans -ne 'yes') { Warn 'Stopped. No app containers were started.'; exit 1 }
} elseif ($dbVer -lt $expected) {
    Ok ("Existing data at schema v{0}; the app will migrate it up to v{1} on start." -f $dbVer, $expected)
} else {
    Ok ("Schema is up to date (v{0})." -f $dbVer)
}

# ---- bring up the rest of the stack ------------------------------------------
Step 'Starting the app (docker compose up -d)'
docker compose --env-file $EnvFile -f $ComposeFile up -d
if ($LASTEXITCODE -ne 0) { Warn 'docker compose up failed — see output above.'; exit 1 }

Step 'Waiting for the app to answer'
$up = $false
for ($i = 0; $i -lt 40; $i++) {
    Start-Sleep 3
    try { if ((Invoke-WebRequest "$AppUrl" -UseBasicParsing -TimeoutSec 3).StatusCode -eq 200) { $up = $true; break } } catch {}
}
if ($up) { Ok "App is up at $AppUrl" } else { Warn "App didn't answer yet — give it a minute, then open $AppUrl (check: docker compose logs -f backend)" }

if (-not $NoBrowser) { Start-Process $AppUrl }

Write-Host ''
Write-Host '====================================================================' -ForegroundColor Cyan
Write-Host ' Setup complete.' -ForegroundColor Cyan
Write-Host "  - Open the app:        $AppUrl" -ForegroundColor White
Write-Host "  - API (CLI/health):    http://localhost:$BackendPort" -ForegroundColor White
Write-Host '  - Stop it:             docker compose down       (run from this folder)' -ForegroundColor White
Write-Host '  - Start it again:      docker compose up -d      (run from this folder)' -ForegroundColor White
Write-Host '  - Next steps:          see README.md (add a resume template + fill candidate-considerations.md)' -ForegroundColor White
Write-Host '  - AI agent operating?  read AGENTS.md' -ForegroundColor White
if ($BackendPort -ne 8080) {
    Write-Host ''
    Write-Host ("  NOTE: the API is on $BackendPort (8080 was busy). The workflow CLI defaults to 8080,") -ForegroundColor Yellow
    Write-Host ("        so point it at this port first:  `$env:TRACKER_API = 'http://localhost:$BackendPort'") -ForegroundColor Yellow
}
Write-Host '====================================================================' -ForegroundColor Cyan
