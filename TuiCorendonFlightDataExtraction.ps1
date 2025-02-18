<# 
.SYNOPSIS
    A PowerShell script to extract flight data from TUI and Corendon websites using Selenium and process the data for further analysis.

.DESCRIPTION
    This script uses Selenium to navigate to the TUI and Corendon flight search pages, extract outbound (heen) and inbound (terug) flight data,
    and process detailed flight information. It saves the TUI flight data to a file and later parses that file to display flight details,
    including flight dates and prices for the first 7 days of outbound and inbound flights, as well as additional detailed flight information
    from TUI Airlines Nederland.

.PARAMETER Verbose
    Enables detailed logging during script execution.

.NOTES
    - Requires the Selenium PowerShell module.
    - Requires Google Chrome and ChromeDriver to be installed and properly configured.
    - The script writes output files to a specified directory (e.g., C:\output).
    - This script is designed for the current structure of the target websites; adjustments may be necessary if the websites change.
    - Save this script as "TuiCorendonFlightDataExtraction.ps1".

.HOW TO RUN
    1. Open a PowerShell terminal with an appropriate execution policy (e.g., run as Administrator if needed).
    2. Ensure that the Selenium module, Google Chrome, and ChromeDriver are installed and correctly configured.
    3. Save this script as `TuiCorendonFlightDataExtraction.ps1` in your desired directory.
    4. Run the script using one of the following commands:
         .\TuiCorendonFlightDataExtraction.ps1
         .\TuiCorendonFlightDataExtraction.ps1 -Verbose
    5. Review the output in the console and check the generated output files in the designated output directory.

.VERSION
    1.0

.LICENSE
     MIT License (Je Moeder)
#>


# ──────────────────────────────────────────────
# PART A: Selenium Setup & Flight Data Extraction
# ──────────────────────────────────────────────

# Check if the Selenium module is installed; if not, install it
Write-Host "Checking if Selenium module is installed..." -Verbose
if (-not (Get-Module -ListAvailable -Name Selenium)) {
    Write-Host "Selenium module not found. Installing..." -Verbose
    Install-Module Selenium -Scope CurrentUser -Force
}
Import-Module Selenium

# Verify that Google Chrome is installed at the specified location
$chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
if (-Not (Test-Path $chromePath)) {
    Write-Host "Google Chrome not found. Please install it first." -ForegroundColor Red
    exit 1
}
Write-Host "✅ Google Chrome found at: $chromePath" -Verbose

# Verify that ChromeDriver is installed at the specified location
$chromeDriverPath = "C:\ChromeDriver\chromedriver-win32\chromedriver.exe"
if (-Not (Test-Path $chromeDriverPath)) {
    Write-Host "❌ ChromeDriver not found. Please download and extract it to $chromeDriverPath" -ForegroundColor Red
    exit 1
}

# Define a helper function to start the Selenium ChromeDriver
function Start-SeleniumDriver {
    param(
        [string]$ChromePath,
        [string]$ChromeDriverPath,
        [bool]$UseHeadless = $false,
        [bool]$StartMaximized = $false
    )

    # Create a new ChromeOptions object and set the binary location for Chrome
    $chromeOptions = New-Object OpenQA.Selenium.Chrome.ChromeOptions
    $chromeOptions.BinaryLocation = $ChromePath

    # Optionally start the browser maximized
    if ($StartMaximized) { 
        $chromeOptions.AddArgument("--start-maximized") 
    }

    # Disable browser notifications
    $chromeOptions.AddUserProfilePreference("profile.default_content_setting_values.notifications", 2)

    # Enable headless mode if specified
    if ($UseHeadless) { 
        $chromeOptions.AddArgument("--headless") 
    }

    # Start the ChromeDriver service from the specified path and return the driver instance
    $driverService = [OpenQA.Selenium.Chrome.ChromeDriverService]::CreateDefaultService((Split-Path $ChromeDriverPath))
    $driver = New-Object OpenQA.Selenium.Chrome.ChromeDriver($driverService, $chromeOptions)
    return $driver
}

# Global setting: set headless to $false for UI (set to $true to run without UI)
$useHeadless = $false

# Create a Selenium Driver instance (shared for both tasks)
$driver = Start-SeleniumDriver -ChromePath $chromePath -ChromeDriverPath $chromeDriverPath -UseHeadless $useHeadless -StartMaximized $true

# ──────────────────────────────────────────────
# Part A1: Extract Corendon Flight Data
# ──────────────────────────────────────────────

# Navigate to the Corendon flights page
$corendonUrl = "https://www.corendon.com/nl/flights/amsterdam/curacao/20250411/20250427?passenger=1&infant=0&utm_source=googleflight&utm_medium=referral&utm_term=cpa&utm_campaign=googleflight"
$driver.Navigate().GoToUrl($corendonUrl)
Start-Sleep -Seconds 5  # Wait for the page to load completely

# Retrieve all date elements and flight card elements from the page
$allDates   = $driver.FindElements([OpenQA.Selenium.By]::XPath("//table[@class='flight-matrix']/thead/tr/th"))
$allFlights = $driver.FindElements([OpenQA.Selenium.By]::ClassName("flightcard"))

# Debug: Uncomment to list all found dates for Corendon flights
# Write-Host "`n📅 All found dates (Corendon):" -ForegroundColor Yellow
# foreach ($date in $allDates) { Write-Host $date.Text }

# Check that the total number of flight cards is even (to allow splitting into outbound/inbound)
if ($allFlights.Count % 2 -ne 0) {
    Write-Host "❌ The number of flight cards is not even. Check the HTML structure!" -ForegroundColor Red
    $driver.Quit()
    exit 1
}

# Split flight cards and dates into two halves: outbound (heen) and inbound (terug)
$halfCount    = [int]($allFlights.Count / 2)
$heenFlights  = $allFlights[0..($halfCount - 1)]
$terugFlights = $allFlights[$halfCount..($allFlights.Count - 1)]

# Ensure that there are enough date elements to match the flight cards
if ($allDates.Count -ge 2 * $halfCount) {
    $heenDates  = $allDates[0..($halfCount - 1)]
    $terugDates = $allDates[$halfCount..(2*$halfCount - 1)]
} else {
    Write-Host "❌ Not enough date elements found. Check the XPath selector for dates." -ForegroundColor Red
    $driver.Quit()
    exit 1
}

# Build the output for Corendon flights
$corendonOutput = @()
$corendonOutput += "`n🛫 **Outbound Flights (Corendon)**"
for ($i = 0; $i -lt $heenFlights.Count; $i++) {
    $date    = $heenDates[$i].Text
    $flight  = $heenFlights[$i]
    # Extract price (removing non-digit characters)
    $price   = ($flight.FindElement([OpenQA.Selenium.By]::ClassName("price")).Text -replace '[^\d]', '')
    $time    = $flight.FindElement([OpenQA.Selenium.By]::ClassName("time")).Text
    # Extract airline information from a nested element
    $airline = $flight.FindElement([OpenQA.Selenium.By]::ClassName("status")).FindElement([OpenQA.Selenium.By]::TagName("small")).Text
    $corendonOutput += "$date | €$price | $time | $airline"
}

$corendonOutput += "`n🛬 **Inbound Flights (Corendon)**"
for ($i = 0; $i -lt $terugFlights.Count; $i++) {
    $date    = $terugDates[$i].Text
    $flight  = $terugFlights[$i]
    $price   = ($flight.FindElement([OpenQA.Selenium.By]::ClassName("price")).Text -replace '[^\d]', '')
    $time    = $flight.FindElement([OpenQA.Selenium.By]::ClassName("time")).Text
    $airline = $flight.FindElement([OpenQA.Selenium.By]::ClassName("status")).FindElement([OpenQA.Selenium.By]::TagName("small")).Text
    $corendonOutput += "$date | €$price | $time | $airline"
}

# ──────────────────────────────────────────────
# Part A2: Extract TUI Flight Data
# ──────────────────────────────────────────────

# Navigate to the TUI flights page
$tuiUrl = "https://www.tui.nl/flight/nl/search?flyingTo=CUR&flyingFrom=AMS&depDate=2025-04-11&adults=1&childAge=&isOneWay=false&returnDate=2025-04-27"
$driver.Navigate().GoToUrl($tuiUrl)
Start-Sleep -Seconds 10  # Wait longer for the TUI page to fully load

# Retrieve the flight container element and extract its text content
try {
    $flightContainer = $driver.FindElement([OpenQA.Selenium.By]::TagName("tfm-search-results-ui"))
    $flightText      = $flightContainer.Text
} catch {
    Write-Host "❌ Could not locate the flight information on the TUI page." -ForegroundColor Red
    $driver.Quit()
    exit 1
}

# Debug: Uncomment to display a snippet of the flight text (first 500 characters)
# Write-Host "`n🔍 Found TUI flight information (first 500 characters):" -ForegroundColor Yellow
# Write-Host $flightText.Substring(0, [Math]::Min(500, $flightText.Length))

# Process the text by splitting it into lines and filtering for relevant flight data lines
$flightLines = $flightText -split "`n"
$flightData  = @()
$collecting  = $false

foreach ($line in $flightLines) {
    # Start collecting lines after encountering "HEENVLUCHT" or "TERUGVLUCHT"
    if ($line -match "HEENVLUCHT|TERUGVLUCHT") {
        $collecting = $true
        continue
    }
    # Stop collecting when encountering specific keywords
    if ($collecting -and ($line -match "Kies vlucht|Vluchtdetails")) {
        $collecting = $false
        continue
    }
    if ($collecting) {
        $flightData += $line.Trim()
    }
}

if ($flightData.Count -eq 0) {
    Write-Host "⚠️ No flight data found for TUI." -ForegroundColor Red
    $driver.Quit()
    exit 1
}

# Build the TUI output as a list of flight data lines
$tuiOutput = @("🛫 **TUI Flight Details**")
$tuiOutput += $flightData

# ──────────────────────────────────────────────
# Combined Output: Display Only Corendon Data via Write-Host
# ──────────────────────────────────────────────

Write-Host "`n----- Combined Output -----" -ForegroundColor Cyan
Write-Host "`n**Corendon Flights:**" -ForegroundColor Cyan
$corendonOutput | ForEach-Object { Write-Host $_ }
# Add an empty line for spacing
Write-Host ""

# Save the TUI flight data to a file for later parsing
$outputFolder = "C:\output"
if (-Not (Test-Path $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder | Out-Null
}
# Create a unique filename with a timestamp
$outputPath = Join-Path $outputFolder ("vluchten-{0}.txt" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$tuiOutput | Out-File -Encoding UTF8 -FilePath $outputPath
Write-Host "✅ TUI flight data saved to: $outputPath" -ForegroundColor Green

# Clean up: Quit the browser
$driver.Quit()
Write-Host "✅ Selenium extraction completed!" -ForegroundColor Green

# ──────────────────────────────────────────────
# PART B: Parse the TUI Flight Data File
# ──────────────────────────────────────────────

# Helper function: Parse a Dutch date string (e.g., "di 24 jun.") into a DateTime object
function Parse-DateFromString($datumString) {
    $culture = [System.Globalization.CultureInfo]::GetCultureInfo("nl-NL")
    # Assume the format "xx dd mmm." (e.g., "di 24 jun.")
    $parts = $datumString.Split(" ")
    if ($parts.Length -ge 3) {
        $day   = $parts[1]
        $month = $parts[2].TrimEnd(".")
        $year  = (Get-Date).Year
        $dateStr = "$day $month $year"
        try {
            return [datetime]::ParseExact($dateStr, "dd MMM yyyy", $culture)
        } catch {
            return [datetime]::MinValue
        }
    } else {
        return [datetime]::MinValue
    }
}

# STEP 1: Automatically locate the newest file in C:\output matching the pattern
$directory = "C:\output"
$latestFile = Get-ChildItem -Path $directory -Filter "vluchten-*.txt" | 
              Sort-Object LastWriteTime -Descending | 
              Select-Object -First 1

if (-not $latestFile) {
    Write-Host "No file found in $directory" -ForegroundColor Red
    exit
}

$filePath = $latestFile.FullName
$content = Get-Content -Path $filePath
Write-Host "`nRead file: $filePath" -ForegroundColor Green

# STEP 2: Initialize variables and arrays to store parsed data
$heenVluchten = @()         # Storage for the first 7 days of outbound flights
$terugVluchten = @()        # Storage for the first 7 days of inbound flights
$vluchtenDetails = @()      # Storage for detailed flight information

$gevondenHeen = 0           # Counter for outbound flights found
$gevondenTerug = 0          # Counter for inbound flights found
$leesTerugVluchten = $false # Flag to switch to inbound flight processing after 7 outbound flights

# Variables to collect detailed flight information
$verwerkVlucht = $false     # Flag indicating if a flight block is being collected
$tempVlucht = @()           # Temporary storage for lines of a flight block
$vluchtCounter = 0          # Counter for the number of lines in the current flight block

$datum = ""                 # Stores the most recent date line encountered

# STEP 3: Read the file and process each line
foreach ($regel in $content) {

    # If currently collecting a detailed flight block
    if ($verwerkVlucht) {
        # End collection if the line indicates the start of a new block (e.g., "TUI fly Belgium")
        if ($regel -match "^TUI fly Belgium") {
            $verwerkVlucht = $false
            $tempVlucht = @()
            $vluchtCounter = 0
            continue
        }
        $tempVlucht += $regel
        $vluchtCounter++
        # Once 11 lines are collected, consider the block complete
        if ($vluchtCounter -eq 11) {
            $vluchtenDetails += [PSCustomObject]@{
                VluchtInfo = ($tempVlucht -join " ") -replace "\s+", " "
            }
            $verwerkVlucht = $false
            $tempVlucht = @()
            $vluchtCounter = 0
        }
        continue
    }
    
    # Process lines that start with a Dutch day abbreviation and a date, possibly with a price
    if ($regel -match "^(Ma|Di|Wo|Do|Vr|Za|Zo) \d{2} \w{3}\.?(\s+€\s*\d+,\d{2})?$") {
        $datum = $regel.Trim()
        if ($gevondenHeen -ge 7 -and -not $leesTerugVluchten) {
            $leesTerugVluchten = $true
        }
        $regexPattern = "^(?<datum>(Ma|Di|Wo|Do|Vr|Za|Zo) \d{2} \w{3}\.)(\s+(?<prijs>€\s*\d+,\d{2}))?$"
        $match = [regex]::Match($regel, $regexPattern)
        if ($match.Success) {
            $datum = $match.Groups["datum"].Value.Trim()
            if ($match.Groups["prijs"].Success -and $match.Groups["prijs"].Value.Trim() -ne "") {
                $prijsStr = $match.Groups["prijs"].Value -replace "[^0-9,]", ""
                $prijsStr = $prijsStr -replace ",", "."
                $vluchtObject = [PSCustomObject]@{
                    Datum = $datum
                    Prijs = [decimal]$prijsStr
                }
                if (-not $leesTerugVluchten) {
                    $heenVluchten += $vluchtObject
                    $gevondenHeen++
                } else {
                    if ($gevondenTerug -lt 7) {
                        $terugVluchten += $vluchtObject
                        $gevondenTerug++
                    }
                }
            }
        }
        continue
    }
    
    # Process lines that contain only a price (in the expected format)
    if ($regel -match "^€\s*\d+,\d{2}$") {
        $prijsStr = $regel -replace "[^0-9,]", ""
        $prijsStr = $prijsStr -replace ",", "."
        $vluchtObject = [PSCustomObject]@{
            Datum = $datum
            Prijs = [decimal]$prijsStr
        }
        if (-not $leesTerugVluchten -and $gevondenHeen -lt 7) {
            $heenVluchten += $vluchtObject
            $gevondenHeen++
        }
        elseif ($leesTerugVluchten -and $gevondenTerug -lt 7) {
            $terugVluchten += $vluchtObject
            $gevondenTerug++
        }
        continue
    }
    
    # Process lines that contain only a date (without a price)
    if ($regel -match "^(Ma|Di|Wo|Do|Vr|Za|Zo) \d{2} \w{3}\.$") {
        $datum = $regel.Trim()
        if ($gevondenHeen -ge 7 -and -not $leesTerugVluchten) {
            $leesTerugVluchten = $true
        }
        continue
    }
    
    # Start collecting detailed flight information for "TUI Airlines Nederland"
    if ($regel -match "^TUI Airlines Nederland") {
        $verwerkVlucht = $true
        $tempVlucht = @($regel)
        $vluchtCounter = 1
        continue
    }
}

# Before output, sort the outbound and inbound arrays based on the parsed date
$sortedHeen = $heenVluchten | Sort-Object { Parse-DateFromString $_.Datum }
$sortedTerug = $terugVluchten | Sort-Object { Parse-DateFromString $_.Datum }

# STEP 4: Display the results in formatted PowerShell tables

Write-Host "`n=== TUI First 7 Days for Outbound Flights ===" -ForegroundColor Cyan
if ($sortedHeen.Count -gt 0) {
    $sortedHeen | Format-Table -AutoSize
} else {
    Write-Host "No outbound flights found!" -ForegroundColor Red
}

Write-Host "`n=== TUI First 7 Days for Inbound Flights ===" -ForegroundColor Cyan
if ($sortedTerug.Count -gt 0) {
    $sortedTerug | Format-Table -AutoSize
} else {
    Write-Host "No inbound flights found!" -ForegroundColor Red
}

Write-Host "`n=== Detailed Flights (TUI Airlines Nederland) ===" -ForegroundColor Yellow
if ($vluchtenDetails.Count -gt 0) {
    $vluchtenDetails | Format-Table -Wrap -AutoSize
} else {
    Write-Host "No TUI Airlines Nederland flights found!" -ForegroundColor Red
}

Write-Host "`n✅ Script completed!" -ForegroundColor Green

# Build the final output array with the consolidated data

$finalOutput = @()

# Section 1: Corendon Flights
$finalOutput += "**Corendon Flights:**"
$finalOutput += ""  # Empty line for spacing
$finalOutput += $corendonOutput  # Contains both outbound and inbound flights from Corendon

# Section 2: First 7 Days for Outbound Flights (TUI)
$finalOutput += ""
$finalOutput += "=== TUI First 7 Days for Outbound Flights ==="
$finalOutput += ""
$finalOutput += "Date         Price"
$finalOutput += "----         -----"
foreach ($vlucht in $sortedHeen) {
    # Format the price using Dutch number formatting (e.g., 389,99)
    $prijsFormatted = $vlucht.Prijs.ToString("F2", [System.Globalization.CultureInfo]::GetCultureInfo("nl-NL"))
    $finalOutput += "{0,-12} {1}" -f $vlucht.Datum, $prijsFormatted
}

# Section 3: First 7 Days for Inbound Flights (TUI)
$finalOutput += ""
$finalOutput += "=== TUI First 7 Days for Inbound Flights ==="
$finalOutput += ""
$finalOutput += "Date         Price"
$finalOutput += "----         -----"
foreach ($vlucht in $sortedTerug) {
    $prijsFormatted = $vlucht.Prijs.ToString("F2", [System.Globalization.CultureInfo]::GetCultureInfo("nl-NL"))
    $finalOutput += "{0,-12} {1}" -f $vlucht.Datum, $prijsFormatted
}

# Section 4: Detailed Flights (TUI Airlines Nederland)
$finalOutput += ""
$finalOutput += "=== Detailed Flights (TUI Airlines Nederland) ==="
$finalOutput += ""
$finalOutput += "Flight Information"
$finalOutput += "------------------"
foreach ($detail in $vluchtenDetails) {
    $finalOutput += $detail.VluchtInfo
}

# Export the final output to a file in C:\output with a unique name
$outputFolder = "C:\output"
if (-Not (Test-Path $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder | Out-Null
}
$outputPath = Join-Path $outputFolder ("Flights_Output-{0}.txt" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$finalOutput | Out-File -Encoding UTF8 -FilePath $outputPath
Write-Host "✅ Flight data saved to: $outputPath" -ForegroundColor Green
