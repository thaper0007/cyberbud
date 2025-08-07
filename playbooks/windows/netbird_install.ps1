# Fetch the latest NetBird release asset via GitHub API
Write-Host "Fetching latest NetBird release info..."
$release = Invoke-RestMethod -Uri https://api.github.com/repos/netbirdio/netbird/releases/latest
$asset = $release.assets | Where-Object { $_.name -match 'netbird_installer_.*_windows_amd64\.exe' } | Select-Object -First 1

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

Write-Host "Cleaning up installer..."
Remove-Item $installerPath -Force

# Connect/login NetBird with auth key
$netbirdExe = "C:\Program Files\Netbird\netbird.exe"
$authKey = "860FFC85-4995-452D-B0DB-0B8ACC661779"

Write-Host "Connecting NetBird to network with login command..."
$cmd = "& `"$netbirdExe`" login --authkey $authKey"

Write-Host "Running: $cmd"
Invoke-Expression $cmd

if ($LASTEXITCODE -ne 0) {
    Write-Error "NetBird login command failed with exit code $LASTEXITCODE"
    exit 1
}

Write-Host "NetBird login successful."

# Optional: Add scheduled task for auto-start on reboot & user login

$action = New-ScheduledTaskAction -Execute $netbirdExe -Argument "daemon"
$trigger1 = New-ScheduledTaskTrigger -AtLogon
$trigger2 = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

$taskName = "NetBirdAutoStart"

if (-not (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue)) {
    Register-ScheduledTask -Action $action -Trigger $trigger1, $trigger2 -Principal $principal -TaskName $taskName -Description "Auto start NetBird daemon on reboot and user login"
    Write-Host "Scheduled task '$taskName' created."
} else {
    Write-Host "Scheduled task '$taskName' already exists."
}

Write-Host "NetBird installation and setup complete."
exit 0
