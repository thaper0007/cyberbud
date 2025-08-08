# ==============================================================================
# NetBird Installation & Auto Login Script (GitHub Download Version)
# ==============================================================================

# --- Configuration Variables ---
$setupKey = "860FFC85-4995-452D-B0DB-0B8ACC661779"  # Replace with your setup key
$managementUrl = "https://netbird.cyberbud.ca:443" # Optional
$tempPath = "C:\Temp"
$installerFile = "$tempPath\netbird-latest.msi"
$netbirdExe = "C:\Program Files\NetBird\netbird.exe"

# --- Step 1: Ensure Temp Directory ---
if (-Not (Test-Path $tempPath)) {
    New-Item -ItemType Directory -Path $tempPath | Out-Null
}

# --- Step 2: Download Latest MSI from GitHub ---
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
    if ($LASTEXITCODE -ne 0) {
        throw "NetBird login failed with exit code $LASTEXITCODE"
    }
    Write-Host "NetBird client connected successfully."
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

Write-Host "Script finished successfully."
