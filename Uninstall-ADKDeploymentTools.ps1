<#
    .SYNOPSIS
    Silently uninstalls all components of the Windows ADK.

    .NOTES
    - Must be run as Administrator.
    - Removes any previously installed ADK features, including Deployment Tools.

    .EXAMPLE
    .\Uninstall-ADKDeploymentTools.ps1
#>

# Ensure script is running elevated
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
    Write-Error 'Please run this script as Administrator.'
    exit 1
}

# Define the download URL for the ADK installer, in case it's not already present
$downloadUrl = 'https://go.microsoft.com/fwlink/?linkid=2289980'

# Path where the installer should reside under the current user's profile
$installerPath = Join-Path $env:USERPROFILE 'adksetup.exe'

# If the installer isn't already downloaded, fetch it now
if (-not (Test-Path $installerPath)) {
    Write-Host "Downloading ADK installer to $installerPath..."
    Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath
}

# Prepare uninstallation arguments:
#   /quiet      - run silently with no UI
#   /uninstall  - remove all installed ADK components
#   /norestart  - prevent automatic reboot (optional)
$args = @(
    '/quiet'
    '/uninstall'
    '/norestart'
)

Write-Host "Uninstalling Windows ADK..."
# Launch the uninstaller and wait for completion
Start-Process -FilePath $installerPath -ArgumentList $args -Wait -NoNewWindow

Write-Host "Windows ADK has been uninstalled."
