<#
.SYNOPSIS
    Uninstalls all versions of Google Chrome and Mozilla Firefox by forcibly closing running processes,
    executing unattended uninstall commands, and removing any desktop and Start Menu shortcuts pointing to Chrome or Firefox
    without triggering a system restart. Also removes per-user installations (installed without admin rights) for Chrome and Firefox.

.DESCRIPTION
    This script verifies administrator privileges and scans the Windows registry for uninstall strings from both the system-wide (HKLM)
    and per-user (HKU) hives for Google Chrome or Mozilla Firefox. For Chrome and Firefox, it:
      1. Detects if the browser process is running; if so, waits 10 seconds and then forcefully terminates the process.
      2. Adjusts the uninstall command:
         - For Chrome (non-MSI), it appends "--uninstall", "--force-uninstall", and "--system-level" (if not already present),
           then adds "/quiet" and "/norestart" to ensure a silent, unattended uninstall.
         - For Firefox (non-MSI), it appends the silent parameter "-ms" if missing. For MSI-based installations, it adds the appropriate MSI silent parameters such as "/qn" and "/norestart".
      3. Executes the uninstall command silently via cmd.exe.
    Next, the script checks each user's AppData\Local folder for per-user installations of Chrome and Firefox.
      - For Chrome, it first looks for an installer (setup.exe) in common locations. If none is found but chrome.exe exists (e.g. at
        C:\Users\<username>\AppData\Local\Google\Chrome\Application\chrome.exe), the entire Chrome folder is deleted.
      - For Firefox, the per-user uninstaller is run if found.
    Finally, the script scans both the Public and per-user Desktop folders as well as the Start Menu folders (Public and per-user)
    for .lnk shortcuts whose target paths reference "chrome.exe" or "firefox.exe" and deletes them.
    A timestamped log file is generated in C:\logs, capturing all verbose output for auditing purposes.

.EXAMPLE
    .\RemoveBrowsers.ps1
    Runs the script, waits 10 seconds to terminate any running Chrome or Firefox processes, uninstalls all
    versions of Chrome, Firefox, and Safari (both system-wide and per-user) without a system restart, and removes desktop
    and Start Menu shortcuts. All details are logged in a file under C:\logs.

.NOTES
    - Run this script as an Administrator.
    - The script targets applications with a DisplayName containing "Chrome", "Mozilla Firefox".
    - No system restart will occur.
#>

# --- Force verbose output so all messages are logged ---
$VerbosePreference = "Continue"

# --- Check for Administrator privileges ---
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script must be run as Administrator!"
    exit
}

# --- Ensure the C:\logs folder exists and set up logging ---
$logPath = "C:\logs"
if (-not (Test-Path $logPath)) {
    New-Item -Path $logPath -ItemType Directory | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile   = Join-Path -Path $logPath -ChildPath "Log_$timestamp.txt"
Start-Transcript -Path $logFile -Append
Write-Verbose "Logging started. Log file: $logFile"

# --- Helper function to wait 10 seconds and forcefully terminate a running process ---
function Kill-BrowserProcess {
    param(
        [string]$ProcessName
    )
    $running = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    if ($running) {
        Write-Verbose "$ProcessName is running. Waiting 10 seconds before terminating..."
        Start-Sleep -Seconds 10
        Write-Verbose "Terminating $ProcessName..."
        Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Stop-Process -Force
    }
}

# --- Function to perform the uninstall command with appropriate silent parameters ---
function Uninstall-Program {
    param (
        [string]$Name,
        [string]$UninstallString
    )

    if ([string]::IsNullOrEmpty($UninstallString)) {
        Write-Verbose "No uninstall command found for $Name. Skipping..."
        return
    }

    # Adjust parameters based on the application
    if ($Name -match "Chrome") {
        Kill-BrowserProcess -ProcessName "chrome"

        # For non-MSI installations, append required parameters if missing
        if ($UninstallString -notmatch "msiexec") {
            if ($UninstallString -notmatch "--uninstall") {
                $UninstallString += " --uninstall"
            }
            if ($UninstallString -notmatch "--force-uninstall") {
                $UninstallString += " --force-uninstall"
            }
            if ($UninstallString -notmatch "--system-level") {
                $UninstallString += " --system-level"
            }
        }
        # Always add silent mode and no restart
        if ($UninstallString -notmatch "/quiet") {
            $UninstallString += " /quiet"
        }
        if ($UninstallString -notmatch "/norestart") {
            $UninstallString += " /norestart"
        }
    }
    elseif ($Name -match "Mozilla Firefox") {
        Kill-BrowserProcess -ProcessName "firefox"

        # For non-MSI installations, append the silent parameter if missing
        if ($UninstallString -notmatch "msiexec") {
            if ($UninstallString -notmatch "-ms" -and $UninstallString -notmatch "/S") {
                $UninstallString += " -ms"
            }
        }
        else {
            # For MSI-based installations, add silent mode and no restart parameters
            if ($UninstallString -notmatch "/qn") {
                $UninstallString += " /qn"
            }
            if ($UninstallString -notmatch "/norestart") {
                $UninstallString += " /norestart"
            }
        }
    }
    # No extra parameters are added for Safari or other applications.

    Write-Verbose "Executing uninstall for $Name with command: $UninstallString"
    try {
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "$UninstallString" -Wait -NoNewWindow
        Write-Verbose "$Name uninstalled successfully."
    }
    catch {
        Write-Warning "Failed to uninstall $Name. Error: $_"
    }
}

# --- Define registry paths to search for installed applications (system-wide) ---
$systemRegistryPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

# --- Search the system-wide registry (HKLM) for target applications and perform uninstallation ---
foreach ($path in $systemRegistryPaths) {
    Write-Verbose "Checking registry path: $path"
    $apps = Get-ItemProperty $path -ErrorAction SilentlyContinue | Where-Object {
        $_.DisplayName -match "Chrome" -or $_.DisplayName -match "Mozilla Firefox" -or $_.DisplayName -match "Safari"
    }

    foreach ($app in $apps) {
        $displayName     = $app.DisplayName
        $uninstallString = $app.UninstallString
        Write-Verbose "Found system-wide application: $displayName"
        Uninstall-Program -Name $displayName -UninstallString $uninstallString
    }
}

# --- Search the per-user registry hives (HKU) for Chrome and Firefox uninstall entries ---
Write-Verbose "Checking per-user uninstall entries in HKU..."
$hkuKeys = Get-ChildItem "HKU:\" -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^S-1-5' }
foreach ($userKey in $hkuKeys) {
    $userUninstallPath = "$($userKey.Name)\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    try {
        $userApps = Get-ItemProperty $userUninstallPath -ErrorAction SilentlyContinue | Where-Object {
            $_.DisplayName -match "Chrome" -or $_.DisplayName -match "Mozilla Firefox"
        }
        foreach ($app in $userApps) {
            $displayName = $app.DisplayName
            $uninstallString = $app.UninstallString
            Write-Verbose "Found per-user application: $displayName in hive $($userKey.Name)"
            Uninstall-Program -Name $displayName -UninstallString $uninstallString
        }
    }
    catch {
        Write-Verbose "No uninstall entries found for hive $($userKey.Name)"
    }
}

# --- Additional per-user uninstallation for apps installed without admin rights ---
Write-Verbose "Checking for per-user installations in user AppData folders..."
# Ensure processes are terminated
Kill-BrowserProcess -ProcessName "chrome"
Kill-BrowserProcess -ProcessName "firefox"

$userProfiles = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue
foreach ($profile in $userProfiles) {
    $localAppDataPath = Join-Path $profile.FullName "AppData\Local"

    ## --- Per-user Chrome uninstallation ---
    # Check for per-user Chrome installer in common locations.
    $chromeInstaller = Join-Path $localAppDataPath "Google\Chrome\Application\setup.exe"
    if (-not (Test-Path $chromeInstaller)) {
        $chromeInstaller = Join-Path $localAppDataPath "Google\Chrome\Application\Installer\setup.exe"
    }
    if (Test-Path $chromeInstaller) {
         Write-Verbose "Found per-user Chrome installer for user $($profile.Name) at $chromeInstaller. Uninstalling via installer..."
         $chromeUserDataDir = Join-Path $localAppDataPath "Google\Chrome\User Data"
         $args = "--uninstall --force-uninstall --user-data-dir=`"$chromeUserDataDir`" /quiet /norestart"
         try {
             Start-Process -FilePath $chromeInstaller -ArgumentList $args -Wait -NoNewWindow
             Write-Verbose "Per-user Chrome uninstalled for user $($profile.Name) via installer."
         }
         catch {
             Write-Warning "Failed to uninstall per-user Chrome for user $($profile.Name) via installer. Error: $_"
         }
    }
    else {
         Write-Verbose "No per-user Chrome installer found for user $($profile.Name). Checking for chrome.exe..."
         $chromeExePath = Join-Path $localAppDataPath "Google\Chrome\Application\chrome.exe"
         if (Test-Path $chromeExePath) {
             Write-Verbose "Found chrome.exe at $chromeExePath for user $($profile.Name). Removing the entire Chrome folder..."
             $chromeFolder = Join-Path $localAppDataPath "Google\Chrome"
             try {
                 Remove-Item -Path $chromeFolder -Recurse -Force
                 Write-Verbose "Chrome removed for user $($profile.Name) by deleting the folder."
             }
             catch {
                 Write-Warning "Failed to remove Chrome folder for user $($profile.Name). Error: $_"
             }
         }
         else {
             Write-Verbose "No per-user Chrome installation found for user $($profile.Name)."
         }
    }

    ## --- Per-user Firefox uninstallation ---
    $firefoxInstaller = Join-Path $localAppDataPath "Mozilla Firefox\uninstall\helper.exe"
    if (Test-Path $firefoxInstaller) {
         Write-Verbose "Found per-user Firefox installation for user $($profile.Name) at $firefoxInstaller. Uninstalling..."
         $args = "-ms"
         try {
             Start-Process -FilePath $firefoxInstaller -ArgumentList $args -Wait -NoNewWindow
             Write-Verbose "Per-user Firefox uninstalled for user $($profile.Name)."
         }
         catch {
             Write-Warning "Failed to uninstall per-user Firefox for user $($profile.Name). Error: $_"
         }
    }
}

# --- Function to remove desktop shortcuts for Chrome and Firefox from each user profile and the Public Desktop ---
function Remove-DesktopShortcuts {
    # Check the Public Desktop folder first
    $publicDesktop = "$env:Public\Desktop"
    if (Test-Path $publicDesktop) {
        Get-ChildItem -Path $publicDesktop -Filter *.lnk -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            $shortcut = $_
            $wshShell = New-Object -ComObject WScript.Shell
            try {
                $shortcutObject = $wshShell.CreateShortcut($shortcut.FullName)
                $targetPath = $shortcutObject.TargetPath
            }
            catch {
                $targetPath = ""
            }
            if ($targetPath -match "(?i)chrome\.exe" -or $targetPath -match "(?i)firefox\.exe") {
                Write-Verbose "Deleting Public Desktop shortcut: $($shortcut.FullName) which points to $targetPath"
                Remove-Item $shortcut.FullName -Force -Verbose
            }
        }
    }

    # Check each user's Desktop folder
    $userProfiles = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue
    foreach ($profile in $userProfiles) {
        $desktopPath = Join-Path $profile.FullName "Desktop"
        if (Test-Path $desktopPath) {
            Get-ChildItem -Path $desktopPath -Filter *.lnk -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
                $shortcut = $_
                $wshShell = New-Object -ComObject WScript.Shell
                try {
                    $shortcutObject = $wshShell.CreateShortcut($shortcut.FullName)
                    $targetPath = $shortcutObject.TargetPath
                }
                catch {
                    $targetPath = ""
                }
                if ($targetPath -match "(?i)chrome\.exe" -or $targetPath -match "(?i)firefox\.exe") {
                    Write-Verbose "Deleting Desktop shortcut: $($shortcut.FullName) which points to $targetPath"
                    Remove-Item $shortcut.FullName -Force -Verbose
                }
            }
        }
    }
}

# --- Function to remove Start Menu shortcuts for Chrome and Firefox from Public and per-user Start Menus ---
function Remove-StartMenuShortcuts {
    # Check the Public Start Menu folder
    $publicStartMenu = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs"
    if (Test-Path $publicStartMenu) {
        Get-ChildItem -Path $publicStartMenu -Filter *.lnk -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            $shortcut = $_
            $wshShell = New-Object -ComObject WScript.Shell
            try {
                $shortcutObject = $wshShell.CreateShortcut($shortcut.FullName)
                $targetPath = $shortcutObject.TargetPath
            }
            catch {
                $targetPath = ""
            }
            if ($targetPath -match "(?i)chrome\.exe" -or $targetPath -match "(?i)firefox\.exe") {
                Write-Verbose "Deleting Public Start Menu shortcut: $($shortcut.FullName) which points to $targetPath"
                Remove-Item $shortcut.FullName -Force -Verbose
            }
        }
    }
    # Check each user's Start Menu folder
    $userProfiles = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue
    foreach ($profile in $userProfiles) {
        $startMenuPath = Join-Path $profile.FullName "AppData\Roaming\Microsoft\Windows\Start Menu\Programs"
        if (Test-Path $startMenuPath) {
            Get-ChildItem -Path $startMenuPath -Filter *.lnk -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
                $shortcut = $_
                $wshShell = New-Object -ComObject WScript.Shell
                try {
                    $shortcutObject = $wshShell.CreateShortcut($shortcut.FullName)
                    $targetPath = $shortcutObject.TargetPath
                }
                catch {
                    $targetPath = ""
                }
                if ($targetPath -match "(?i)chrome\.exe" -or $targetPath -match "(?i)firefox\.exe") {
                    Write-Verbose "Deleting Start Menu shortcut: $($shortcut.FullName) which points to $targetPath"
                    Remove-Item $shortcut.FullName -Force -Verbose
                }
            }
        }
    }
}

# --- Remove any remaining Chrome or Firefox desktop shortcuts ---
Remove-DesktopShortcuts

# --- Remove any remaining Chrome or Firefox Start Menu shortcuts ---
Remove-StartMenuShortcuts

Write-Verbose "Uninstallation process completed. Microsoft Edge remains unaffected."
Stop-Transcript
