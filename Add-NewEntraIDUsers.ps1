<#
    .SYNOPSIS
    Add-NewEntraIDUsers.ps1

    .DESCRIPTION
    This script creates Microsoft Entra ID users from a CSV file. The CSV file must be placed in the same directory where the PowerShell script is run. The script reads user details from the CSV file and creates accounts in Microsoft Entra ID using the specified parameters.

    .NOTES
    Written by: ChatGPT
    Website:    www.openai.com
#>

# Connect to Microsoft Graph with user read/write permissions
Connect-MgGraph -Scopes "User.ReadWrite.All"

# Specify the path of the CSV file located in the same directory as the script
$ScriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$CSVFilePath = Join-Path -Path $ScriptDir -ChildPath "Users.csv"

# Create password profile
$PasswordProfile = @{
    Password                             = "Turkijealtijdnummer1!"
    ForceChangePasswordNextSignIn        = $true
    ForceChangePasswordNextSignInWithMfa = $true
}

# Import data from CSV file
$Users = Import-Csv -Path $CSVFilePath

# Loop through each row containing user details in the CSV file
foreach ($User in $Users) {
    $UserParams = @{
        DisplayName       = $User.DisplayName
        MailNickName      = $User.MailNickName
        UserPrincipalName = $User.UserPrincipalName
        Department        = $User.Department
        JobTitle          = $User.JobTitle
        Mobile            = $User.Mobile
        Country           = $User.Country
        EmployeeId        = $User.EmployeeId
        PasswordProfile   = $PasswordProfile
        AccountEnabled    = $true
    }

    try {
        $null = New-MgUser @UserParams -ErrorAction Stop
        Write-Host ("Successfully created the account for {0}" -f $User.DisplayName) -ForegroundColor Green
    }
    catch {
        Write-Host ("Failed to create the account for {0}. Error: {1}" -f $User.DisplayName, $_.Exception.Message) -ForegroundColor Red
    }
}
