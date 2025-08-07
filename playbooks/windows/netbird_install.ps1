# Variables
$setupKey = "860FFC85-4995-452D-B0DB-0B8ACC661779"  # Replace with your actual setup/auth key
$netbirdExePath = "C:\Program Files\Netbird\netbird.exe"

# Fetch latest NetBird release info from GitHub API
Write-Host "Fetching latest NetBird release info..."
$release = Invoke-RestMethod -Uri https://api.github.com/repos/netbirdio/netbird/releases/latest

# Find the Windows amd64 installer asset
$asset = $release.assets | Where-Object { $_.name -match 'netbird_installer_.*_windows_amd64\.exe' } | Select-Object -First 1

if (-not $asset) {
    Write-Error "No suitable NetBird installer found in the latest release."
    exit 1
}

$downloadUrl = $asset.browser_download_url
$installerPath = Join-Path $env:TEMP $asset.name

# Download installer
Write-Host "Downloading NetBird installer from: $downloadUrl"
Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath

# Install NetBird silently
Write-Host "Installing NetBird silently..."
Start-Process -FilePath $installerPath -ArgumentList "/S" -Wait

# Cleanup installer file
Write-Host "Cleaning up installer..."
Remove-Item $installerPath -Force

# Connect to network using 'join' command and auth key
Write-Host "Connecting NetBird to network with join command..."
$joinCommand = "& `"$netbirdExePath`" join --authkey $setupKey"
Write-Host "Running: $joinCommand"
Invoke-Expression $joinCommand 4>&1 | Tee-Object -Variable output
Write-Host "Output:`n$output"

if ($LASTEXITCODE -ne 0) {
    Write-Error "NetBird join command failed with exit code $LASTEXITCODE"
    exit 1
}

Write-Host "NetBird connected successfully."

# Optional: Add NetBird to auto-start with Windows
Write-Host "Setting NetBird to start automatically on system startup..."
$taskName = "NetBird Auto Start"

# Check if task exists
$taskExists = (schtasks /query /tn $taskName -ErrorAction SilentlyContinue) -ne $null

if (-not $taskExists) {
    schtasks /create /tn $taskName /tr "`"$netbirdExePath`" daemon" /sc onlogon /ru SYSTEM /rl HIGHEST
    Write-Host "Scheduled task created for NetBird auto-start."
} else {
    Write-Host "Scheduled task for NetBird auto-start already exists."
}

Write-Host "NetBird installation and configuration completed."
exit 0
