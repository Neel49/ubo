#Requires -Version 5.1
<#
.SYNOPSIS
    ubo - One-command uBlock Origin installer for Google Chrome on Windows.
.DESCRIPTION
    Downloads uBlock Origin from GitHub releases and creates a Chrome shortcut
    with MV2 support flags so the extension keeps working.
.EXAMPLE
    .\ubo.ps1 install
    .\ubo.ps1 status
    .\ubo.ps1 update
#>

param(
    [Parameter(Position = 0)]
    [ValidateSet("install", "uninstall", "status", "update", "launch", "version", "help")]
    [string]$Command = "help"
)

$ErrorActionPreference = "Stop"

# --- Constants ---
$UboVersion = "0.1.0"
$ExtId = "cjpalhdlnbpafiamejdnhcphjbkeiagm"
$UboDir = Join-Path $env:LOCALAPPDATA "ubo"
$ExtDir = Join-Path $UboDir "ublock0.chromium"
$VersionFile = Join-Path $UboDir "version"
$GitHubRepo = "gorhill/uBlock"
$MV2Flags = "--disable-features=ExtensionManifestV2Unsupported,ExtensionManifestV2Disabled"

$Desktop = [Environment]::GetFolderPath("Desktop")
$StartMenu = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs"
$ShortcutName = "Chrome uBO.lnk"

# --- Find Chrome ---
function Find-Chrome {
    $paths = @(
        "C:\Program Files\Google\Chrome\Application\chrome.exe",
        "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
        (Join-Path $env:LOCALAPPDATA "Google\Chrome\Application\chrome.exe")
    )

    # Also check registry
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe"
    )
    foreach ($reg in $regPaths) {
        if (Test-Path $reg) {
            $regVal = (Get-ItemProperty $reg -ErrorAction SilentlyContinue).'(default)'
            if ($regVal -and (Test-Path $regVal)) {
                $paths = @($regVal) + $paths
            }
        }
    }

    foreach ($p in $paths) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

function Get-ChromeVersion {
    param([string]$ChromePath)
    try {
        return (Get-Item $ChromePath).VersionInfo.FileVersion
    }
    catch { return "unknown" }
}

# --- Output helpers ---
function Write-Info    { param([string]$msg) Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Success { param([string]$msg) Write-Host "==> $msg" -ForegroundColor Green }
function Write-Warn    { param([string]$msg) Write-Host "Warning: $msg" -ForegroundColor Yellow }
function Write-Err     { param([string]$msg) Write-Host "Error: $msg" -ForegroundColor Red }

# --- Install ---
function Invoke-Install {
    Write-Info "ubo installer v$UboVersion"
    Write-Host ""

    # 1. Find Chrome
    $chrome = Find-Chrome
    if (-not $chrome) {
        Write-Err "Google Chrome not found."
        Write-Host "  Install Chrome from https://google.com/chrome and try again."
        exit 1
    }
    $chromeVer = Get-ChromeVersion $chrome
    Write-Info "Found Chrome $chromeVer at $chrome"

    # 2. Check internet
    try {
        $null = Invoke-RestMethod -Uri "https://api.github.com" -Method Head -TimeoutSec 5
    }
    catch {
        Write-Err "Cannot reach GitHub. Check your internet connection."
        exit 1
    }

    # 3. Warn if Chrome is running
    $chromeProc = Get-Process -Name "chrome" -ErrorAction SilentlyContinue
    if ($chromeProc) {
        Write-Warn "Chrome is currently running."
        Write-Host "  You'll need to close Chrome and relaunch via 'Chrome uBO' shortcut for changes to take effect."
        Write-Host ""
    }

    # 4. Check existing install
    if ((Test-Path $ExtDir) -and (Test-Path $VersionFile)) {
        $currentVer = Get-Content $VersionFile -Raw
        Write-Warn "uBlock Origin $currentVer is already installed."
        $confirm = Read-Host "  Reinstall? [y/N]"
        if ($confirm -notmatch '^[Yy]$') {
            Write-Host "  Skipping download. Checking shortcuts..."
            New-Shortcuts $chrome
            return
        }
    }

    # 5. Download extension
    Get-Extension

    # 6. Create shortcuts
    New-Shortcuts $chrome

    # 7. Success
    Write-Host ""
    Write-Success "Installation complete!"
    Write-Host ""
    Write-Host "  uBlock Origin: $(Get-Content $VersionFile -Raw)"
    Write-Host "  Extension:     $ExtDir"
    Write-Host "  Shortcut:      $Desktop\$ShortcutName"
    Write-Host ""
    Write-Host "  Next steps:" -ForegroundColor White
    Write-Host "  1. Close Chrome completely if it's running"
    Write-Host "  2. Double-click 'Chrome uBO' on your Desktop"
    Write-Host "  3. Pin it to your taskbar for easy access"
    Write-Host ""
    Write-Host "  Note: Chrome will show a 'developer mode extensions' dialog on launch." -ForegroundColor Yellow
    Write-Host "  Just click the X or 'Cancel' to dismiss it. This is expected."
}

function Get-Extension {
    Write-Info "Fetching latest uBlock Origin release..."

    $apiUrl = "https://api.github.com/repos/$GitHubRepo/releases/latest"
    try {
        $release = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing
    }
    catch {
        Write-Err "Could not fetch release info. GitHub API may be rate-limited."
        exit 1
    }

    $version = $release.tag_name
    if (-not $version) {
        Write-Err "Could not determine latest version."
        exit 1
    }

    # Find the chromium zip asset
    $asset = $release.assets | Where-Object { $_.name -like "*chromium*" -and $_.name -like "*.zip" } | Select-Object -First 1
    if (-not $asset) {
        Write-Err "Could not find ublock0.chromium.zip in the latest release."
        exit 1
    }

    Write-Info "Downloading uBlock Origin $version..."
    New-Item -ItemType Directory -Path $UboDir -Force | Out-Null

    $zipPath = Join-Path $UboDir "ublock0.chromium.zip"
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -UseBasicParsing

    # Extract
    Write-Info "Extracting..."
    $extractTmp = Join-Path $UboDir "_extract_tmp"
    if (Test-Path $extractTmp) { Remove-Item $extractTmp -Recurse -Force }
    if (Test-Path $ExtDir) { Remove-Item $ExtDir -Recurse -Force }

    Expand-Archive -Path $zipPath -DestinationPath $extractTmp -Force

    # Find the extension directory (case-insensitive)
    $extracted = Get-ChildItem -Path $extractTmp -Directory | Where-Object { $_.Name -match "ublock.*chromium" } | Select-Object -First 1
    if ($extracted) {
        Move-Item -Path $extracted.FullName -Destination $ExtDir
    }
    elseif (Test-Path (Join-Path $extractTmp "manifest.json")) {
        Move-Item -Path $extractTmp -Destination $ExtDir
    }
    else {
        Write-Err "Extraction failed: could not find extension directory."
        Remove-Item $extractTmp -Recurse -Force -ErrorAction SilentlyContinue
        exit 1
    }

    Remove-Item $extractTmp -Recurse -Force -ErrorAction SilentlyContinue

    # Verify
    if (-not (Test-Path (Join-Path $ExtDir "manifest.json"))) {
        Write-Err "Invalid extension: manifest.json not found."
        exit 1
    }

    # Save version
    $version | Out-File -FilePath $VersionFile -Encoding UTF8 -NoNewline

    # Cleanup zip
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

    Write-Success "Downloaded uBlock Origin $version"
}

function New-Shortcuts {
    param([string]$ChromePath)

    $arguments = "$MV2Flags --load-extension=`"$ExtDir`""

    $WshShell = New-Object -ComObject WScript.Shell

    # Desktop shortcut
    $desktopLnk = Join-Path $Desktop $ShortcutName
    $shortcut = $WshShell.CreateShortcut($desktopLnk)
    $shortcut.TargetPath = $ChromePath
    $shortcut.Arguments = $arguments
    $shortcut.IconLocation = "$ChromePath,0"
    $shortcut.Description = "Google Chrome with uBlock Origin (MV2)"
    $shortcut.Save()
    Write-Info "Created Desktop shortcut: $desktopLnk"

    # Start Menu shortcut
    $startLnk = Join-Path $StartMenu $ShortcutName
    $shortcut2 = $WshShell.CreateShortcut($startLnk)
    $shortcut2.TargetPath = $ChromePath
    $shortcut2.Arguments = $arguments
    $shortcut2.IconLocation = "$ChromePath,0"
    $shortcut2.Description = "Google Chrome with uBlock Origin (MV2)"
    $shortcut2.Save()
    Write-Info "Created Start Menu shortcut: $startLnk"

    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($WshShell) | Out-Null
}

# --- Uninstall ---
function Invoke-Uninstall {
    Write-Info "Uninstalling ubo..."
    Write-Host ""

    $removed = $false

    # Remove shortcuts
    $desktopLnk = Join-Path $Desktop $ShortcutName
    if (Test-Path $desktopLnk) {
        Remove-Item $desktopLnk -Force
        Write-Host "  Removed $desktopLnk"
        $removed = $true
    }

    $startLnk = Join-Path $StartMenu $ShortcutName
    if (Test-Path $startLnk) {
        Remove-Item $startLnk -Force
        Write-Host "  Removed $startLnk"
        $removed = $true
    }

    # Remove extension data
    if (Test-Path $UboDir) {
        Remove-Item $UboDir -Recurse -Force
        Write-Host "  Removed $UboDir"
        $removed = $true
    }

    if (-not $removed) {
        Write-Host "  Nothing to uninstall."
        return
    }

    Write-Host ""
    Write-Success "ubo has been uninstalled."
    Write-Host ""
    Write-Host "  Note: If uBlock Origin was loaded in a Chrome session, it will"
    Write-Host "  disappear next time you restart Chrome normally."
}

# --- Status ---
function Invoke-Status {
    Write-Host "ubo status" -ForegroundColor White
    Write-Host ""

    $allGood = $true

    # Chrome
    $chrome = Find-Chrome
    if ($chrome) {
        $ver = Get-ChromeVersion $chrome
        Write-Host "  ✓ Chrome installed (v$ver)" -ForegroundColor Green
    }
    else {
        Write-Host "  ✗ Chrome not installed" -ForegroundColor Red
        $allGood = $false
    }

    # Extension downloaded
    if ((Test-Path $ExtDir) -and (Test-Path (Join-Path $ExtDir "manifest.json"))) {
        $ver = if (Test-Path $VersionFile) { Get-Content $VersionFile -Raw } else { "unknown" }
        Write-Host "  ✓ uBlock Origin downloaded ($ver)" -ForegroundColor Green
    }
    else {
        Write-Host "  ✗ uBlock Origin not downloaded (run 'ubo install')" -ForegroundColor Red
        $allGood = $false
    }

    # Desktop shortcut
    $desktopLnk = Join-Path $Desktop $ShortcutName
    if (Test-Path $desktopLnk) {
        Write-Host "  ✓ Desktop shortcut exists" -ForegroundColor Green
    }
    else {
        Write-Host "  ✗ Desktop shortcut not found (run 'ubo install')" -ForegroundColor Red
        $allGood = $false
    }

    # Start Menu shortcut
    $startLnk = Join-Path $StartMenu $ShortcutName
    if (Test-Path $startLnk) {
        Write-Host "  ✓ Start Menu shortcut exists" -ForegroundColor Green
    }
    else {
        Write-Host "  ✗ Start Menu shortcut not found (run 'ubo install')" -ForegroundColor Red
        $allGood = $false
    }

    # Chrome running with flags?
    $chromeProc = Get-Process -Name "chrome" -ErrorAction SilentlyContinue
    if ($chromeProc) {
        try {
            $cmdLine = (Get-CimInstance Win32_Process -Filter "Name='chrome.exe'" -ErrorAction SilentlyContinue |
                Select-Object -First 1).CommandLine
            if ($cmdLine -and $cmdLine -match "ExtensionManifestV2Unsupported") {
                Write-Host "  ✓ Chrome running with MV2 flags" -ForegroundColor Green
            }
            else {
                Write-Host "  ! Chrome running WITHOUT MV2 flags (relaunch via 'Chrome uBO')" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "  · Chrome running (could not check flags)" -ForegroundColor Blue
        }
    }
    else {
        Write-Host "  · Chrome not running" -ForegroundColor Blue
    }

    Write-Host ""
    if ($allGood) {
        Write-Success "Everything looks good!"
    }
    else {
        Write-Host "  Run 'ubo install' to fix missing components."
    }
}

# --- Update ---
function Invoke-Update {
    if (-not (Test-Path $ExtDir)) {
        Write-Err "uBlock Origin is not installed. Run 'ubo install' first."
        exit 1
    }

    $currentVer = if (Test-Path $VersionFile) { (Get-Content $VersionFile -Raw).Trim() } else { "unknown" }

    Write-Info "Checking for updates..."
    Write-Info "Current version: $currentVer"

    try {
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$GitHubRepo/releases/latest" -UseBasicParsing
    }
    catch {
        Write-Err "Could not check latest version. GitHub API may be rate-limited."
        exit 1
    }

    $latestVer = $release.tag_name
    Write-Info "Latest version:  $latestVer"

    if ($currentVer -eq $latestVer) {
        Write-Success "Already up to date!"
        return
    }

    Write-Host ""
    Write-Info "Updating $currentVer → $latestVer..."

    $asset = $release.assets | Where-Object { $_.name -like "*chromium*" -and $_.name -like "*.zip" } | Select-Object -First 1
    if (-not $asset) {
        Write-Err "Could not find download URL for latest release."
        exit 1
    }

    $zipPath = Join-Path $UboDir "ublock0.chromium.zip"
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -UseBasicParsing

    # Extract with same normalization logic
    $extractTmp = Join-Path $UboDir "_extract_tmp"
    if (Test-Path $extractTmp) { Remove-Item $extractTmp -Recurse -Force }
    if (Test-Path $ExtDir) { Remove-Item $ExtDir -Recurse -Force }

    Expand-Archive -Path $zipPath -DestinationPath $extractTmp -Force

    $extracted = Get-ChildItem -Path $extractTmp -Directory | Where-Object { $_.Name -match "ublock.*chromium" } | Select-Object -First 1
    if ($extracted) {
        Move-Item -Path $extracted.FullName -Destination $ExtDir
    }
    elseif (Test-Path (Join-Path $extractTmp "manifest.json")) {
        Move-Item -Path $extractTmp -Destination $ExtDir
    }

    Remove-Item $extractTmp -Recurse -Force -ErrorAction SilentlyContinue
    $latestVer | Out-File -FilePath $VersionFile -Encoding UTF8 -NoNewline
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Success "Updated to uBlock Origin $latestVer"

    $chromeProc = Get-Process -Name "chrome" -ErrorAction SilentlyContinue
    if ($chromeProc) {
        Write-Host ""
        Write-Warn "Chrome is running. Close and reopen via 'Chrome uBO' shortcut to load the update."
    }
}

# --- Launch ---
function Invoke-Launch {
    $chrome = Find-Chrome
    if (-not $chrome) {
        Write-Err "Chrome not found."
        exit 1
    }

    $args = $MV2Flags
    if (Test-Path $ExtDir) {
        $args += " --load-extension=`"$ExtDir`""
    }

    Start-Process -FilePath $chrome -ArgumentList $args
}

# --- Help ---
function Show-Help {
    Write-Host @"
ubo $UboVersion - uBlock Origin installer for Windows Chrome

Usage: ubo <command>

Commands:
  install     Download uBlock Origin and create Chrome shortcuts
  uninstall   Remove uBlock Origin and shortcuts
  status      Check installation status
  update      Update uBlock Origin to latest release
  launch      Launch Chrome with uBlock Origin and MV2 support
  version     Print version
  help        Show this help

Examples:
  ubo install     # Set up everything
  ubo status      # Check if it's working
  ubo update      # Get the latest uBlock Origin
"@
}

# --- Main ---
switch ($Command) {
    "install"   { Invoke-Install }
    "uninstall" { Invoke-Uninstall }
    "status"    { Invoke-Status }
    "update"    { Invoke-Update }
    "launch"    { Invoke-Launch }
    "version"   { Write-Host "ubo $UboVersion" }
    "help"      { Show-Help }
    default     { Show-Help }
}
