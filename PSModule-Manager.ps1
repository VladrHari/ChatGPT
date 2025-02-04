<#
.SYNOPSIS
    A comprehensive PowerShell script for managing PowerShell modules, including 
    viewing installed modules, installing new modules, updating existing modules, 
    removing unwanted modules, and exporting module cmdlets to CSV.
    
.DESCRIPTION
    This script provides an automated and structured approach to handling 
    PowerShell modules. It includes logging capabilities to track all operations, 
    ensuring transparency and easy debugging.

    Key functionalities include:
    - Listing all installed modules with details.
    - Installing PowerShell modules from the PowerShell Gallery.
    - Updating existing modules to their latest versions.
    - Removing unwanted or deprecated modules.
    - Exporting all cmdlets available within installed modules to a CSV file 
      for documentation and auditing.

    The script creates necessary directories for exporting data and ensures 
    that logs are maintained for every executed operation.

.PARAMETER ModuleName
    (If applicable) Specifies the name of the PowerShell module to be installed, 
    updated, or removed. This parameter is required for specific module operations.

.OUTPUTS
    - Logs operations in "C:\Temp\ModuleManager.log".
    - Exports cmdlet data to CSV in "C:\Temp\".

.VERSION
    

.AUTHOR
    ChatGPT

.LICENSE
    MIT License (Je Moeder)

.NOTES
    - Ensure that you have administrative privileges to install or remove modules.
    - PowerShell Gallery (`PSGallery`) must be available to install and update modules.
    - The script supports logging for debugging and auditing purposes.
    - Requires PowerShell version 5.1 or later.
#>




# ========================= Configuration =========================

# Check if running as admin
function Ensure-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    if (-not $isAdmin) {
        Write-Host "Warning: Some operations may require administrative privileges." -ForegroundColor Yellow
    }
}
Ensure-Admin

# Function to check and create C:\Temp if it doesn't exist
function Ensure-TempDirectory {
    $exportPath = "C:\Temp"
    if (-not (Test-Path -Path $exportPath)) {
        Write-Host "Creating folder: $exportPath" -ForegroundColor Yellow
        New-Item -Path $exportPath -ItemType Directory | Out-Null
    }
}
Ensure-TempDirectory

# ========================= Logging Setup =========================

$logFile = "C:\Temp\ModuleManager.log"

function Write-Log {
    param (
        [string]$message,
        [string]$level = "INFO"
    )
    if (-not (Test-Path $logFile)) { New-Item -Path $logFile -ItemType File -Force | Out-Null }
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logFile -Value "[$timestamp] [$level] $message"
}

# ========================= Export Cmdlets to CSV =========================

function Export-Cmdlets-ToCSV {
    # Select one or more modules
    $selectedModules = Show-InstalledModules
    if (-not $selectedModules -or $selectedModules.Count -eq 0) {
        Write-Host "No modules selected. Returning to menu..." -ForegroundColor Yellow
        return
    }

    # Ensure export directory exists
    Ensure-TempDirectory

    # Process each selected module
    foreach ($module in $selectedModules) {
        $moduleName = $module.Name
        $safeModuleName = $moduleName -replace '[\\/:*?"<>|]', '_'
        Write-Host "Exporting cmdlets for module: $moduleName" -ForegroundColor Cyan

        try {
            # Import the module safely
            Import-Module $moduleName -Force -ErrorAction Stop -WarningAction Stop
            Write-Host "Module '$moduleName' successfully loaded." -ForegroundColor Green

            # Get all cmdlets from the module
            $cmdlets = Get-Command -Module $moduleName
            if (-not $cmdlets) {
                Write-Host "No cmdlets found in '$moduleName'. Skipping..." -ForegroundColor Yellow
                continue
            }

            # Define common parameters to exclude
            $commonParams = @("Verbose", "Debug", "ErrorAction", "WarningAction", "InformationAction",
                              "ErrorVariable", "WarningVariable", "InformationVariable",
                              "OutVariable", "OutBuffer", "PipelineVariable")

            # Generate example commands
            $examples = @()
            foreach ($cmdlet in $cmdlets) {
                $parameters = if ($cmdlet.Parameters) {
                    ($cmdlet.Parameters.Keys | Where-Object { $commonParams -notcontains $_ }) -join " -<value> "
                } else {
                    ""
                }

                $exampleCmd = if ($parameters) { "$($cmdlet.Name) -$parameters" } else { "$($cmdlet.Name)" }

                $examples += [PSCustomObject]@{
                    "Cmdlet Name"       = $cmdlet.Name
                    "Generated Example" = $exampleCmd
                }
            }

            # Export the data to CSV with a safe filename
            $csvPath = "C:\Temp\$safeModuleName`_Cmdlets_Examples.csv"
            $examples | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
            Write-Host "Export completed: $csvPath" -ForegroundColor Green
            Write-Log "Exported cmdlets for $moduleName to $csvPath"
        } catch {
            Write-Host "Error: Failed to export cmdlets for module '$moduleName'." -ForegroundColor Red
            Write-Log "ERROR: Failed to export cmdlets for module '$moduleName'. $_"
        }
    }

    # Wait for user input before returning to the main menu
    Write-Host "`nPress Enter to return to the main menu..." -ForegroundColor Cyan
    Read-Host
}



# ========================= View Installed Modules =========================

function Show-InstalledModules {
    $installedModules = Get-Module -ListAvailable | Select-Object Name, Version, ModuleBase

    if ($installedModules) {
        $selectedModules = $installedModules | Out-GridView -Title "Select Modules to Manage" -PassThru
        if ($selectedModules) {
            Write-Host "`nYou selected the following module(s):" -ForegroundColor Cyan
            $selectedModules | ForEach-Object { Write-Host " - $($_.Name) (Version: $($_.Version))" }
        }
        return $selectedModules
    } else {
        Write-Host "No downloaded modules found." -ForegroundColor Red
        return @()
    }
}

# ========================= Manage & Update Modules =========================

function Manage-Modules {
    $selectedModules = Show-InstalledModules
    if ($selectedModules.Count -eq 0) {
        Write-Host "No modules selected. Returning to menu..." -ForegroundColor Yellow
        return
    }

    foreach ($module in $selectedModules) {
        $moduleName = $module.Name
        $installedVersions = Get-Module -ListAvailable -Name $moduleName | Select-Object -ExpandProperty Version | Sort-Object -Descending

        Write-Host "`nModule '$moduleName' is installed with these versions:" -ForegroundColor Cyan
        $installedVersions | ForEach-Object { Write-Host " - Version: $_" }

        Write-Host "`nWhat would you like to do with '$moduleName'?"
        Write-Host "1. Upgrade or Downgrade the version"
        Write-Host "2. Remove a specific version or all versions"
        Write-Host "3. Keep the installed version(s) and continue"
        $userChoice = Read-Host "Enter your choice (1/2/3)"

        if ($userChoice -eq "1") {
            Write-Host "Fetching all available versions for '$moduleName'..." -ForegroundColor Yellow

            try {
                # Get all available versions from the PowerShell Gallery
                $availableVersions = Find-Module -Name $moduleName -AllVersions -ErrorAction Stop | Select-Object -ExpandProperty Version | Sort-Object -Descending
                if (-not $availableVersions) {
                    Write-Host "❌ No available versions found for '$moduleName'." -ForegroundColor Red
                    continue
                }

                Write-Host "Available versions:" -ForegroundColor Cyan
                $availableVersions | ForEach-Object { Write-Host " - $_" }

                $selectedVersion = Read-Host "Enter the version number to install (upgrade/downgrade) or type 'latest' for the newest version"
                if ($selectedVersion -eq "latest") { $selectedVersion = $availableVersions[0] }

                if ($installedVersions -contains $selectedVersion) {
                    Write-Host "⚠ Version $selectedVersion of '$moduleName' is already installed. Skipping." -ForegroundColor Yellow
                    continue
                }

                Write-Host "Installing version $selectedVersion of '$moduleName'..." -ForegroundColor Yellow
                try {
                    Install-Module -Name $moduleName -RequiredVersion $selectedVersion -Scope CurrentUser -Force -ErrorAction Stop
                    Write-Host "✔ Successfully installed $moduleName (Version: $selectedVersion)." -ForegroundColor Green
                } catch {
                    Write-Host "❌ ERROR: Failed to install $moduleName (Version: $selectedVersion). $_" -ForegroundColor Red
                }

            } catch {
                Write-Host "❌ ERROR: Unable to fetch available versions for '$moduleName'. $_" -ForegroundColor Red
            }

        } elseif ($userChoice -eq "2") {
            $versionToRemove = Read-Host "Enter a version number to remove or type 'all' to remove all versions"

            if ($versionToRemove -eq "all") {
                # Ask for confirmation before removing all versions
                $confirmRemove = Read-Host "Are you sure you want to remove ALL versions of '$moduleName'? (Y/N)"
                if ($confirmRemove -notmatch "^[Yy]$") {
                    Write-Host "Skipping removal of '$moduleName'." -ForegroundColor Yellow
                    continue
                }

                try {
                    # Unload the module before removing it
                    if (Get-Module -Name $moduleName) {
                        Write-Host "Unloading module '$moduleName' before removal..." -ForegroundColor Yellow
                        Remove-Module -Name $moduleName -Force -ErrorAction Stop
                    }

                    Write-Host "Removing all versions of '$moduleName'..." -ForegroundColor Yellow
                    Uninstall-Module -Name $moduleName -AllVersions -Force -ErrorAction Stop
                    Write-Host "✔ Successfully removed all versions of $moduleName." -ForegroundColor Green
                } catch {
                    Write-Host "❌ ERROR: Failed to remove all versions of $moduleName. $_" -ForegroundColor Red
                }

            } elseif ($installedVersions -contains $versionToRemove) {
                # Ask for confirmation before removing a specific version
                $confirmRemove = Read-Host "Are you sure you want to remove '$moduleName' (Version: $versionToRemove)? (Y/N)"
                if ($confirmRemove -notmatch "^[Yy]$") {
                    Write-Host "Skipping removal of '$moduleName' (Version: $versionToRemove)." -ForegroundColor Yellow
                    continue
                }

                try {
                    # Unload the module before removing it
                    if (Get-Module -Name $moduleName) {
                        Write-Host "Unloading module '$moduleName' before removal..." -ForegroundColor Yellow
                        Remove-Module -Name $moduleName -Force -ErrorAction Stop
                    }

                    Write-Host "Removing '$moduleName' (Version: $versionToRemove)..." -ForegroundColor Yellow
                    Uninstall-Module -Name $moduleName -RequiredVersion $versionToRemove -Force -ErrorAction Stop
                    Write-Host "✔ Successfully removed $moduleName (Version: $versionToRemove)." -ForegroundColor Green
                } catch {
                    Write-Host "❌ ERROR: Failed to remove $moduleName (Version: $versionToRemove). $_" -ForegroundColor Red
                }
            } else {
                Write-Host "⚠ Version $versionToRemove is not installed. Skipping." -ForegroundColor Yellow
            }
        }
    }

    Write-Host "`n✔ Module management complete!" -ForegroundColor Green
    Write-Host "Press Enter to return to the main menu..." -ForegroundColor Cyan
    Read-Host
}





# ========================= Remove Multiple Modules in Bulk =========================

function Remove-ModulesInBulk {
    # Get all installed modules
    $installedModules = Get-Module -ListAvailable | Select-Object Name, Version, ModuleBase, Scope | Sort-Object Name

    if (-not $installedModules) {
        Write-Host "No installed modules found. Returning to main menu..." -ForegroundColor Yellow
        return
    }

    # Step 1: Show Out-GridView for Module Selection
    try {
        $selectedModules = $installedModules | Out-GridView -Title "Select PowerShell Modules to Remove" -PassThru -ErrorAction Stop
    } catch {
        Write-Host "⚠ WARNING: Out-GridView is not available. Falling back to manual selection." -ForegroundColor Yellow
        $selectedModules = @()
        foreach ($module in $installedModules) {
            $confirm = Read-Host "Remove '$($module.Name) (Version: $($module.Version))'? (Y/N)"
            if ($confirm -match "^[Yy]$") { $selectedModules += $module }
        }
    }

    # Check if the user selected any modules
    if (-not $selectedModules) {
        Write-Host "No modules selected. Returning to main menu..." -ForegroundColor Yellow
        return
    }

    # Display selected modules
    Write-Host "`nYou selected the following modules for removal:" -ForegroundColor Cyan
    $selectedModules | ForEach-Object { 
        Write-Host " - $($_.Name) (Version: $($_.Version), Location: $($_.ModuleBase))" -ForegroundColor White
    }

    # Step 2: Confirmation Prompt Before Proceeding
    $confirmation = Read-Host "`nAre you sure you want to remove ALL selected modules? (Y/N)"
    if ($confirmation -notmatch "^[Yy]$") {
        Write-Host "Operation canceled. Returning to main menu..." -ForegroundColor Yellow
        return
    }

    # Step 3: Check for Processes Using the Modules
    $lockedProcesses = Get-Process | Where-Object { $_.Modules -match "Microsoft.Graph" } -ErrorAction SilentlyContinue
    if ($lockedProcesses) {
        Write-Host "⚠ WARNING: The following processes are using Microsoft Graph modules:" -ForegroundColor Yellow
        $lockedProcesses | ForEach-Object { Write-Host " - $($_.Name) (PID: $($_.Id))" }

        $confirmKill = Read-Host "Forcefully close these processes? (Y/N)"
        if ($confirmKill -match "^[Yy]$") {
            $lockedProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
            Write-Host "✔ Processes terminated successfully." -ForegroundColor Green
            Start-Sleep -Seconds 2
        } else {
            Write-Host "Skipping removal of locked modules." -ForegroundColor Yellow
            return
        }
    }

    # Step 4: Unload Selected Modules Before Removal
    foreach ($module in $selectedModules) {
        Write-Host "Unloading module: $($module.Name)" -ForegroundColor Yellow
        Remove-Module -Name $module.Name -Force -ErrorAction SilentlyContinue
    }

    # Step 5: Remove Selected Modules
    $totalModules = $selectedModules.Count
    $currentModule = 0

    foreach ($module in $selectedModules) {
        $currentModule++
        $moduleName = $module.Name
        $moduleVersion = $module.Version
        $modulePath = $module.ModuleBase

        Write-Host "[ $currentModule / $totalModules ] Removing module: $moduleName (Version: $moduleVersion)" -ForegroundColor Cyan

        try {
            Uninstall-Module -Name $moduleName -AllVersions -Force -ErrorAction Stop
            Write-Host "✔ Successfully removed $moduleName" -ForegroundColor Green
        }
        catch {
            Write-Host "⚠ Uninstall-Module failed for '$moduleName'. Attempting folder deletion..." -ForegroundColor Yellow

            try {
                # Change permissions to ensure deletion is possible
                icacls "$modulePath" /grant "*S-1-1-0:F" /t /c /q | Out-Null

                # Remove read-only attributes
                attrib -R -H "$modulePath\*" /S /D

                # Attempt deletion
                Remove-Item -Path $modulePath -Recurse -Force -ErrorAction Stop

                if (-not (Test-Path $modulePath)) {
                    Write-Host "✔ Successfully deleted module folder: $modulePath" -ForegroundColor Green
                } else {
                    Write-Host "❌ ERROR: Folder still exists. Trying elevated removal..." -ForegroundColor Red
                    Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"Remove-Item -Path '$modulePath' -Recurse -Force`"" -Verb RunAs -Wait
                }
            } catch {
                Write-Host "❌ ERROR: Failed to delete module folder '$modulePath'. $_" -ForegroundColor Red
            }
        }
    }

    # Step 6: Completion Message
    Write-Host "`n✔ All selected modules have been removed!" -ForegroundColor Green
    Write-Host "Press Enter to return to the main menu..." -ForegroundColor Cyan
    Read-Host
}

# ========================= Main Menu =========================

do {
    Clear-Host
    Write-Host "============= PowerShell Module Manager (Windows PowerShell 5.X) ============="
    Write-Host "1. View Installed Modules"
    Write-Host "2. Manage & Update Modules"
    Write-Host "3. Remove Multiple Modules in Bulk"
    Write-Host "4. Export Cmdlets to CSV"
    Write-Host "5. Exit Script"
    Write-Host "==========================================================================="

    $menuChoice = Read-Host "Enter your choice (1/2/3/4/5)"

    switch ($menuChoice) {
        "1" { Show-InstalledModules }
        "2" { Manage-Modules }
        "3" { Remove-ModulesInBulk }
        "4" { Export-Cmdlets-ToCSV }
        "5" { Write-Host "Exiting script..." -ForegroundColor Green; exit }
        default { Write-Host "Invalid selection. Try again." -ForegroundColor Red }
    }
} while ($true)
