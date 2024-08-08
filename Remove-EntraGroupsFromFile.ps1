<#
.SYNOPSIS
    Removes Entra groups from a list of names in a .txt file.

.DESCRIPTION
    This script connects to Microsoft Entra, reads a .txt file with group names from the directory
    where the script is run, finds the corresponding groups by display name, and removes them. The script
    then disconnects from Microsoft Entra.

.EXAMPLE
    PS C:\> .\Remove-EntraGroupsFromFile.ps1

    (Assuming 'groups.txt' is in the same directory as the script)
    Group 'FinanceTeam' has been removed.
    Group 'HRTeam' has been removed.

.NOTES
    Author: ChatGPT
    Date: 2024-08-08
    Version: 1.0
#>

# Install Microsoft.Graph module if not already installed
if (-Not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
    Install-Module -Name Microsoft.Graph -Scope CurrentUser -Force
}

# Connect to Microsoft Graph
Connect-MgGraph -Scopes "Group.ReadWrite.All"

# Define the file path for the group names file
$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$GroupsFile = "$ScriptDirectory\groups.txt"

# Output the script directory and file path for debugging purposes
Write-Host "Script directory: $ScriptDirectory"
Write-Host "Expected groups file path: $GroupsFile"

# Check if the file exists
if (-Not (Test-Path -Path $GroupsFile)) {
    Write-Host "The file 'groups.txt' was not found in the script directory. Please ensure the file exists and try again."
    Disconnect-MgGraph
    exit
}

# Read the group names from the file
$GroupNames = Get-Content -Path $GroupsFile

# Loop through each name and remove the group
foreach ($GroupName in $GroupNames) {
    try {
        # Find the group by display name
        $group = Get-MgGroup -Filter "displayName eq '$GroupName'"

        # Check if the group exists
        if ($group -ne $null) {
            # Remove the group
            Remove-MgGroup -GroupId $group.Id -Confirm:$false
            
            # Output the result
            Write-Host "Group '$GroupName' has been removed."
        } else {
            Write-Host "Group '$GroupName' does not exist."
        }
    } catch {
        Write-Host "Failed to remove group '$GroupName'. Error: $_"
    }
}

# Disconnect from Microsoft Graph
Disconnect-MgGraph
