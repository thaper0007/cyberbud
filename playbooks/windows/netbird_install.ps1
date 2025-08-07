# ==============================================================================
# NetBird Installation and Automated Login Script
# This script installs NetBird on a Windows machine, then logs in automatically
# using a setup key. It's designed to be executed via Ansible's win_shell module.
#
# Prerequisites:
# - The NetBird installer file (.msi) must be available on the target machine.
# - The NetBird management service URL and a valid setup key are required.
# ==============================================================================

# --- Configuration Variables ---
# Define your NetBird installer path, setup key, and management URL here.
# These variables can be passed as Ansible variables.

$installerPath = "C:\Temp\netbird-ui-windows_0.53.0_windows_amd64.msi"
$setupKey = "860FFC85-4995-452D-B0DB-0B8ACC661779"  # Replace with your actual setup key
$managementUrl = "https://netbird.cyberbud.ca:443" # Replace with your management URL, or omit for NetBird Cloud

# --- Step 1: Install NetBird ---
Write-Host "Starting NetBird installation..."

# The 'msiexec' command is used for installing MSI packages.
# /i: Specifies the installation option.
# /qn: Specifies the quiet mode, with no user interface.
# /L*v: A log file option for detailed logging, useful for debugging.
# C:\Temp\netbird_install.log: The path for the installation log file.
try {
    Start-Process msiexec.exe -Wait -ArgumentList "/i `"$installerPath`" /qn /L*v C:\Temp\netbird_install.log"
    Write-Host "NetBird installation completed successfully."
}
catch {
    Write-Error "NetBird installation failed. Error: $_"
    exit 1 # Exit with a non-zero code to indicate failure
}

# --- Step 2: Automatic Login with Setup Key ---
Write-Host "Starting NetBird automatic login..."

$netbirdExecutablePath = "C:\Program Files\NetBird\netbird.exe"

try {
    if ($managementUrl) {
        $netbirdLoginCommand = "`"$netbirdExecutablePath`" up --setup-key `"$setupKey`" --management-url `"$managementUrl`""
    }
    else {
        $netbirdLoginCommand = "`"$netbirdExecutablePath`" up --setup-key `"$setupKey`""
    }
    
    # Execute the command
    $netbirdOutput = & $netbirdLoginCommand
    Write-Host "NetBird login command executed. Output:"
    $netbirdOutput | Write-Host
    Write-Host "NetBird client should now be connected."
}
catch {
    Write-Error "NetBird login failed. Error: $_"
    exit 1
}

# --- Step 3: Verify Status (Optional) ---
Write-Host "Checking NetBird status..."

try {
    $statusOutput = netbird status
    Write-Host "NetBird Status:"
    $statusOutput | Write-Host
}
catch {
    Write-Error "Failed to get NetBird status. Error: $_"
    exit 1
}

Write-Host "Script finished."
