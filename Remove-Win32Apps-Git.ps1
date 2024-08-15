<#
.SYNOPSIS
    This script retrieves and removes Win32 applications listed in a text file from both Intune and the C:\packages directory.

.DESCRIPTION
    The script first retrieves all Win32 apps using the Get-WtWin32Apps command, then reads application IDs from a text file located in the same directory as the script,
    and removes each corresponding package from Intune and deletes the local package files from C:\packages.

.PARAMETER Username
    The username (email address) used for interactive login. This is prompted at runtime.

.EXAMPLE
    .\Remove-Win32Apps-Git.ps1
    This example runs the script, prompts for the username, retrieves app details, removes all specified applications from Intune, and deletes the corresponding local package files.

.NOTES
    Requires: WinTuner PowerShell module
    Author: ChatGPT
    Version: 1.0
#>

# Ensure the WinTuner module is installed and imported
if (-not (Get-Module -ListAvailable -Name WinTuner)) {
    Install-Module -Name WinTuner -Force -AllowClobber
}
Import-Module WinTuner -ErrorAction SilentlyContinue

# Prompt the user for their username (email address) for interactive login
$username = Read-Host "Enter your username (email address)"

# Retrieve all Win32 apps
$oldApps = Get-WtWin32Apps -Username $username -NoBroker $true

# Display the Package IDs
$oldApps | Format-Table -Property PackageId

# Get the directory where the script is being run
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path

# Read application IDs from the file Winget-Apps-list.txt located in the script's directory
$applicationsFilePath = Join-Path -Path $scriptDirectory -ChildPath "Winget-Apps-list.txt"

if (Test-Path $applicationsFilePath) {
    $applicationIDs = Get-Content -Path $applicationsFilePath
    Write-Host "Application IDs loaded from $applicationsFilePath"
} else {
    Write-Host "Error: The file Winget-Apps-list.txt was not found in the script directory."
    exit 1
}

# Remove each application listed in the .txt file from Intune
foreach ($app in $applicationIDs) {
    $appToRemove = $oldApps | Where-Object { $_.PackageId -eq $app }
    
    if ($appToRemove) {
        Write-Host "Removing application: $($appToRemove.PackageId) from Intune"
        Remove-WtWin32App -Username $username -AppId $appToRemove.GraphId
        Write-Host "Removed $($appToRemove.PackageId) from Intune."
        
        # Remove the local package file if it exists in C:\packages
        $packagePath = Join-Path -Path "C:\packages" -ChildPath "$app"
        if (Test-Path $packagePath) {
            Remove-Item -Path $packagePath -Recurse -Force
            Write-Host "Removed $packagePath from local storage."
        } else {
            Write-Host "$packagePath does not exist in local storage."
        }
    } else {
        Write-Host "Application ID $app not found in the retrieved apps."
    }
}

Write-Host "All specified applications have been processed."
