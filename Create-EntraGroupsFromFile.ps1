<#
.SYNOPSIS
    Creates Entra groups from a list of names in a .txt file.

.DESCRIPTION
    This script connects to Microsoft Entra, reads a .txt file with group names from the directory
    where the script is run, sets the required parameters, creates the groups, and then disconnects
    from Microsoft Entra.

.EXAMPLE
    PS C:\> .\Create-EntraGroupsFromFile.ps1

    (Assuming 'groups.txt' is in the same directory as the script)
    Group 'FinanceTeam' has been created.
    Group 'HRTeam' has been created.

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

# Initialize an array to store created groups
$CreatedGroups = @()

# Loop through each name and create the group
foreach ($GroupName in $GroupNames) {
    try {
        # Create the group
        $group = New-MgGroup -DisplayName $GroupName -MailEnabled:$false -MailNickname $GroupName -SecurityEnabled:$true
        
        # Add the created group to the array
        $CreatedGroups += $group

        # Output the result
        Write-Host "Group '$GroupName' has been created."
    } catch {
        Write-Host "Failed to create group '$GroupName'. Error: $_"
    }
}

# Display the created groups in a neat format
$CreatedGroups | Format-Table DisplayName, Id -AutoSize

# Disconnect from Microsoft Graph
Disconnect-MgGraph
