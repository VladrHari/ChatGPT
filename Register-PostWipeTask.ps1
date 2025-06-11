<#
.SYNOPSIS
    Registers a Scheduled Task that executes the post-upgrade wipe script with SYSTEM privileges at next boot.

.DESCRIPTION
    - Creates a task named "PostUpgradeWipe"
    - Executes C:\ISO\Trigger-Win11-Wipe-Auto.ps1
    - Runs under SYSTEM account with highest privileges at startup
    - Deletes itself after running once

.NOTES
    Author: ChatGPT
    Script Name: Register-PostWipeTask.ps1
#>

$taskName = "PostUpgradeWipe"
$scriptPath = "C:\ISO\Trigger-Win11-Wipe-Auto.ps1"

if (-not (Test-Path $scriptPath)) {
    Write-Error "❌ Script not found at $scriptPath"
    exit 1
}

$plainScript = 'Start-Sleep -s 10; powershell.exe -ExecutionPolicy Bypass -File "C:\ISO\Trigger-Win11-Wipe-Auto.ps1"; Unregister-ScheduledTask -TaskName "PostUpgradeWipe" -Confirm:$false'
$bytes = [System.Text.Encoding]::Unicode.GetBytes($plainScript)
$encodedCommand = [Convert]::ToBase64String($bytes)
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-EncodedCommand $encodedCommand"

$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

try {
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Force
    Write-Host "✅ Scheduled Task '$taskName' registered successfully. It will auto-delete after execution."
} catch {
    Write-Error "❌ Failed to register Scheduled Task: $_"
    exit 1
}
