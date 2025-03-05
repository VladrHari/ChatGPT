<#
.SYNOPSIS
    Prevents system sleep and simulates minimal user activity to keep Microsoft Teams status active.

.DESCRIPTION
    This script uses the Windows API function SetThreadExecutionState (via a custom .NET type)
    to prevent the computer from entering sleep mode and turning off the display.
    Additionally, it simulates a minimal mouse movement (shifting the cursor 1 pixel to the right and then restoring its original position)
    to trigger user activity. This helps ensure that applications such as Microsoft Teams continue to show an active (green) status,
    as Teams determines activity based on actual input.
    
    Note: While the script prevents the system from sleeping, Teams may still mark you as inactive if no genuine user input is detected.
    The minimal mouse movement is designed to be nearly imperceptible.
    
.EXAMPLE
    .\KeepTeamsActive.ps1
    Runs the script indefinitely until manually terminated (e.g., by pressing Ctrl+C).
    
.NOTES
    - Ensure that script execution is enabled (e.g., Set-ExecutionPolicy RemoteSigned).
    - Use with caution: Simulating user input might interfere with some applications.
#>

# Load required .NET assemblies for mouse simulation.
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Define the SetThreadExecutionState API using a full type definition.
$signature = @'
using System;
using System.Runtime.InteropServices;
public class SleepUtil {
    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern uint SetThreadExecutionState(uint esFlags);
}
'@
Add-Type -TypeDefinition $signature

# Define constants as unsigned 32-bit integers.
$ES_CONTINUOUS       = [uint32]2147483648  # 0x80000000: Instructs the system to maintain the state until changed.
$ES_SYSTEM_REQUIRED  = [uint32]1           # 0x00000001: Prevents the system from sleeping.
$ES_DISPLAY_REQUIRED = [uint32]2           # 0x00000002: Prevents the display from turning off.

function Prevent-Sleep {
    # Combine the flags using bitwise OR.
    $flags = $ES_CONTINUOUS -bor $ES_SYSTEM_REQUIRED -bor $ES_DISPLAY_REQUIRED
    $result = [SleepUtil]::SetThreadExecutionState($flags)
    if ($result -eq 0) {
        Write-Error "Failed to set the execution state."
    } else {
        Write-Host "Sleep prevention active."
    }
}

function Simulate-UserActivity {
    # Get the current mouse position as a System.Drawing.Point.
    $currentPos = [System.Drawing.Point]([System.Windows.Forms.Cursor]::Position)
    # Ensure X is treated as an integer and add 1.
    $newX = [int]$currentPos.X + 1
    # Create a new point with the updated X coordinate.
    $newPos = New-Object System.Drawing.Point($newX, $currentPos.Y)
    # Set the cursor to the new position.
    [System.Windows.Forms.Cursor]::Position = $newPos
    Start-Sleep -Milliseconds 100
    # Restore the original mouse position.
    [System.Windows.Forms.Cursor]::Position = $currentPos
    Write-Host "Simulated user activity via minimal mouse movement."
}

# Initial call to prevent sleep.
Prevent-Sleep

Write-Host "Keeping system awake and simulating user activity to keep Microsoft Teams active."
Write-Host "Press Ctrl+C to stop the script."

# Main loop: every 50 seconds, reapply sleep prevention and simulate a minimal mouse movement.
while ($true) {
    Start-Sleep -Seconds 50
    Prevent-Sleep
    Simulate-UserActivity
}
