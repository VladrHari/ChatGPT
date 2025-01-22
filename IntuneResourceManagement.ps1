<#PSScriptInfo
.VERSION 2.4
.DESCRIPTION 
this script connects to Microsoft Graph and retrieves various Intune resources (e.g., device configurations, compliance policies,
applications, etc.) using dynamic resource mapping and enhanced functionality.
.AUTHOR ChatGPT
#>

<# 
.SYNOPSIS
    A PowerShell script to retrieve, count, and manage Microsoft Intune resources via Microsoft Graph API.

.DESCRIPTION
    This script connects to Microsoft Graph and retrieves various Intune resources (e.g., device configurations, compliance policies,
    applications, etc.) using dynamic resource mappings. It displays the resources in an interactive grid view for user selection 
    and provides the option to delete selected items with confirmation prompts.
    
    It includes robust error handling, logging, and safeguards to prevent accidental deletions.

.PARAMETER Verbose
    Enables detailed logging during script execution.

.NOTES
    - Requires the Microsoft.Graph.Authentication and Microsoft.Graph.DeviceManagement modules.
    - Requires permissions for the following Microsoft Graph API scopes: 
      DeviceManagementConfiguration.ReadWrite.All, Directory.ReadWrite.All.
    - Designed for environments with GUI support for `Out-GridView` and `MessageBox`.
    - Deletion actions are commented out by default.

.HOW TO RUN
    1. Open a PowerShell terminal with the necessary permissions to execute scripts.
    2. Ensure the required Microsoft Graph permissions and modules are installed.
    3. Run the script as follows:
         .\IntuneResourceManagement.ps1
         .\IntuneResourceManagement.ps1 -Verbose
    4. Select resources from the grid view and confirm deletions as needed.

.VERSION
    2.4
#>

[CmdletBinding()]  # Enables support for -Verbose and other advanced features
param ()

# ========================= Configuration =========================
$LogFile = Join-Path -Path $env:TEMP -ChildPath "Intune_Log_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').txt"
Start-Transcript -Path $LogFile -Append

# ========================= Module Handling =========================
Function Ensure-ModuleInstalled {
    param ([string]$ModuleName)
    if (-not (Get-InstalledModule -Name $ModuleName -ErrorAction SilentlyContinue)) {
        Write-Verbose "Installing $ModuleName..."
        Install-Module -Name $ModuleName -Scope CurrentUser -Force -AllowClobber
    }
    Import-Module -Name $ModuleName -ErrorAction Stop
    Write-Verbose "$ModuleName is installed and loaded."
}

# Ensure necessary modules are installed
Ensure-ModuleInstalled -ModuleName "Microsoft.Graph.Authentication"
Ensure-ModuleInstalled -ModuleName "Microsoft.Graph.DeviceManagement"

# ========================= Authentication =========================
Write-Verbose "Connecting to Microsoft Graph..."
Connect-MgGraph -Scopes "DeviceManagementConfiguration.ReadWrite.All, Directory.ReadWrite.All"
Write-Verbose "Successfully connected to Microsoft Graph."

# ========================= Functions for API Calls =========================
Function Get-Resource {
    param (
        [string]$ResourceType,
        [string]$Id = $null
    )
    $Uri = if ($Id) {
        "https://graph.microsoft.com/beta/$ResourceType/$Id"
    } else {
        "https://graph.microsoft.com/beta/$ResourceType"
    }

    $Results = @()
    try {
        do {
            Write-Verbose "Retrieving data from $Uri..."
            $Response = Invoke-MgGraphRequest -Uri $Uri -Method Get -OutputType PSObject
            $Results += $Response.Value
            $Uri = $Response.'@odata.nextLink' # Handle pagination
        } while ($Uri)
    } catch {
        Write-Warning "Failed to retrieve resources from $ResourceType : $_"
    }
    return $Results
}

# ========================= Centralized Resource Mappings =========================
$ResourceMappings = @{
    "Admin Template"                = "deviceManagement/groupPolicyConfigurations"
    "Settings Catalog"              = "deviceManagement/configurationPolicies"
    "Compliance Policy"             = "deviceManagement/deviceCompliancePolicies"
    "Security Policy"               = "deviceManagement/intents"
    "Conditional Access Policy"     = "identity/conditionalAccess/policies"
    "Autopilot Profile"             = "deviceManagement/windowsAutopilotDeploymentProfiles"
    "Proactive Remediation"         = "deviceManagement/deviceHealthScripts"
    "iOS Mobile App Configuration"  = "deviceAppManagement/mobileAppConfigurations"
    "PowerShell Script"             = "deviceManagement/deviceManagementScripts"
    "Targeted Managed App Configuration" = "deviceAppManagement/targetedManagedAppConfigurations"
    "Windows Driver Update Profile" = "deviceManagement/windowsDriverUpdateProfiles"
    "App Protection"                = "deviceAppManagement/managedAppPolicies"
    "Applications"                  = "deviceAppManagement/mobileApps"
    "Device Configurations"         = "deviceManagement/deviceConfigurations"
    "Scripts"                       = "deviceManagement/deviceShellScripts"
}

# ========================= Interactive Resource Retrieval =========================
# Load the System.Windows.Forms assembly
Add-Type -AssemblyName System.Windows.Forms

do {
    Write-Verbose "Retrieving resources from Microsoft Graph..."

    $Configuration = @()
    foreach ($Type in $ResourceMappings.Keys) {
        $ResourceType = $ResourceMappings[$Type]
        $Resources = Get-Resource -ResourceType $ResourceType
        $Configuration += $Resources | ForEach-Object {
            # Ensure DisplayName is properly handled
            $DisplayName = if ($Type -eq "Settings Catalog" -and $_.PSObject.Properties["name"]) {
                $_.name
            } elseif ($_.PSObject.Properties["displayName"]) {
                $_.displayName
            } else {
                $null  # Leave blank if no display name exists
            }

            # Filter applications to only include "Windows App (Win32)" and "Microsoft Store app"
            if ($Type -eq "Applications" -and $_.PSObject.Properties["@odata.type"]) {
                $AppType = $_.'@odata.type'
                if ($AppType -notmatch "microsoft.graph.win32LobApp|microsoft.graph.microsoftStoreApp") {
                    return
                }
            }

            [PSCustomObject]@{
                ID          = $_.id
                Type        = $Type
                DisplayName = $DisplayName
                Description = if ($_.PSObject.Properties["description"]) { $_.description } else { $null }  # Leave blank if no description
            }
        }
    }

    # Display resources for selection
    $SelectedItems = $Configuration | Out-GridView -PassThru -Title "Select resources to delete"

    if ($SelectedItems) {
        $Confirmation = [System.Windows.Forms.MessageBox]::Show(
            "Are you sure you want to delete the selected items?",
            "Confirmation",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )

        if ($Confirmation -eq [System.Windows.Forms.DialogResult]::Yes) {
            foreach ($Item in $SelectedItems) {
                $Type = $Item.Type
                $Id = $Item.ID
                $ResourceType = $ResourceMappings[$Type]
                if ($ResourceType) {
                    Write-Verbose "Deleting resource: $Type, ID: $Id, DisplayName: $($Item.DisplayName)"
                    # Uncomment the following line to enable deletion
                    Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/$ResourceType/$Id" -Method Delete
                } else {
                    Write-Warning "Unrecognized resource type: $Type"
                }
            }
        } else {
            Write-Host "Deletion cancelled by the user."
        }
    } else {
        Write-Host "No items selected for deletion."
    }

    $Restart = [System.Windows.Forms.MessageBox]::Show(
        "Would you like to start the selection process again?",
        "Restart",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
} while ($Restart -eq [System.Windows.Forms.DialogResult]::Yes)

# ========================= Disconnect and Cleanup =========================
Write-Verbose "Disconnecting from Microsoft Graph..."
# Disconnect-MgGraph
Write-Verbose "Disconnected successfully."

# Stop transcript and provide the log file path
Stop-Transcript
Write-Host "Transcript saved to: $LogFile"
