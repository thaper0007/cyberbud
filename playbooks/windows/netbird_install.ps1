# --- Download and install NetBird ---

# Fetch latest release info from GitHub API
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

Write-Host "Cleaning up installer..."
Remove-Item $installerPath -Force

# --- Connect NetBird to network ---

Start-Sleep -Seconds 10  # Wait a bit for install to settle

$netbirdExe = "C:\Program Files\Netbird\netbird.exe"
$setupKey = "860FFC85-4995-452D-B0DB-0B8ACC661779"

if (-not (Test-Path $netbirdExe)) {
    Write-Error "NetBird executable not found at $netbirdExe"
    exit 1
}

Write-Host "Connecting NetBird to network..."
$connectCommand = "& `"$netbirdExe`" connect --url https://netbird.cyberbud.ca --authkey $setupKey"
Write-Host "Running: $connectCommand"
Invoke-Expression $connectCommand 4>&1 | Tee-Object -Variable output
Write-Host "Output:`n$output"

if ($LASTEXITCODE -ne 0) {
    Write-Error "NetBird connect command failed with exit code $LASTEXITCODE"
    exit 1
}

Write-Host "NetBird connected successfully."

# --- Add task to auto-update on reboot and user login ---

$taskName = "NetBird AutoUpdate"
$scriptPath = $netbirdExe
$arguments = "update"

$action = New-ScheduledTaskAction -Execute $scriptPath -Argument $arguments
$trigger1 = New-ScheduledTaskTrigger -AtStartup
$trigger2 = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

$task = New-ScheduledTask -Action $action -Trigger $trigger1, $trigger2 -Principal $principal -Settings (New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries)

Register-ScheduledTask -TaskName $taskName -InputObject $task -Force

Write-Host "Scheduled task '$taskName' created to auto-update NetBird on reboot and logon."
