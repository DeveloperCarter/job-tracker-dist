<#
.SYNOPSIS
    One-step installer for the Job Search Tracker (recipient side).
    Ensures Git + Git LFS are present, clones the distribution repo, and starts
    the app - i.e. it wraps:

        git clone <repo>
        cd <repo>
        ./bootstrap.ps1

.DESCRIPTION
    This is the very first thing your friend runs. They don't need anything
    installed beforehand - this script:
      1. Makes sure Git is installed (installs it via winget if missing).
      2. Makes sure Git LFS is installed and initialized. This is REQUIRED:
         the app's Docker images ship through LFS, so a plain `git clone`
         without LFS would download tiny pointer files and the app wouldn't
         start. We install LFS BEFORE cloning so the images come down for real.
      3. Clones the distribution repo (or fast-forwards it if already cloned).
      4. Runs bootstrap.ps1 from inside it to start everything.

    Easiest way to run it (PowerShell), no manual download needed:

        irm https://raw.githubusercontent.com/DeveloperCarter/job-tracker-dist/main/install.ps1 | iex

    Or, if you saved this file, allow it to run for this one session:

        powershell -ExecutionPolicy Bypass -File .\install.ps1

.PARAMETER Dir
    Folder to clone into (created if needed). Default: job-tracker-dist in the
    current directory.

.PARAMETER RepoUrl
    Distribution repo to clone. Default: the published Job Search Tracker repo.

.PARAMETER NoStart
    Clone/update only; don't run bootstrap.ps1 afterwards.
#>
[CmdletBinding()]
param(
    [string]$Dir     = 'job-tracker-dist',
    [string]$RepoUrl = 'https://github.com/DeveloperCarter/job-tracker-dist',
    [switch]$NoStart
)

$ErrorActionPreference = 'Stop'

function Step($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "    $m" -ForegroundColor Green }
function Warn($m) { Write-Host "    $m" -ForegroundColor Yellow }
function Info($m) { Write-Host "    $m" -ForegroundColor Gray }
function Die($m)  { Write-Host "ERROR: $m" -ForegroundColor Red; exit 1 }

# After a winget install, the new tool isn't on PATH in this already-running
# shell. Rebuild PATH from the machine + user environment so we can use it now.
function Update-PathFromEnvironment {
    $machine = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user    = [System.Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = (@($machine, $user) | Where-Object { $_ }) -join ';'
}

function Test-Cmd([string]$name) { [bool](Get-Command $name -ErrorAction SilentlyContinue) }

function Install-WithWinget([string]$id, [string]$label) {
    if (-not (Test-Cmd 'winget')) {
        Die "winget (Windows Package Manager) isn't available, so $label can't be auto-installed. Install $label manually, then re-run."
    }
    Step "Installing $label (winget id: $id)"
    Info 'A Windows UAC prompt may appear - that is expected.'
    winget install --id $id -e --source winget --accept-source-agreements --accept-package-agreements
    # winget exit codes vary; verify by capability rather than trusting the code.
    Update-PathFromEnvironment
}

Write-Host '====================================================================' -ForegroundColor Cyan
Write-Host ' Job Search Tracker - installer' -ForegroundColor Cyan
Write-Host '====================================================================' -ForegroundColor Cyan

# ---- 1. ensure Git -----------------------------------------------------------
Step 'Checking for Git'
if (Test-Cmd 'git') {
    Ok "Git present ($((git --version)))"
} else {
    Warn 'Git not found - installing.'
    Install-WithWinget 'Git.Git' 'Git'
    if (-not (Test-Cmd 'git')) {
        Die 'Git still not found after install. Close this window, open a NEW PowerShell, and run the installer again.'
    }
    Ok "Git installed ($((git --version)))"
}

# ---- 2. ensure Git LFS (required for the app images) -------------------------
Step 'Checking for Git LFS'
& git lfs version *> $null
if ($LASTEXITCODE -eq 0) {
    Ok "Git LFS present ($((git lfs version)))"
} else {
    Warn 'Git LFS not found - installing (the app images need it).'
    Install-WithWinget 'GitHub.GitLFS' 'Git LFS'
    & git lfs version *> $null
    if ($LASTEXITCODE -ne 0) {
        Die 'Git LFS still not found after install. Close this window, open a NEW PowerShell, and run the installer again.'
    }
    Ok "Git LFS installed ($((git lfs version)))"
}
# Initialize LFS for the current user so clone smudges real files (idempotent).
& git lfs install *> $null

# ---- 3. clone (or update) the distribution repo ------------------------------
$target = Join-Path (Get-Location) $Dir
if (Test-Path (Join-Path $target '.git')) {
    Step "Updating existing clone ($Dir)"
    git -C $target pull --ff-only
    if ($LASTEXITCODE -ne 0) { Warn 'Could not fast-forward - using the existing checkout as-is.' }
    git -C $target lfs pull
} elseif (Test-Path $target) {
    Die "'$target' exists but isn't a git checkout. Move/rename it, then re-run."
} else {
    Step "Cloning $RepoUrl"
    git clone $RepoUrl $target
    if ($LASTEXITCODE -ne 0) { Die 'git clone failed - check your internet connection and the repo URL.' }
    Ok "cloned into $target"
}

# Sanity: confirm the LFS images came down as real files, not pointers.
$backendTar = Join-Path $target 'images\jobsearch-backend.tar'
if (Test-Path $backendTar) {
    $size = (Get-Item $backendTar).Length
    if ($size -lt 1MB) {
        Warn ("The app image looks like an unresolved LFS pointer ({0} bytes)." -f $size)
        Info 'Fetching the real images now (git lfs pull)...'
        git -C $target lfs pull
    }
}

# ---- 4. start the app --------------------------------------------------------
if ($NoStart) {
    Ok "Done. To start the app:  cd `"$target`"  then  ./bootstrap.ps1"
    exit 0
}

$bootstrap = Join-Path $target 'bootstrap.ps1'
if (-not (Test-Path $bootstrap)) { Die "bootstrap.ps1 not found in the clone ($bootstrap)." }

Step 'Starting the app (bootstrap.ps1)'
Set-Location $target
& $bootstrap
