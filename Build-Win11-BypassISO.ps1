<#
.SYNOPSIS
    Builds a custom Windows 11 ISO with TPM/Secure Boot/CPU bypass by injecting a dummy appraiserres.dll.
.DESCRIPTION
    - Uses Windows ADK's oscdimg.exe to create the final ISO
    - Automatically installs ADK Deployment Tools if oscdimg.exe is missing
    - Mounts the base ISO, injects a zero-byte DLL to bypass compatibility checks
    - Searches for etfsboot.com & efisys.bin as fallback boot files
    - Outputs the custom ISO in C:\ISO with a timestamped name
.NOTES
    Author: ChatGPT & Vladimir
    
    Build-Win11-BypassISO.ps1
#>


param (
    [Parameter(Mandatory=$false)]
    [string]$BaseIsoPath = "$env:USERPROFILE\Downloads\Win11_24H2_Dutch_x64-RAW.iso"
)

# Ensures the script is running with administrative privileges
function Ensure-Administrator {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
        Write-Error '❌ This script must be run as Administrator.'
        exit 1
    }
}

# Installs the ADK Deployment Tools feature silently if not already installed
function Install-ADKDeploymentTools {
    $downloadUrl   = 'https://go.microsoft.com/fwlink/?linkid=2289980'
    $installerPath = Join-Path $env:TEMP 'adksetup.exe'

    Write-Host "📥 Downloading Windows ADK installer to: $installerPath"
    Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath

    if (-not (Test-Path $installerPath)) {
        Write-Error "❌ Download failed. Installer not found at $installerPath"
        exit 1
    }

    $args = @(
        '/quiet',
        '/norestart',
        '/features', 'OptionId.DeploymentTools'
    )

    Write-Host "⚙️ Starting ADK Deployment Tools installation..."
    Start-Process -FilePath $installerPath -ArgumentList $args -Wait -NoNewWindow

    Write-Host "✅ ADK Deployment Tools installation completed."
    Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
}

# Attempts to locate oscdimg.exe from a list of possible ADK installation paths
# If not found, triggers the ADK installer function and retries
function Get-ADKOscdimgPath {
    $paths = @(
        "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe",
        "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\x86\Oscdimg\oscdimg.exe"
    )
    foreach ($p in $paths) {
        if (Test-Path $p) { return $p }
    }

    Write-Warning "⚠️ oscdimg.exe not found. Attempting to install ADK Deployment Tools..."
    Install-ADKDeploymentTools

    foreach ($p in $paths) {
        if (Test-Path $p) { return $p }
    }

    Write-Error "❌ oscdimg.exe still not found after installation. Aborting."
    exit 1
}

# Searches for boot files like etfsboot.com or efisys.bin within the ADK directory structure
function Find-ADKBootFile {
    param($Name, $OscdimgPath)
    $adkRoot = Split-Path -Parent (Split-Path -Parent $OscdimgPath)
    return (Get-ChildItem -Path $adkRoot -Filter $Name -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty FullName)
}

# === MAIN EXECUTION FLOW START ===

Ensure-Administrator

# 1) Validate that the specified ISO path exists
if (-not (Test-Path $BaseIsoPath)) {
    Write-Error "❌ Invalid ISO path: $BaseIsoPath"
    exit 1
}

# 2) Mount the ISO and copy its contents to a temporary directory
$tempDir = Join-Path $env:TEMP "Win11_Bypass_$(Get-Random)"
New-Item -Path $tempDir -ItemType Directory | Out-Null
Write-Host "🔧 Mounting and copying contents to: $tempDir" -ForegroundColor Green

$disk = Mount-DiskImage -ImagePath $BaseIsoPath -PassThru
Start-Sleep 2
$driveLetter = ($disk | Get-Volume | Select-Object -First 1 -ExpandProperty DriveLetter) + ":"
Copy-Item "$driveLetter\*" $tempDir -Recurse -Force
Dismount-DiskImage -ImagePath $BaseIsoPath

# 3) Replace or create a zero-byte dummy appraiserres.dll to bypass hardware checks
$dllTarget = Join-Path $tempDir "sources\appraiserres.dll"
if (Test-Path $dllTarget) { Remove-Item $dllTarget -Force }
New-Item -Path $dllTarget -ItemType File | Out-Null
Write-Host "✅ Dummy appraiserres.dll created" -ForegroundColor Green

# 4) Locate boot files: etfsboot.com and efisys.bin, fallback to ADK if missing
$oscdimg = Get-ADKOscdimgPath
$etfs   = Join-Path $tempDir "boot\etfsboot.com"
$efi    = Join-Path $tempDir "efi\microsoft\boot\efisys.bin"

if (-not (Test-Path $etfs)) {
    $etfs = Find-ADKBootFile -Name "etfsboot.com" -OscdimgPath $oscdimg
    Write-Host "⚠️ Using fallback etfsboot.com: $etfs"
}
if (-not (Test-Path $efi)) {
    $efi = Find-ADKBootFile -Name "efisys.bin" -OscdimgPath $oscdimg
    Write-Host "⚠️ Using fallback efisys.bin: $efi"
}

if (-not (Test-Path $etfs) -or -not (Test-Path $efi)) {
    Write-Error "❌ Could not locate required boot files. Verify ADK installation."
    exit 1
}

# 5) Build argument array for oscdimg
$bootData = "2#p0,e,b`"$etfs`"#pEF,e,b`"$efi`""
$args = @(
    '-m',                # no media size limit
    '-u1',               # use UDF 1.02
    '-h',                # preserve long filenames
    '-lWIN11_24H2_Bypass',
    "-bootdata:$bootData",
    $tempDir
)

# 6) Ensure output directory exists and generate a timestamped output ISO name
$isoFolder = "C:\ISO"
if (-not (Test-Path $isoFolder)) {
    New-Item -Path $isoFolder -ItemType Directory | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmm"
$outputIso = Join-Path $isoFolder "$timestamp-Windows11_24H2-Jemoeder.iso"

Write-Host "🚀 Generating custom ISO to: $outputIso" -ForegroundColor Cyan

# 7) Execute oscdimg to generate the ISO
& $oscdimg @args $outputIso
if ($LASTEXITCODE -ne 0) {
    Write-Error "❌ ISO generation failed. Exit code: $LASTEXITCODE"
    exit 1
}

# 8) Clean up temporary files
Remove-Item $tempDir -Recurse -Force
Write-Host "🎉 Done! Your custom ISO is saved at: $outputIso" -ForegroundColor Cyan
