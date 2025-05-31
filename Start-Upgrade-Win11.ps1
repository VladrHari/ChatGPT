<#
    .SYNOPSIS
        Automatic Windows 11 in-place upgrade via setupprep.exe (only /product server and /eula accept).

    .DESCRIPTION
        - Searches C:\ISO for the Windows 11 ISO file, mounts it, and performs the upgrade.
        - Uses only /product server and /eula accept switches, disables dynamic updates, and auto upgrades.

    .EXAMPLE
        .\Start-Upgrade-Win11.ps1
#>

# Function to throw an error on non-zero exit codes
function Throw-IfError {
    param(
        [int]$ExitCode,
        [string]$Message
    )
    if ($ExitCode -ne 0) {
        Write-Error "❌ $Message (ExitCode=$ExitCode)"
        exit $ExitCode
    }
}

# 1) Define folder and locate the Windows 11 ISO
$isoFolder = "C:\ISO\"
Write-Host "🔍 Searching for Windows 11 ISO in $isoFolder" -ForegroundColor Yellow
$isoFile = Get-ChildItem -Path $isoFolder -Filter "*Windows*11*.iso" -File | Select-Object -First 1
if (-not $isoFile) {
    Write-Error "❌ No Windows 11 ISO found in $isoFolder"
    exit 1
}
$isoPath = $isoFile.FullName
Write-Host "✅ Found ISO: $isoPath" -ForegroundColor Green

# 2) Mount the ISO image
Write-Host "📀 Mounting ISO..." -ForegroundColor Cyan
$image = Mount-DiskImage -ImagePath $isoPath -PassThru
Throw-IfError $LASTEXITCODE "Failed to mount ISO"
Start-Sleep -Seconds 2

# 3) Retrieve the drive letter for the mounted ISO
$volume = $image |
    Get-Volume |
    Where-Object FileSystem -in @('CDFS','UDF') |
    Select-Object -First 1
if (-not $volume) {
    Write-Error "❌ Unable to get volume for mounted ISO"
    exit 1
}
$driveLetter = "$($volume.DriveLetter):"
Write-Host "🔧 ISO mounted at drive $driveLetter" -ForegroundColor Green

# 4) Verify setupprep.exe exists on the mounted ISO
$setupPrepExe = Join-Path $driveLetter "sources\setupprep.exe"
if (-not (Test-Path $setupPrepExe)) {
    Write-Error "❌ setupprep.exe not found at $setupPrepExe"
    exit 1
}
Write-Host "🔍 Found setup executable: $setupPrepExe" -ForegroundColor Green

# 5) Launch the in-place upgrade
Write-Host "🚀 Starting in-place upgrade" -ForegroundColor Cyan
$args = @(
    '/product server',            # Specify server product edition
    '/eula accept',              # Automatically accept the license agreement
    '/DynamicUpdate Disable',     # Disable dynamic updates during setup
    '/auto upgrade'              # Perform an automatic upgrade
)
$process = Start-Process -FilePath $setupPrepExe -ArgumentList $args -Wait -PassThru
Throw-IfError $process.ExitCode "Upgrade process failed"

# 6) Clean up: Dismount the ISO
Write-Host "🧹 Dismounting ISO" -ForegroundColor Green
Dismount-DiskImage -ImagePath $isoPath

# Final message: reboot required to complete installation
Write-Host "🎉 Upgrade completed. A restart is required to finish the installation." -ForegroundColor Cyan
