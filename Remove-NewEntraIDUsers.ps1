<#
    .SYNOPSIS
    Remove-NewEntraIDUsers.ps1

    .DESCRIPTION
    Remove Microsoft Entra ID users from CSV file.The CSV file must be placed in the same directory where the PowerShell script is run.

    .LINK
    

    .NOTES
    Written by: ChatGPT
    Website:    www.openai.com

#>

# Connect to Microsoft Graph with user read/write permissions
Connect-MgGraph -Scopes "User.ReadWrite.All"

# Specify the path of the CSV file in the same directory as the script
$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$CSVFilePath = Join-Path -Path $ScriptDirectory -ChildPath "Users.csv"

# Import data from CSV file
$Users = Import-Csv -Path $CSVFilePath

# Loop through each row containing user details in the CSV file
foreach ($User in $Users) {
    $UserPrincipalName = $User.UserPrincipalName

    try {
        Remove-MgUser -UserId $UserPrincipalName -ErrorAction Stop
        Write-Host ("Successfully removed the account for {0}" -f $UserPrincipalName) -ForegroundColor Green
    }
    catch {
        Write-Host ("Failed to remove the account for {0}. Error: {1}" -f $UserPrincipalName, $_.Exception.Message) -ForegroundColor Red
    }
}
