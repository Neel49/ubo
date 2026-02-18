# ubo installer for Windows
# Usage: irm https://raw.githubusercontent.com/neel49/ubo/main/windows/install.ps1 | iex

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$UboDir = "$env:LOCALAPPDATA\ubo"
$Url = "https://raw.githubusercontent.com/neel49/ubo/main/windows/ubo.ps1"

Write-Host "==> Installing ubo..." -ForegroundColor Cyan

# Create directory
New-Item -ItemType Directory -Path $UboDir -Force | Out-Null

# Download ubo.ps1 using WebClient (more reliable than Invoke-WebRequest on PS 5.1)
try {
    (New-Object Net.WebClient).DownloadFile($Url, "$UboDir\ubo.ps1")
}
catch {
    Write-Host "Error: Download failed. $_" -ForegroundColor Red
    exit 1
}

# Create ubo.bat wrapper
Set-Content -Path "$UboDir\ubo.bat" -Value '@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ubo.ps1" %*'

# Add to PATH
$p = [Environment]::GetEnvironmentVariable("Path", "User")
if ($p -notlike "*$UboDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$p;$UboDir", "User")
    $env:Path += ";$UboDir"
    Write-Host "==> Added to PATH" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "==> ubo installed!" -ForegroundColor Green
Write-Host "    Now run: ubo install" -ForegroundColor White
