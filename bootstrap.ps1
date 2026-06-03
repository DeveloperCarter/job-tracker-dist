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
         elevation prompt - that's the consented install).
      4. Ensure Docker's WSL2 backend is enabled (and flag BIOS virtualization).
         If WSL2 was just turned on, it asks you to reboot and re-run.
      5. Optionally install + explain Tailscale (only if you opt in).
      6. Load the prebuilt Docker images and run `docker compose up`.
      7. Open the app at http://localhost:8088.

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

# Is this PowerShell session elevated? (wsl --install needs admin rights.)
function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

# InstallState 1 = enabled. Win32_OptionalFeature is queryable WITHOUT elevation
# (unlike DISM / Get-WindowsOptionalFeature). Returns $true/$false, or $null if
# the feature can't be queried (don't block on an unknown).
function Test-WindowsFeature($name) {
    try {
        $f = Get-CimInstance -ClassName Win32_OptionalFeature -Filter "Name='$name'" -ErrorAction Stop
        if (-not $f) { return $false }
        return ($f.InstallState -eq 1)
    } catch { return $null }
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
        Warn 'git is not installed yet - skipping update. (It will be offered below.)'
    } else {
        git -C $Here rev-parse --is-inside-work-tree *> $null
        if ($LASTEXITCODE -ne 0) {
            Warn 'This folder is not a git checkout - nothing to pull. Continuing with what is here.'
        } else {
            git -C $Here pull --ff-only
            if ($LASTEXITCODE -ne 0) { Warn 'git pull could not fast-forward - continuing with the current build.' }
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
            if ($LASTEXITCODE -ne 0) { Warn ("winget returned $LASTEXITCODE for {0} - you may need to install it manually." -f $p.Name) }
            else { Ok ("installed {0}" -f $p.Name) }
        }
        Warn 'If Docker Desktop was just installed, Windows may need a REBOOT (and WSL2 enabled) before Docker can run.'
    }
}
else { Ok 'all prerequisites already present' }

# ---- virtualization + WSL2 backend (Docker Desktop requirement) --------------
# Docker Desktop runs its engine inside a lightweight VM via the WSL2 backend,
# which needs (a) CPU virtualization enabled in firmware and (b) the WSL2 /
# Virtual Machine Platform Windows features. The "Virtualization support not
# detected" error at Docker startup means one of these is missing. A script can
# enable the Windows features (with elevation); it CANNOT flip a BIOS setting.
Step 'Checking virtualization + WSL2 (Docker Desktop backend)'

# (a) Firmware virtualization. HypervisorPresent=true means a hypervisor is
# already running (so virtualization is on). Only warn when both say "off".
$cpuVirt = $null
$hyperv  = $null
try { $cpuVirt = (Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1).VirtualizationFirmwareEnabled } catch {}
try { $hyperv  = (Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).HypervisorPresent } catch {}
if ($cpuVirt -eq $false -and $hyperv -ne $true) {
    Warn 'CPU virtualization appears DISABLED in firmware (BIOS/UEFI).'
    Warn 'Docker Desktop cannot start without it. Reboot into BIOS/UEFI, enable'
    Warn 'Intel VT-x  (or AMD SVM / AMD-V), save, then re-run this script.'
    Warn 'Tip: Task Manager > Performance > CPU shows Virtualization: Enabled/Disabled.'
}

# (b) WSL2 / Virtual Machine Platform features.
$vmp = Test-WindowsFeature 'VirtualMachinePlatform'
$wsl = Test-WindowsFeature 'Microsoft-Windows-Subsystem-Linux'
if ($vmp -eq $true -and $wsl -eq $true) {
    Ok 'WSL2 backend features enabled.'
} elseif ($vmp -eq $null -or $wsl -eq $null) {
    Info 'Could not query Windows features - skipping the WSL2 enable.'
    Info 'If Docker reports "Virtualization support not detected", run (as admin):'
    Info '    wsl --install --no-distribution    then reboot.'
} else {
    Warn 'The WSL2 backend is not fully enabled yet - Docker Desktop needs it.'
    $go = $Yes
    if (-not $go) {
        $ans = (Read-Host 'Enable WSL2 now via "wsl --install --no-distribution"? [y/N]').Trim().ToLower()
        $go = ($ans -eq 'y' -or $ans -eq 'yes')
    }
    if ($go) {
        Step 'Enabling WSL2 (wsl --install --no-distribution)'
        # --no-distribution installs the WSL2 kernel + enables the platform WITHOUT
        # pulling a Linux distro (so there's no interactive username/password prompt).
        # It needs admin; self-elevate if this session isn't already elevated.
        $wslOk = $false
        try {
            if (Test-Admin) {
                wsl.exe --install --no-distribution
                $wslOk = ($LASTEXITCODE -eq 0)
            } else {
                Info 'Requesting administrator rights for the WSL2 install...'
                $p = Start-Process -FilePath 'wsl.exe' -ArgumentList '--install','--no-distribution' `
                        -Verb RunAs -Wait -PassThru
                $wslOk = ($p.ExitCode -eq 0)
            }
        } catch {
            Warn ("Could not launch the elevated WSL install: {0}" -f $_.Exception.Message)
        }
        if ($wslOk) {
            Ok 'WSL2 enabled.'
            Warn 'A REBOOT is required before Docker Desktop can use it.'
            Warn 'Reboot Windows, then re-run this script to finish setup.'
            exit 0
        } else {
            Warn 'WSL2 enable did not complete. Open an ADMIN PowerShell and run:'
            Warn '    wsl --install --no-distribution'
            Warn 'then reboot and re-run this script.'
        }
    } else {
        Warn 'Skipped. Docker Desktop will likely fail to start until WSL2 is enabled.'
    }
}

# ---- optional: Tailscale -----------------------------------------------------
if ($NoTailscale) {
    Info 'Skipping the Tailscale step (-NoTailscale).'
} else {
Step 'Tailscale (optional) - reach the tracker from your phone/iPad'
Info 'Tailscale is a free, secure private network. Install it on your PC and phone,'
Info 'sign in to the same account on both, and your phone can open this app at'
Info 'http://<your-pc-name>.ts.net:8088 from anywhere - nothing exposed publicly.'
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
        } else { Warn 'Tailscale install did not complete - see https://tailscale.com/download' }
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
    if ($WebPort -ne 8088)     { Warn ("Port 8088 is busy - using {0} for the app instead." -f $WebPort) }
    if ($BackendPort -ne 8080) { Warn ("Port 8080 is busy - using {0} for the API instead." -f $BackendPort) }
    @("WEB_PORT=$WebPort", "BACKEND_PORT=$BackendPort") | Set-Content -LiteralPath $EnvFile -Encoding ascii
}
$AppUrl = "http://localhost:$WebPort"
Ok ("web -> {0}   |   api -> http://localhost:{1}" -f $AppUrl, $BackendPort)

# ---- bring up Postgres first + verify schema compatibility -------------------
# This stack runs under its own compose project (jobsearch-tracker) with isolated,
# uniquely-named containers and volume, so it never collides with a separate dev
# copy. Start ONLY the database first, so we can read its Flyway history before the
# backend tries to migrate: a volume left over from a NEWER build would make the
# packaged (older) backend's Flyway refuse to start - caught below with a clear note.
Step 'Starting the database'
docker compose --env-file $EnvFile -f $ComposeFile up -d postgres
if ($LASTEXITCODE -ne 0) { Warn 'docker compose up (postgres) failed - see output above.'; exit 1 }

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
# Read the highest applied migration. On a FRESH database the flyway_schema_history
# table does not exist yet (the backend creates it on its first migration), so guard
# with to_regclass() - the query returns 0 instead of raising "relation does not
# exist". Wrap the call so a native nonzero exit / stderr cannot abort the script
# under $ErrorActionPreference='Stop' (PowerShell 7 can turn native stderr into a
# terminating error otherwise).
$dbVer = 0
$schemaSql = "select case when to_regclass('public.flyway_schema_history') is null then 0 else coalesce((select max(version::numeric) from flyway_schema_history where success), 0) end"
try {
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $dbVerRaw = docker exec $DbCid psql -U jobsearch -d jobsearch -tAc $schemaSql 2>$null
    $ErrorActionPreference = $prevEAP
    if ($LASTEXITCODE -eq 0 -and $dbVerRaw) { [void][int]::TryParse(($dbVerRaw | Out-String).Trim(), [ref]$dbVer) }
} catch {
    $dbVer = 0
}

if ($null -eq $expected) {
    Info 'No schema.version shipped with this package - skipping schema check.'
} elseif ($dbVer -eq 0) {
    Ok ("Fresh database - the app will create schema v{0} on first start." -f $expected)
} elseif ($dbVer -gt $expected) {
    Warn ("Existing data is at schema v{0}, but this package only understands v{1}." -f $dbVer, $expected)
    Warn 'This is an OLDER package than the data - starting it could fail or risk your data.'
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
if ($LASTEXITCODE -ne 0) { Warn 'docker compose up failed - see output above.'; exit 1 }

Step 'Waiting for the app to answer'
$up = $false
for ($i = 0; $i -lt 40; $i++) {
    Start-Sleep 3
    try { if ((Invoke-WebRequest "$AppUrl" -UseBasicParsing -TimeoutSec 3).StatusCode -eq 200) { $up = $true; break } } catch {}
}
if ($up) { Ok "App is up at $AppUrl" } else { Warn "App didn't answer yet - give it a minute, then open $AppUrl (check: docker compose logs -f backend)" }

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
