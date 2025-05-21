<#
    .SYNOPSIS
    Silently installs components of the Windows ADK.

    .NOTES
    - Must be run as Administrator.
    - Removes any previously installed ADK features, including Deployment Tools.
#># Ensure script is running elevated

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
    Write-Error 'Please run this script as Administrator.'
    exit 1
}

# 1) Download the ADK installer into your user profile folder
$downloadUrl   = 'https://go.microsoft.com/fwlink/?linkid=2289980'
$installerPath = Join-Path $env:USERPROFILE 'adksetup.exe'

Write-Host "Downloading Windows ADK installer to $installerPath..."
Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath

# 2) Install only the Deployment Tools feature, silently, with no restart
$args = @(
    '/quiet'                                     # silent install
    '/norestart'                                 # suppress automatic reboot
    '/features', 'OptionId.DeploymentTools'      # install only Deployment Tools :contentReference[oaicite:2]{index=2}
)

Write-Host "Launching ADK installer..."
Start-Process -FilePath $installerPath -ArgumentList $args -Wait -NoNewWindow

Write-Host "Deployment Tools installation complete."
