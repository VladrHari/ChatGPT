<#
.SYNOPSIS
    Creates a Windows shortcut on the Desktop that launches a specified PowerShell script.

.DESCRIPTION
    This script creates a shortcut ("snelkoppeling") on the current user's Desktop. The shortcut,
    when clicked, will start PowerShell with parameters to bypass the execution policy and run the 
    specified script. You can modify the shortcut name, target path, arguments, and icon as needed.
    
.EXAMPLE
    .\CreateShortcut.ps1
    Creates a shortcut named "KeepTeamsActive.lnk" on the Desktop that starts the PowerShell script.
    
.NOTES
    - Update the $ScriptPath variable to point to your PowerShell script.
    - The shortcut uses "-NoExit" so the PowerShell window remains open. Remove it if you prefer the window to close automatically.
#>

# Path to the PowerShell script to be launched.
$ScriptPath = "C:\scripts\KeepTeamsActive.ps1"  # <<< Change this to your actual script path.

# Check if the target script exists.
if (-not (Test-Path $ScriptPath)) {
    Write-Error "The specified script '$ScriptPath' does not exist. Please update the path."
    exit 1
}

# Create a WScript.Shell COM object.
$WshShell = New-Object -ComObject WScript.Shell

# Define the path to the user's Desktop.
$DesktopPath = [Environment]::GetFolderPath("Desktop")
$ShortcutPath = Join-Path $DesktopPath "KeepTeamsActive.lnk"

# Create the shortcut.
$Shortcut = $WshShell.CreateShortcut($ShortcutPath)

# Set the target to PowerShell.
$Shortcut.TargetPath = "powershell.exe"

# Set the arguments to run the script with the desired parameters.
$Shortcut.Arguments = "-NoExit -ExecutionPolicy Bypass -File `"$ScriptPath`""

# Set the working directory to the folder containing the script.
$Shortcut.WorkingDirectory = Split-Path $ScriptPath

# Optionally, set the icon to the default PowerShell icon.
$Shortcut.IconLocation = "powershell.exe,0"

# Save the shortcut.
$Shortcut.Save()

Write-Host "Shortcut created at: $ShortcutPath"
