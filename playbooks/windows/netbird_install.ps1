# Existing code to download and install NetBird
$release = Invoke-RestMethod -Uri https://api.github.com/repos/netbirdio/netbird/releases/latest
$asset = $release.assets | Where-Object { $_.name -match 'netbird_installer_.*_windows_amd64\.exe' } | Select -First 1

if (-not $asset) {
  Write-Error "No suitable NetBird installer found in the latest release."
  exit 1
}

$downloadUrl = $asset.browser_download_url
$installerPath = Join-Path $env:TEMP $asset.name

Write-Host "Downloading NetBird from: $downloadUrl"
Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath

Write-Host "Installing NetBird silently..."
Start-Process -FilePath $installerPath -ArgumentList "/S" -Wait

Write-Host "Cleaning up..."
Remove-Item $installerPath -Force

Write-Host "NetBird installation complete."

# **New part:** Connect NetBird to network using setup key
$netbirdExe = "C:\Program Files\Netbird\netbird.exe"
$setupKey = "645A7BD2-CFD7-4173-8EB9-C00A5D0A7FBE"

Write-Host "Connecting NetBird to network..."
& $netbirdExe connect --url https://netbird.cyberbud.ca --authkey $setupKey

Write-Host "NetBird connected successfully."
