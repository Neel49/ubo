#Requires -Version 5.1
param(
    [Parameter(Position = 0)]
    [string]$Command = "help"
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- Constants ---
$UboVersion = "0.1.0"
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
    try { return (Get-Item $ChromePath).VersionInfo.FileVersion }
    catch { return "unknown" }
}

# --- Output helpers ---
function Write-Info { param([string]$msg) Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Success { param([string]$msg) Write-Host "==> $msg" -ForegroundColor Green }
function Write-Warn { param([string]$msg) Write-Host "Warning: $msg" -ForegroundColor Yellow }
function Write-Err { param([string]$msg) Write-Host "Error: $msg" -ForegroundColor Red }

# --- Download extension ---
function Get-Extension {
    Write-Info "Fetching latest uBlock Origin release..."
    $apiUrl = "https://api.github.com/repos/$GitHubRepo/releases/latest"
    try {
        $release = Invoke-RestMethod -Uri $apiUrl
    }
    catch {
        Write-Err "Could not fetch release info from GitHub."
        exit 1
    }

    $version = $release.tag_name
    if (-not $version) {
        Write-Err "Could not determine latest version."
        exit 1
    }

    $asset = $release.assets | Where-Object { $_.name -like "*chromium*" -and $_.name -like "*.zip" } | Select-Object -First 1
    if (-not $asset) {
        Write-Err "Could not find chromium zip in release."
        exit 1
    }

    Write-Info "Downloading uBlock Origin $version..."
    New-Item -ItemType Directory -Path $UboDir -Force | Out-Null

    $zipPath = Join-Path $UboDir "ublock0.chromium.zip"
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -UseBasicParsing

    Write-Info "Extracting..."
    $extractTmp = Join-Path $UboDir "_extract_tmp"
    if (Test-Path $extractTmp) { Remove-Item $extractTmp -Recurse -Force }
    if (Test-Path $ExtDir) { Remove-Item $ExtDir -Recurse -Force }

    Expand-Archive -Path $zipPath -DestinationPath $extractTmp -Force

    $extracted = Get-ChildItem -Path $extractTmp -Directory |
        Where-Object { $_.Name -match "ublock.*chromium" } |
        Select-Object -First 1

    if ($extracted) {
        Move-Item -Path $extracted.FullName -Destination $ExtDir
    }
    elseif (Test-Path (Join-Path $extractTmp "manifest.json")) {
        Move-Item -Path $extractTmp -Destination $ExtDir
    }
    else {
        Write-Err "Extraction failed."
        Remove-Item $extractTmp -Recurse -Force -ErrorAction SilentlyContinue
        exit 1
    }
    Remove-Item $extractTmp -Recurse -Force -ErrorAction SilentlyContinue

    if (-not (Test-Path (Join-Path $ExtDir "manifest.json"))) {
        Write-Err "Invalid extension: manifest.json not found."
        exit 1
    }

    Set-Content -Path $VersionFile -Value $version -NoNewline
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    Write-Success "Downloaded uBlock Origin $version"
}

# --- Create shortcuts ---
function New-Shortcuts {
    param([string]$ChromePath)
    $shortcutArgs = "$MV2Flags --load-extension=$ExtDir"
    $WshShell = New-Object -ComObject WScript.Shell

    $desktopLnk = Join-Path $Desktop $ShortcutName
    $s = $WshShell.CreateShortcut($desktopLnk)
    $s.TargetPath = $ChromePath
    $s.Arguments = $shortcutArgs
    $s.IconLocation = "$ChromePath,0"
    $s.Description = "Google Chrome with uBlock Origin (MV2)"
    $s.Save()
    Write-Info "Created Desktop shortcut"

    $startLnk = Join-Path $StartMenu $ShortcutName
    $s2 = $WshShell.CreateShortcut($startLnk)
    $s2.TargetPath = $ChromePath
    $s2.Arguments = $shortcutArgs
    $s2.IconLocation = "$ChromePath,0"
    $s2.Description = "Google Chrome with uBlock Origin (MV2)"
    $s2.Save()
    Write-Info "Created Start Menu shortcut"

    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($WshShell) | Out-Null
}

# --- Install ---
function Invoke-Install {
    Write-Info "ubo installer v$UboVersion"
    Write-Host ""

    $chrome = Find-Chrome
    if (-not $chrome) {
        Write-Err "Google Chrome not found. Install Chrome and try again."
        exit 1
    }
    Write-Info ("Found Chrome " + (Get-ChromeVersion $chrome))

    $chromeProc = Get-Process -Name "chrome" -ErrorAction SilentlyContinue
    if ($chromeProc) {
        Write-Warn "Chrome is running. It must be closed for uBlock Origin to load."
        $closeIt = Read-Host "  Close Chrome now? [Y/n]"
        if ($closeIt -match '^[Nn]$') {
            Write-Warn "You will need to close Chrome manually and relaunch via 'Chrome uBO'."
        }
        else {
            Write-Info "Closing Chrome..."
            Stop-Process -Name "chrome" -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            Write-Success "Chrome closed."
        }
        Write-Host ""
    }

    if ((Test-Path $ExtDir) -and (Test-Path $VersionFile)) {
        $currentVer = Get-Content $VersionFile -Raw
        Write-Warn "uBlock Origin $currentVer is already installed."
        $confirm = Read-Host "  Reinstall? [y/N]"
        if ($confirm -notmatch '^[Yy]$') {
            New-Shortcuts $chrome
            return
        }
    }

    Get-Extension
    New-Shortcuts $chrome

    Write-Host ""
    Write-Success "Installation complete!"
    Write-Host ""
    Write-Host "  Extension path: $ExtDir" -ForegroundColor Gray
    Write-Host ("  manifest.json:  " + (Test-Path (Join-Path $ExtDir "manifest.json"))) -ForegroundColor Gray
    Write-Host ""

    # Auto-launch Chrome with uBlock Origin if Chrome is not running
    $chromeStillRunning = Get-Process -Name "chrome" -ErrorAction SilentlyContinue
    if (-not $chromeStillRunning) {
        Write-Info "Launching Chrome with uBlock Origin..."
        Invoke-Launch
        Write-Host ""
        Write-Host "  Chrome is opening with uBlock Origin loaded."
        Write-Host "  Pin 'Chrome uBO' from your Desktop to your taskbar for easy access."
    }
    else {
        Write-Host "  Next steps:"
        Write-Host "  1. Close Chrome completely"
        Write-Host "  2. Double-click 'Chrome uBO' on your Desktop"
        Write-Host "  3. Pin it to your taskbar"
    }
    Write-Host ""
    Write-Warn "Chrome will show a developer mode dialog on launch. Click Cancel to dismiss."
}

# --- Uninstall ---
function Invoke-Uninstall {
    Write-Info "Uninstalling ubo..."
    $removed = $false

    $desktopLnk = Join-Path $Desktop $ShortcutName
    if (Test-Path $desktopLnk) { Remove-Item $desktopLnk -Force; Write-Host "  Removed Desktop shortcut"; $removed = $true }

    $startLnk = Join-Path $StartMenu $ShortcutName
    if (Test-Path $startLnk) { Remove-Item $startLnk -Force; Write-Host "  Removed Start Menu shortcut"; $removed = $true }

    if (Test-Path $UboDir) { Remove-Item $UboDir -Recurse -Force; Write-Host "  Removed $UboDir"; $removed = $true }

    if (-not $removed) { Write-Host "  Nothing to uninstall."; return }
    Write-Host ""
    Write-Success "ubo has been uninstalled."
}

# --- Status ---
function Invoke-Status {
    Write-Host "ubo status" -ForegroundColor White
    Write-Host ""

    $allGood = $true

    $chrome = Find-Chrome
    if ($chrome) {
        Write-Host ("  [OK] Chrome installed (v" + (Get-ChromeVersion $chrome) + ")") -ForegroundColor Green
    }
    else {
        Write-Host "  [X] Chrome not installed" -ForegroundColor Red
        $allGood = $false
    }

    if ((Test-Path $ExtDir) -and (Test-Path (Join-Path $ExtDir "manifest.json"))) {
        $ver = "unknown"
        if (Test-Path $VersionFile) { $ver = (Get-Content $VersionFile -Raw).Trim() }
        Write-Host "  [OK] uBlock Origin downloaded ($ver)" -ForegroundColor Green
    }
    else {
        Write-Host "  [X] uBlock Origin not downloaded (run 'ubo install')" -ForegroundColor Red
        $allGood = $false
    }

    $desktopLnk = Join-Path $Desktop $ShortcutName
    if (Test-Path $desktopLnk) {
        Write-Host "  [OK] Desktop shortcut exists" -ForegroundColor Green
    }
    else {
        Write-Host "  [X] Desktop shortcut missing (run 'ubo install')" -ForegroundColor Red
        $allGood = $false
    }

    $chromeProc = Get-Process -Name "chrome" -ErrorAction SilentlyContinue
    if ($chromeProc) {
        $hasFlags = $false
        try {
            $proc = Get-CimInstance Win32_Process -Filter "Name='chrome.exe'" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($proc -and $proc.CommandLine -match "ExtensionManifestV2Unsupported") {
                $hasFlags = $true
            }
        }
        catch {}
        if ($hasFlags) {
            Write-Host "  [OK] Chrome running with MV2 flags" -ForegroundColor Green
        }
        else {
            Write-Host "  [!] Chrome running WITHOUT MV2 flags" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "  [--] Chrome not running" -ForegroundColor Gray
    }

    Write-Host ""
    if ($allGood) { Write-Success "Everything looks good!" }
    else { Write-Host "  Run 'ubo install' to fix missing components." }
}

# --- Update ---
function Invoke-Update {
    if (-not (Test-Path $ExtDir)) {
        Write-Err "uBlock Origin not installed. Run 'ubo install' first."
        exit 1
    }

    $currentVer = "unknown"
    if (Test-Path $VersionFile) { $currentVer = (Get-Content $VersionFile -Raw).Trim() }

    Write-Info "Checking for updates..."
    Write-Info "Current: $currentVer"

    try {
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$GitHubRepo/releases/latest"
    }
    catch {
        Write-Err "Could not check for updates."
        exit 1
    }

    $latestVer = $release.tag_name
    Write-Info "Latest:  $latestVer"

    if ($currentVer -eq $latestVer) {
        Write-Success "Already up to date!"
        return
    }

    Write-Info "Updating $currentVer to $latestVer..."

    $asset = $release.assets | Where-Object { $_.name -like "*chromium*" -and $_.name -like "*.zip" } | Select-Object -First 1
    if (-not $asset) { Write-Err "Could not find download."; exit 1 }

    $zipPath = Join-Path $UboDir "ublock0.chromium.zip"
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -UseBasicParsing

    $extractTmp = Join-Path $UboDir "_extract_tmp"
    if (Test-Path $extractTmp) { Remove-Item $extractTmp -Recurse -Force }
    if (Test-Path $ExtDir) { Remove-Item $ExtDir -Recurse -Force }

    Expand-Archive -Path $zipPath -DestinationPath $extractTmp -Force

    $extracted = Get-ChildItem -Path $extractTmp -Directory |
        Where-Object { $_.Name -match "ublock.*chromium" } |
        Select-Object -First 1

    if ($extracted) { Move-Item -Path $extracted.FullName -Destination $ExtDir }
    elseif (Test-Path (Join-Path $extractTmp "manifest.json")) { Move-Item -Path $extractTmp -Destination $ExtDir }

    Remove-Item $extractTmp -Recurse -Force -ErrorAction SilentlyContinue
    Set-Content -Path $VersionFile -Value $latestVer -NoNewline
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

    Write-Success "Updated to $latestVer"
}

# --- Launch ---
function Invoke-Launch {
    $chrome = Find-Chrome
    if (-not $chrome) { Write-Err "Chrome not found."; exit 1 }

    if (Test-Path $ExtDir) {
        Start-Process -FilePath $chrome -ArgumentList $MV2Flags, "--load-extension=$ExtDir"
    }
    else {
        Start-Process -FilePath $chrome -ArgumentList $MV2Flags
    }
}

# --- Help ---
function Show-Help {
    Write-Host "ubo $UboVersion - uBlock Origin installer for Windows Chrome"
    Write-Host ""
    Write-Host "Usage: ubo <command>"
    Write-Host ""
    Write-Host "  install     Download uBlock Origin and create Chrome shortcuts"
    Write-Host "  uninstall   Remove uBlock Origin and shortcuts"
    Write-Host "  status      Check installation status"
    Write-Host "  update      Update uBlock Origin to latest release"
    Write-Host "  launch      Launch Chrome with uBlock Origin"
    Write-Host "  version     Print version"
    Write-Host "  help        Show this help"
}

# --- Main ---
switch ($Command) {
    "install" { Invoke-Install }
    "uninstall" { Invoke-Uninstall }
    "status" { Invoke-Status }
    "update" { Invoke-Update }
    "launch" { Invoke-Launch }
    "version" { Write-Host "ubo $UboVersion" }
    "help" { Show-Help }
    default { Show-Help }
}
