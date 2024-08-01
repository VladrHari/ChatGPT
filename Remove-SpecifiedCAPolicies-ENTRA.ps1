<#
.SYNOPSIS
    This script deletes all Conditional Access policies that are in a disabled state.

.NOTES
    1. Ensure you have the necessary permissions to delete Conditional Access policies.
    2. Review the policies before running the script to avoid accidental deletion of important policies.

.DETAILS
    FileName:    Remove-DisabledCAPolicies.ps1
    Author:      Jacques Behr & ChatGPT
    Created:     July 2024
    VERSION:     1.1
#>

# Define the module name for Azure AD Conditional Access policies
$moduleName = "Microsoft.Graph.Entra"

# Check if the Microsoft.Graph.Entra module is installed
$module = Get-Module -ListAvailable -Name $moduleName

if (-not $module) {
    Write-Host "Module $moduleName is not installed. Installing now..."
    Install-Module -Name $moduleName -Repository PSGallery -Scope CurrentUser -AllowPrerelease -Force
} else {
    Write-Host "Module $moduleName is already installed."
}

# Check if the module is imported
if (-not (Get-Module -Name $moduleName)) {
    Write-Host "Importing module $moduleName..."
    Import-Module $moduleName
} else {
    Write-Host "Module $moduleName is already imported."
}

Connect-Entra

# Get all Conditional Access policies
$allPolicies = Get-EntraConditionalAccessPolicy

# Filter policies that are in a disabled state
$disabledPolicies = $allPolicies | Where-Object { $_.State -eq "Disabled" }

# Loop through each disabled policy and delete it
foreach ($policy in $disabledPolicies) {
    try {
        Remove-EntraConditionalAccessPolicy -PolicyId $policy.Id
        Write-Host "Deleted policy: $($policy.DisplayName)" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to delete policy: $($policy.DisplayName). Error: $_" -ForegroundColor Red
    }
}

Write-Host "Script completed" -ForegroundColor Cyan
