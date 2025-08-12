# ====================================================================
# NetBird Installation & Auto Update Script (combined)
# ====================================================================

# --- Configuration Variables ---
$setupKey = "860FFC85-4995-452D-B0DB-0B8ACC661779"  # Replace with your setup key
$managementUrl = "https://netbird.cyberbud.ca:443"   # Optional
$tempPath = "C:\Windows\Temp"
$installerFile = "$tempPath\netbird-latest.msi"
$netbirdExe = "C:\Program Files\NetBird\netbird.exe"
$netbirdUI = "C:\Program Files\NetBird\netbird-ui.exe"
$taskName = "NetBird Auto Update"
$updateScriptPath = "$tempPath\netbird_update.ps1"

# --- Step 1: Ensure Temp Directory ---
if (-Not (Test-Path $tempPath)) {
    New-Item -ItemType Directory -Path $tempPath | Out-Null
}

# --- Step 2: Download Latest MSI Installer ---
Write-Host "Fetching latest NetBird release URL from GitHub..."
try {
    $latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/netbirdio/netbird/releases/latest" -UseBasicParsing
    $asset = $latestRelease.assets | Where-Object { $_.name -match "windows_amd64\.msi$" } | Select-Object -First 1
    if (-not $asset) {
        throw "No MSI asset found in latest release."
    }
    $downloadUrl = $asset.browser_download_url
    Write-Host "Downloading from $downloadUrl..."
    Invoke-WebRequest -Uri $downloadUrl -OutFile $installerFile
    Write-Host "Downloaded installer to $installerFile"
} catch {
    Write-Error "Failed to download NetBird installer: $_"
    exit 1
}

# --- Step 3: Install NetBird ---
Write-Host "Installing NetBird..."
try {
    Start-Process msiexec.exe -Wait -ArgumentList "/i `"$installerFile`" /qn /L*v $tempPath\netbird_install.log"
    Write-Host "Installation completed successfully."
} catch {
    Write-Error "Installation failed: $_"
    exit 1
}

# --- Step 4: Login to NetBird ---
if (-Not (Test-Path $netbirdExe)) {
    Write-Error "NetBird executable not found at $netbirdExe"
    exit 1
}

Write-Host "Logging into NetBird..."
$arguments = @("up", "--setup-key", $setupKey)
if ($managementUrl) {
    $arguments += "--management-url"
    $arguments += $managementUrl
}

try {
    Start-Process -FilePath $netbirdExe -ArgumentList $arguments -Wait -NoNewWindow
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        $statusCheck = & $netbirdExe status
        if ($statusCheck -match "Connected") {
            Write-Host "NetBird is already connected. Ignoring non-zero exit code ($exitCode)."
        } else {
            throw "NetBird login failed with exit code $exitCode"
        }
    } else {
        Write-Host "NetBird client connected successfully."
    }
} catch {
    Write-Error $_
    exit 1
}

# --- Step 5: Verify Status ---
Write-Host "Checking NetBird status..."
try {
    $status = & $netbirdExe status
    Write-Host "NetBird Status:`n$status"
} catch {
    Write-Error "Failed to get NetBird status: $_"
    exit 1
}

# --- Step 6: Launch NetBird UI (Tray) ---
if (Test-Path $netbirdUI) {
    Write-Host "Starting NetBird UI in system tray..."
    Start-Process -FilePath $netbirdUI -WindowStyle Hidden
} else {
    Write-Host "NetBird UI executable not found, skipping tray startup."
}

# --- Step 7: Set NetBird UI to Auto-Start for All Users ---
try {
    $startupFolder = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"
    $shortcutPath = Join-Path $startupFolder "NetBird.lnk"
    if (Test-Path $netbirdUI) {
        $wsh = New-Object -ComObject WScript.Shell
        $shortcut = $wsh.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $netbirdUI
        $shortcut.Save()
        Write-Host "NetBird UI will now auto-launch for all users on login."
    } else {
        Write-Host "NetBird UI executable not found, skipping auto-start setup."
    }
} catch {
    Write-Error "Failed to set NetBird UI autostart: $_"
}

# --- Step 8: Create Scheduled Task for Auto-Update ---

$updateScriptContent = @"
# NetBird Auto-Update Script
function Get-InstalledNetBirdVersion {
    \$netbirdExe = 'C:\Program Files\NetBird\netbird.exe'
    if (Test-Path \$netbirdExe) {
        return (Get-Item \$netbirdExe).VersionInfo.ProductVersion
    }
    return \$null
}

function Update-NetBird {
    \$releaseApiUrl = 'https://api.github.com/repos/netbirdio/netbird/releases/latest'
    \$headers = @{ 'User-Agent' = 'PowerShell' }

    try {
        \$response = Invoke-RestMethod -Uri \$releaseApiUrl -Headers \$headers
    } catch {
        return
    }

    \$latestVersion = \$response.tag_name.TrimStart('v')
    \$installedVersion = Get-InstalledNetBirdVersion

    if (-not \$installedVersion) { return }
    if (\$installedVersion -eq \$latestVersion) { return }

    \$msiAsset = \$response.assets | Where-Object { \$_.name -like '*windows_amd64.msi' }
    if (-not \$msiAsset) { return }

    \$tempInstaller = "\$env:TEMP\netbird-latest.msi"
    Invoke-WebRequest -Uri \$msiAsset.browser_download_url -OutFile \$tempInstaller

    Start-Process msiexec.exe -ArgumentList "/i `"\$tempInstaller`" /quiet /norestart" -Wait

    Restart-Service -Name netbird -ErrorAction SilentlyContinue
}

Update-NetBird
"@

# Save update script to file
Set-Content -Path $updateScriptPath -Value $updateScriptContent -Encoding UTF8

# Register scheduled task if not exists
if (-not (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue)) {
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$updateScriptPath`""
    $trigger = New-ScheduledTaskTrigger -Daily -At 3am
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal
    Write-Host "Scheduled task '$taskName' created to run daily at 3am."
} else {
    Write-Host "Scheduled task '$taskName' already exists."
}

Write-Host "Script finished successfully."
