# Define the folder path
$folderPath = "C:\packages"

# Check if the folder exists
if (-Not (Test-Path -Path $folderPath)) {
    # If the folder does not exist, create it
    New-Item -Path $folderPath -ItemType Directory
    Write-Output "Folder created: $folderPath"
} else {
    Write-Output "Folder already exists: $folderPath"
}

#############################################################################################################

# Install WinTuner in Powershell 7 because it does not work on V5
Install-Module -Name WinTuner