#Requires -Version 5.1
# ubo installer for Windows
# Usage: irm https://raw.githubusercontent.com/neel49/ubo/main/windows/install.ps1 | iex

$ErrorActionPreference = "Stop"

# Force TLS 1.2 (PowerShell 5.1 defaults to TLS 1.0 which GitHub rejects)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$UboDir = Join-Path $env:LOCALAPPDATA "ubo"
$UboScript = Join-Path $UboDir "ubo.ps1"
$UboBat = Join-Path $UboDir "ubo.bat"
$ScriptUrl = "https://raw.githubusercontent.com/neel49/ubo/main/windows/ubo.ps1"

Write-Host "==> Installing ubo..." -ForegroundColor Cyan

# Download ubo.ps1 directly (no API call needed)
New-Item -ItemType Directory -Path $UboDir -Force | Out-Null

try {
    Invoke-WebRequest -Uri $ScriptUrl -OutFile $UboScript -UseBasicParsing
}
catch {
    Write-Host "Error: Could not download ubo. Check your internet connection." -ForegroundColor Red
    Write-Host "  URL: $ScriptUrl" -ForegroundColor Red
    exit 1
}

# Create a ubo.bat wrapper so "ubo" works from cmd and PowerShell
@"
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ubo.ps1" %*
"@ | Out-File -FilePath $UboBat -Encoding ASCII

# Add to PATH if not already there
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($currentPath -notlike "*$UboDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$currentPath;$UboDir", "User")
    # Also update current session so ubo works immediately
    $env:Path = "$env:Path;$UboDir"
    Write-Host "==> Added $UboDir to your PATH" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "==> ubo installed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "  Now run:" -ForegroundColor White
Write-Host "    ubo install" -ForegroundColor White
Write-Host ""
Write-Host "  This will download uBlock Origin and create Chrome shortcuts."
