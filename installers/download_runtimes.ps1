# Download and extract bundled Python + Bun runtimes for Windows.
#
# Usage:
#   .\download_runtimes.ps1 -TargetDir <path>
#
# Optional parameters:
#   -PythonBuildTag   python-build-standalone release tag  (default: 20260303)
#   -PythonVersion    CPython version                       (default: 3.12.13)
#   -BunVersion       Bun version                           (default: latest)

param(
    [Parameter(Mandatory)][string]$TargetDir,
    [string]$PythonBuildTag = "20260303",
    [string]$PythonVersion  = "3.12.13",
    [string]$BunVersion     = "latest"
)

$ErrorActionPreference = "Stop"

# PS 5.1-compatible download with retry (MaximumRetryCount requires PS 6+)
function Invoke-DownloadWithRetry {
    param(
        [string]$Uri,
        [string]$OutFile,
        [int]$MaxRetries = 3
    )
    for ($i = 1; $i -le ($MaxRetries + 1); $i++) {
        try {
            Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing
            return
        } catch {
            if ($i -gt $MaxRetries) { throw }
            Write-Host "  Retry $i/$MaxRetries ..."
            Start-Sleep -Seconds (2 * $i)
        }
    }
}

$PythonBaseUrl = "https://github.com/astral-sh/python-build-standalone/releases/download/$PythonBuildTag"
$BunBaseUrl    = "https://github.com/oven-sh/bun/releases"

# Resolve filenames
$PythonTriple   = "x86_64-pc-windows-msvc"
$PythonFilename = "cpython-${PythonVersion}+${PythonBuildTag}-${PythonTriple}-install_only.tar.gz"
$PythonUrl      = "$PythonBaseUrl/$PythonFilename"

if ($BunVersion -eq "latest") {
    $BunUrl = "$BunBaseUrl/latest/download/bun-windows-x64.zip"
} else {
    $BunUrl = "$BunBaseUrl/download/bun-v${BunVersion}/bun-windows-x64.zip"
}

New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null

# ── Download & extract Python ─────────────────────────────────

Write-Host "-> Downloading Python $PythonVersion (windows-x64) ..."
$TmpPython = New-TemporaryFile
$TmpPythonGz = "$TmpPython.tar.gz"
Rename-Item $TmpPython $TmpPythonGz
Invoke-DownloadWithRetry -Uri $PythonUrl -OutFile $TmpPythonGz

Write-Host "-> Extracting Python to $TargetDir\python ..."
$PythonDir = Join-Path $TargetDir "python"
New-Item -ItemType Directory -Force -Path $PythonDir | Out-Null

# tar on Windows can handle .tar.gz
tar -xzf $TmpPythonGz -C $PythonDir --strip-components=1
Remove-Item $TmpPythonGz -Force

$PythonBin = Join-Path $PythonDir "python.exe"
if (-Not (Test-Path $PythonBin)) {
    Write-Error "Python binary not found at $PythonBin"
    Get-ChildItem $PythonDir | Format-Table
    exit 1
}
$pyVer = & $PythonBin --version 2>&1
Write-Host "  OK Python: $pyVer"

# ── Download & extract Bun ────────────────────────────────────

Write-Host "-> Downloading Bun (windows-x64) ..."
$TmpBun = New-TemporaryFile
$TmpBunZip = "$TmpBun.zip"
Rename-Item $TmpBun $TmpBunZip
Invoke-DownloadWithRetry -Uri $BunUrl -OutFile $TmpBunZip

Write-Host "-> Extracting Bun to $TargetDir\bun ..."
$BunDir = Join-Path $TargetDir "bun"
New-Item -ItemType Directory -Force -Path $BunDir | Out-Null

$TmpExtract = Join-Path ([System.IO.Path]::GetTempPath()) "bun_extract"
if (Test-Path $TmpExtract) { Remove-Item $TmpExtract -Recurse -Force }
Expand-Archive -Path $TmpBunZip -DestinationPath $TmpExtract -Force

# Find bun.exe in extracted contents
$BunExe = Get-ChildItem -Path $TmpExtract -Recurse -Filter "bun.exe" | Select-Object -First 1
if (-Not $BunExe) {
    Write-Error "bun.exe not found in extracted archive"
    exit 1
}
Copy-Item $BunExe.FullName (Join-Path $BunDir "bun.exe") -Force
Remove-Item $TmpBunZip -Force
Remove-Item $TmpExtract -Recurse -Force

$BunBin = Join-Path $BunDir "bun.exe"
$bunVer = & $BunBin --version 2>&1
Write-Host "  OK Bun: $bunVer"

# ── Install agent-browser via Bun ─────────────────────────────
# Pre-install agent-browser (Playwright-based browser automation CLI) so that
# the application works out-of-the-box without requiring users to run npm/bun
# install manually. Playwright's own browser download is skipped — the app
# will auto-detect and use the system Chrome/Edge at runtime.

Write-Host "-> Installing agent-browser via bundled Bun ..."
$AbDir = Join-Path $TargetDir "agent-browser"
New-Item -ItemType Directory -Force -Path $AbDir | Out-Null

# Create minimal package.json
$PkgJson = '{ "name": "deskclaw-agent-browser", "private": true }'
Set-Content -Path (Join-Path $AbDir "package.json") -Value $PkgJson

# Skip Playwright browser downloads — we use the system browser at runtime
$env:PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1"
$env:PLAYWRIGHT_BROWSERS_PATH = "0"
& $BunBin add --cwd $AbDir agent-browser 2>&1 | Select-Object -Last 5

# Locate the entry point
$AbEntry = Get-ChildItem -Path (Join-Path $AbDir "node_modules\agent-browser") -Recurse -Include "cli.js","index.js","agent-browser.js" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-Not $AbEntry) {
    # Fallback: look for the bin link
    $AbBinLink = Join-Path $AbDir "node_modules\.bin\agent-browser"
    if (Test-Path $AbBinLink) {
        $AbEntry = Get-Item $AbBinLink
    }
}

if ($AbEntry) {
    $AbEntryRel = [System.IO.Path]::GetRelativePath($AbDir, $AbEntry.FullName)

    # Create a .cmd wrapper for Windows
    $WrapperContent = @"
@echo off
REM Auto-generated wrapper — launches agent-browser with the bundled Bun runtime
REM and auto-detected system browser. Do not edit manually.
set "SCRIPT_DIR=%~dp0"
set "RUNTIMES_DIR=%SCRIPT_DIR%.."
set "BUN=%RUNTIMES_DIR%\bun\bun.exe"

REM Auto-detect system Chrome/Edge for Playwright
if not defined PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH (
    if exist "C:\Program Files\Google\Chrome\Application\chrome.exe" (
        set "PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=C:\Program Files\Google\Chrome\Application\chrome.exe"
    ) else if exist "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe" (
        set "PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
    ) else if exist "C:\Program Files\Microsoft\Edge\Application\msedge.exe" (
        set "PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=C:\Program Files\Microsoft\Edge\Application\msedge.exe"
    ) else if exist "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" (
        set "PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
    )
)

"%BUN%" "%SCRIPT_DIR%$AbEntryRel" %*
"@
    Set-Content -Path (Join-Path $AbDir "agent-browser.cmd") -Value $WrapperContent

    $abVer = & (Join-Path $AbDir "agent-browser.cmd") --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  OK agent-browser: $abVer"
    } else {
        Write-Host "  OK agent-browser: installed (version check skipped)"
    }
} else {
    Write-Warning "Could not locate agent-browser entry point, browser automation may not work"
}

# Clean up env vars
Remove-Item Env:\PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD -ErrorAction SilentlyContinue
Remove-Item Env:\PLAYWRIGHT_BROWSERS_PATH -ErrorAction SilentlyContinue

# ── Summary ───────────────────────────────────────────────────

Write-Host ""
Write-Host "Runtimes installed to $TargetDir"
Write-Host "Done."
