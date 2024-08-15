<#
.SYNOPSIS
    This PowerShell script deploys multiple Win32 applications to Intune using WinTuner.
    The script authenticates interactively with a username and processes a list of application IDs.

.DESCRIPTION
    The script performs the following actions:
    1. Installs and imports the WinTuner PowerShell module if not already available.
    2. Prompts the user for their username to authenticate with Intune interactively.
    3. Ensures that the directory where Win32 app packages are stored exists, creating it if necessary.
    4. Iterates through a list of application IDs and deploys each application to Intune.

.PARAMETER Username
    The username (email address) used for interactive login. This is prompted at runtime.

.EXAMPLE
    .\Deploy-MultipleApps-Wintuner.ps1
    This example runs the script, prompts for the username, ensures the package folder exists, and deploys all specified applications.

.NOTES
    File Name      : Deploy-MultipleApps-Wintuner-Git.ps1
    Author         : Your Name
    Prerequisites  : WinTuner PowerShell module must be installed.
    Requires       : PowerShell 7.0 or later.
    Version        : 1.0
#>

# Ensure the WinTuner module is installed and imported
if (-not (Get-Module -ListAvailable -Name WinTuner)) {
    Install-Module -Name WinTuner -Force -AllowClobber
}
Import-Module WinTuner -ErrorAction SilentlyContinue

# Define the directory where the Win32 app packages are stored
$packageFolder = "C:\\packages\\"

# Ensure the directory exists, create it if it doesn't
if (-not (Test-Path -Path $packageFolder)) {
    Write-Host "The folder $packageFolder does not exist. Creating it now..."
    New-Item -Path $packageFolder -ItemType Directory -Force
    Write-Host "Folder $packageFolder created successfully."
} else {
    Write-Host "The folder $packageFolder already exists."
}

# Prompt the user for their username (email address) for interactive login
$username = Read-Host "Enter your username (email address)"

# Read application IDs from the file Winget-Apps-list.txt located in the same directory as the script
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$applicationsFilePath = Join-Path -Path $scriptDirectory -ChildPath "Winget-Apps-list.txt"

if (Test-Path $applicationsFilePath) {
    $applications = Get-Content -Path $applicationsFilePath
    Write-Host "Application IDs loaded from $applicationsFilePath"
} else {
    Write-Host "Error: The file Winget-Apps-list.txt was not found in the script directory."
    exit 1
}

# Process the first application with full command including NoBroker
if ($applications.Count -gt 0) {
    $firstApp = $applications[0]
    Write-Host "Processing the first application: $firstApp with NoBroker parameter"

    New-WtWingetPackage -PackageId $firstApp -PackageFolder $packageFolder | Deploy-WtWin32App -Username $username -NoBroker $true
    Write-Host "Deployment initiated for $firstApp with NoBroker."

    # Pause for 2 seconds
    Start-Sleep -Seconds 2
}

# Process the remaining applications without NoBroker
if ($applications.Count -gt 1) {
    $remainingApps = $applications[1..($applications.Count - 1)]
    
    foreach ($app in $remainingApps) {
        try {
            Write-Host "Processing application: $app"
            
            # Create the Win32 package and deploy it without NoBroker
            New-WtWingetPackage -PackageId $app -PackageFolder $packageFolder | Deploy-WtWin32App -Username $username
            Write-Host "Deployment initiated for $app."

            # Pause for 2 seconds
            Start-Sleep -Seconds 2
        } catch {
            # Use a more explicit error message
            $errorMessage = $_.Exception.Message
            Write-Host "An error occurred during deployment of $app. Error message: $errorMessage"
        }
    }
} else {
    Write-Host "No additional applications to process."
}

Write-Host "All applications have been processed."
