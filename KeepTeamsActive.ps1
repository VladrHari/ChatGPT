<#
.SYNOPSIS
    Prevents system sleep and simulates user activity to keep Microsoft Teams status active.

.DESCRIPTION
    This script uses the Windows API function SetThreadExecutionState (via a custom .NET type) 
    to prevent the computer from sleeping and the display from turning off.
    Additionally, it simulates a minimal mouse movement by moving the cursor a configurable number 
    of pixels (default 5 pixels) to trigger user activity. This helps ensure that Microsoft Teams 
    displays an active (green) status.
    
    Note: Although this script prevents the system from sleeping, Teams may still mark you as inactive 
    if no genuine user input is detected. Increasing the movement offset might help.
    
.EXAMPLE
    .\KeepTeamsActive.ps1
    Runs the script indefinitely until manually terminated (e.g., by pressing Ctrl+C).
    
.NOTES
    - Ensure that script execution is enabled (e.g., Set-ExecutionPolicy RemoteSigned).
    - The simulated mouse movement might be slightly noticeable if the offset is set too high.
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
$ES_CONTINUOUS       = [uint32]2147483648  # 0x80000000: Maintains the state until changed.
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
    # Define the pixel offset for mouse movement.
    $offset = 5  # Increase this value if needed.
    
    # Get the current mouse position as a System.Drawing.Point.
    $currentPos = [System.Drawing.Point]([System.Windows.Forms.Cursor]::Position)
    
    # Calculate the new position by moving the cursor horizontally by the offset.
    $newX = [int]$currentPos.X + $offset
    $newPos = New-Object System.Drawing.Point($newX, $currentPos.Y)
    
    # Move the mouse cursor to the new position.
    [System.Windows.Forms.Cursor]::Position = $newPos
    # Short delay to simulate the movement.
    Start-Sleep -Milliseconds 100
    # Restore the cursor to its original position.
    [System.Windows.Forms.Cursor]::Position = $currentPos
    
    Write-Host "Simulated user activity: moved mouse by $offset pixels."
}

# Initial call to prevent sleep.
Prevent-Sleep

Write-Host "Keeping system awake and simulating user activity to keep Microsoft Teams active."
Write-Host "Press Ctrl+C to stop the script."

# Main loop: every 50 seconds, reapply sleep prevention and simulate a mouse movement.
while ($true) {
    Start-Sleep -Seconds 50
    Prevent-Sleep
    Simulate-UserActivity
}
