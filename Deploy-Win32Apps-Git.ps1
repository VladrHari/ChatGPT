<#
.SYNOPSIS
    This script connects to Microsoft Intune using specified credentials and deploys a set of applications 
    packaged via Winget to Intune.

.DESCRIPTION
    The script is designed to automate the deployment of multiple Win32 applications to Microsoft Intune. 
    It uses a set of credentials (Tenant ID, Client ID, and Client Secret) to authenticate against the Intune API 
    and then deploys the specified applications. Each application is packaged using Winget, and the script assumes 
    that the packages are stored in a specified directory on the local machine.

.PARAMETER tenantId
    The Tenant ID for the Azure AD tenant where the Intune service is hosted.

.PARAMETER clientId
    The Client ID (also known as App ID) of the Azure AD application used to authenticate the script.

.PARAMETER clientSecret
    The Client Secret of the Azure AD application used for authentication.

.PARAMETER packageFolder
    The directory where the Win32 app packages are stored.

.NOTES
    - Ensure the `WinTuner` module is installed and imported before running this script.
    - The script assumes that the required Winget packages are already available in the specified directory.
    - This script is designed for environments that require automated deployment of applications via Intune.
    - Modify the `applications` array to add or remove applications as needed.
    - Created by ChatGPT, an AI language model developed by OpenAI.

.EXAMPLE
    .\Deploy-Win32Apps-Git.ps1

    This example deploys the specified Win32 applications to Intune using the provided credentials.

.LINK
    https://wintuner.app/docs/category/wintuner-powershell
#>

# Parameters for Intune connection
$tenantId = "ADD_YOUR_TENANT_ID_HERE"
$clientId = "ADD_YOUR_CLIENT_ID_HERE"
$clientSecret = "ADD_YOUR_CLIENT_SECRET_HERE"

###############################################################################################################

# Connect to Intune using the specified credentials
$connectionParams = @{
    TenantId     = $tenantId
    ClientId     = $clientId
    ClientSecret = $clientSecret
}

###############################################################################################################

# Define the directory where the Win32 app packages are stored
# Make sure this folder exist before running script 
$packageFolder = "C:\packages\"

# List of applications to be deployed via Winget (this is an example) 
$applications = @(
    "Adobe.Acrobat.Reader.32-bit",
    "GitHub.GitHubDesktop",
    "WhatsApp.WhatsApp",
    "Dropbox.Dropbox",
    "Zoom.Zoom"
)

# Loop through each application in the list
foreach ($app in $applications) {
    # Create the Win32 package and deploy it to Intune
    New-WtWingetPackage -PackageId $app -PackageFolder $packageFolder | Deploy-WtWin32App @connectionParams
}
