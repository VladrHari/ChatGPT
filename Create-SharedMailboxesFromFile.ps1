<#
.SYNOPSIS
    Creates shared mailboxes in Exchange Online from a list of names in a .txt file.

.DESCRIPTION
    This script connects to Exchange Online, reads a .txt file with shared mailbox names from the directory
    where the script is run, sets the required parameters, creates the shared mailboxes, and then disconnects
    from Exchange Online.

.EXAMPLE
    PS C:\> .\Create-SharedMailboxesFromFile.ps1

    (Assuming 'sharedmailboxes.txt' is in the same directory as the script)
    Shared mailbox 'FinanceTeam' with email address 'FinanceTeam@example.com' has been created.
    Shared mailbox 'HRTeam' with email address 'HRTeam@example.com' has been created.

.NOTES
    Author: ChatGPT
    Date: 2024-08-04
    Version: 1.0
#>

# Connect to Exchange Online
Connect-ExchangeOnline

# Define the file path for the shared mailbox names file
$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$SharedMailboxesFile = "$ScriptDirectory\sharedmailboxes.txt"

# Check if the file exists
if (-Not (Test-Path -Path $SharedMailboxesFile)) {
    Write-Host "The file 'sharedmailboxes.txt' was not found in the script directory. Please ensure the file exists and try again."
    Disconnect-ExchangeOnline -Confirm:$false
    exit
}

# Prompt for the domain name
$DomainName = Read-Host "Enter the domain name for the shared mailboxes (e.g., example.com)"

# Read the shared mailbox names from the file
$SharedMailboxNames = Get-Content -Path $SharedMailboxesFile

# Loop through each name and create the shared mailbox
foreach ($SharedMailboxName in $SharedMailboxNames) {
    # Set shared mailbox parameters
    $DisplayName = $SharedMailboxName
    $Alias = $SharedMailboxName -replace ' ', ''
    $PrimarySmtpAddress = "$Alias@$DomainName"

    # Create the shared mailbox
    New-Mailbox -Shared -Name $DisplayName -DisplayName $DisplayName -Alias $Alias -PrimarySmtpAddress $PrimarySmtpAddress 

    # Output the result
    Write-Host "Shared mailbox '$DisplayName' with email address '$PrimarySmtpAddress' has been created."
}

# Disconnect from Exchange Online
Disconnect-ExchangeOnline -Confirm:$false
