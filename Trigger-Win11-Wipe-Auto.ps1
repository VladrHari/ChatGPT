<#
.SYNOPSIS
    Executes a full system wipe using MDM bridge on Windows 11 24H2 machines.

.DESCRIPTION
    - Validates that Windows 11 24H2 (build 26100) is active
    - Disables BitLocker if active
    - Triggers MDM_RemoteWipe via WMI bridge
    - Logs actions to C:\Logs\WipePostUpgrade.log

.NOTES
    Author: ChatGPT
    Script Name: Trigger-Win11-Wipe-Auto.ps1
#>

$LogPath = "C:\Logs"
$LogFile = "$LogPath\WipePostUpgrade.log"

if (!(Test-Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
}

Function Write-Log($message) {
    Add-Content -Path $LogFile -Value "$(Get-Date -Format G) - $message"
}

Write-Log "=== Starting post-upgrade wipe check ==="

$osVersion = (Get-CimInstance Win32_OperatingSystem).Version
$isWin1124H2 = $osVersion -like "10.0.26100*"

if (-not $isWin1124H2) {
    Write-Log "Not Windows 11 24H2. Current version: $osVersion. Exiting."
    exit 1
}

Write-Log "Windows 11 24H2 detected. Continuing with wipe process..."

# Check and disable BitLocker
$bitlockerStatus = Get-BitLockerVolume -MountPoint "C:" | Select-Object -ExpandProperty ProtectionStatus
if ($bitlockerStatus -eq 1) {
    Write-Log "BitLocker is enabled. Disabling..."
    Disable-BitLocker -MountPoint "C:" | Out-Null
    Start-Sleep -Seconds 10
    while ((Get-BitLockerVolume -MountPoint "C:").ProtectionStatus -ne 0) {
        Write-Log "Waiting for BitLocker to be disabled..."
        Start-Sleep -Seconds 5
    }
    Write-Log "BitLocker is now disabled."
} else {
    Write-Log "BitLocker was already disabled."
}

# Trigger MDM RemoteWipe
Write-Log "Attempting MDM RemoteWipe."
try {
    $namespaceName = "root\cimv2\mdm\dmmap"
    $className = "MDM_RemoteWipe"
    $methodName = "doWipeMethod"
    $session = New-CimSession

    $params = New-Object Microsoft.Management.Infrastructure.CimMethodParametersCollection
    $param = [Microsoft.Management.Infrastructure.CimMethodParameter]::Create("param", "", "String", "In")
    $params.Add($param)

    $instance = Get-CimInstance -Namespace $namespaceName -ClassName $className -Filter "ParentID='./Vendor/MSFT' and InstanceID='RemoteWipe'"
    $session.InvokeMethod($namespaceName, $instance, $methodName, $params)
    Write-Log "MDM RemoteWipe initiated successfully."
} catch {
    Write-Log "MDM RemoteWipe failed: $_"
    exit 1
}

Write-Log "=== Script complete ==="
