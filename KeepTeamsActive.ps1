<#
.SYNOPSIS
    Prevents system sleep and simulates realistic user activity (mouse movement and left click) to keep Microsoft Teams active.

.DESCRIPTION
    This script uses the Windows API function SetThreadExecutionState (via a custom .NET type) to prevent the computer from sleeping and the display from turning off.
    Additionally, it simulates human-like mouse movement by gradually moving the cursor from its current position to a random target location. 
    The target is determined by applying a random offset up to a maximum defined by $offsetMax (default 1000 pixels) in both X and Y directions,
    ensuring the target remains within the primary screen bounds. When the mouse reaches the new position, the script simulates a left mouse click.
    
    Note: Although the script prevents sleep and simulates mouse activity, Teams may still mark you as inactive if genuine user input is not detected.
    Adjust parameters like $offsetMax, $steps, and $stepDelay to fine-tune the behavior.
    
.EXAMPLE
    .\KeepTeamsActive.ps1
    Runs the script indefinitely until manually terminated (e.g., by pressing Ctrl+C).
    
.NOTES
    - Ensure that script execution is enabled (e.g., Set-ExecutionPolicy RemoteSigned).
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

# Define a new type for simulating mouse actions (left click).
$mouseSignature = @'
using System;
using System.Runtime.InteropServices;
public class MouseActions {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
}
'@
Add-Type -TypeDefinition $mouseSignature

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
    # Maximum offset for mouse movement (in pixels).
    $offsetMax = 1000

    # Get the current mouse position.
    $currentPos = [System.Drawing.Point]([System.Windows.Forms.Cursor]::Position)

    # Get primary screen bounds.
    $screenBounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds

    # Create a random object.
    $rand = New-Object System.Random

    # Generate random offsets for X and Y within the range [-offsetMax, offsetMax].
    $deltaX = $rand.Next(-$offsetMax, $offsetMax + 1)
    $deltaY = $rand.Next(-$offsetMax, $offsetMax + 1)

    # Compute target position.
    $targetX = $currentPos.X + $deltaX
    $targetY = $currentPos.Y + $deltaY

    # Ensure the target position is within screen bounds.
    $targetX = [Math]::Max($screenBounds.X, [Math]::Min($screenBounds.X + $screenBounds.Width - 1, $targetX))
    $targetY = [Math]::Max($screenBounds.Y, [Math]::Min($screenBounds.Y + $screenBounds.Height - 1, $targetY))
    $targetPos = New-Object System.Drawing.Point($targetX, $targetY)

    Write-Host "Moving mouse from ($($currentPos.X), $($currentPos.Y)) to ($($targetPos.X), $($targetPos.Y))"

    # Define the number of steps and delay per step for smooth, human-like movement.
    $steps = 50
    $stepDelay = 20  # in milliseconds

    # Calculate incremental movement.
    $stepX = ($targetPos.X - $currentPos.X) / $steps
    $stepY = ($targetPos.Y - $currentPos.Y) / $steps

    # Gradually move the mouse pointer.
    for ($i = 1; $i -le $steps; $i++) {
        $newX = $currentPos.X + [Math]::Round($i * $stepX)
        $newY = $currentPos.Y + [Math]::Round($i * $stepY)
        $newPos = New-Object System.Drawing.Point($newX, $newY)
        [System.Windows.Forms.Cursor]::Position = $newPos
        Start-Sleep -Milliseconds $stepDelay
    }
    
    Write-Host "Mouse moved to new position: ($($targetPos.X), $($targetPos.Y)). Simulating left click..."
    
    # Simulate a left mouse click.
    # MOUSEEVENTF_LEFTDOWN = 0x0002, MOUSEEVENTF_LEFTUP = 0x0004.
    [MouseActions]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)  # Left button down.
    Start-Sleep -Milliseconds 50
    [MouseActions]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)  # Left button up.
    
    Write-Host "Left mouse click simulated at ($($targetPos.X), $($targetPos.Y))."
}

# Initial call to prevent sleep.
Prevent-Sleep

Write-Host "Keeping system awake and simulating realistic user activity to keep Microsoft Teams active."
Write-Host "Press Ctrl+C to stop the script."

# Main loop: every 50 seconds, reapply sleep prevention and simulate user activity.
while ($true) {
    Start-Sleep -Seconds 50
    Prevent-Sleep
    Simulate-UserActivity
}
