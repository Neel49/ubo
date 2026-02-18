#Requires -Version 5.1
# ubo installer for Windows
# Usage: irm https://raw.githubusercontent.com/neel49/ubo/main/windows/install.ps1 | iex

$ErrorActionPreference = "Stop"
$Repo = "neel49/ubo"
$UboDir = Join-Path $env:LOCALAPPDATA "ubo"
$UboScript = Join-Path $UboDir "ubo.ps1"
$UboBat = Join-Path $UboDir "ubo.bat"

Write-Host "==> Installing ubo..." -ForegroundColor Cyan

# Get latest release
try {
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -UseBasicParsing
    $tag = $release.tag_name
}
catch {
    Write-Host "Error: Could not reach GitHub. Check your internet connection." -ForegroundColor Red
    exit 1
}

Write-Host "==> Latest version: $tag" -ForegroundColor Cyan

# Download and extract
$zipUrl = "https://github.com/$Repo/archive/refs/tags/$tag.zip"
$tmpZip = Join-Path $env:TEMP "ubo-install.zip"
$tmpDir = Join-Path $env:TEMP "ubo-install"

Write-Host "==> Downloading..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $zipUrl -OutFile $tmpZip -UseBasicParsing

if (Test-Path $tmpDir) { Remove-Item $tmpDir -Recurse -Force }
Expand-Archive -Path $tmpZip -DestinationPath $tmpDir -Force

# Find the extracted folder
$extracted = Get-ChildItem -Path $tmpDir -Directory | Select-Object -First 1

# Install ubo.ps1
New-Item -ItemType Directory -Path $UboDir -Force | Out-Null
Copy-Item -Path (Join-Path $extracted.FullName "windows\ubo.ps1") -Destination $UboScript -Force

# Create a ubo.bat wrapper so "ubo" works from cmd and PowerShell
@"
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ubo.ps1" %*
"@ | Out-File -FilePath $UboBat -Encoding ASCII

# Add to PATH if not already there
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($currentPath -notlike "*$UboDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$currentPath;$UboDir", "User")
    Write-Host "==> Added $UboDir to your PATH" -ForegroundColor Cyan
    Write-Host "    You may need to restart your terminal for 'ubo' to work." -ForegroundColor Yellow
}

# Cleanup
Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue
Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "==> ubo installed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "  Now run:" -ForegroundColor White
Write-Host "    ubo install" -ForegroundColor White
Write-Host ""
Write-Host "  This will download uBlock Origin and create Chrome shortcuts."
