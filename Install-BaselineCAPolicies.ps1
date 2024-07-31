<#
.SYNOPSIS
    Dit script bevat een baseline voor MKB-organisaties om de volgende aanbevolen Conditional Access policies te creëren:
    
    CA001: Require multi-factor authentication for admins (Required)
    CA002: Securing security info registration (Optional)
    CA003: Block legacy authentication (Required)
    CA004: Require multi-factor authentication for all users (Required)
    CA005: Require multifactor authentication for guest access (Required)
    CA006: Require multi-factor authentication for Azure management (Required)
    CA010: Block access for unknown or unsupported device platform (Required)
    CA011: Session duration
    CA012: Require app protection
    CA014: Use application enforced restrictions for unmanaged devices (Optional)
    CA015: Block Directory Synchronization account from unknown locations
    CA016: Sign-in frequency for high risk apps

.NOTES
    1. Mogelijk moet u de 'Security defaults' eerst uitschakelen. Zie https://aka.ms/securitydefaults
    2. Geen van de door dit script aangemaakte policies zal standaard ingeschakeld zijn.
    3. Voordat u policies inschakelt, moet u eindgebruikers informeren over de verwachte impact.
    4. Zorg ervoor dat u de beveiligingsgroep 'sgu-Exclude from CA' vult met ten minste één beheerdersaccount voor noodgevallen.

.HOW-TO
    1. Om de Azure AD Preview PowerShell-module te installeren, gebruik: Install-Module AzureADPreview -AllowClobber
    2. Voer .\Install-BaselineCAPolicies.ps1 uit

.DETAILS
    FileName:    Install-BaselineCAPolicies.ps1
    Author:      Alex Fields, ITProMentor.com
    Updated by: Jacques Behr, BehrIT
    Created:     February 2022
    Updated:     July 2024
    VERSION:     2.0
#>

#Import-Module AzureADPreview
Connect-AzureAD

## Controleer het bestaan van de "Exclude from CA" beveiligingsgroep en maak de groep indien deze niet bestaat

$ExcludeCAGroupName = "sgu-Exclude From CA"
$ExcludeCAGroup = Get-AzureADGroup -All $true | Where-Object DisplayName -eq $ExcludeCAGroupName

if ($ExcludeCAGroup -eq $null -or $ExcludeCAGroup -eq "") {
    New-AzureADGroup -DisplayName $ExcludeCAGroupName -SecurityEnabled $true -MailEnabled $false -MailNickName sgu-ExcludeFromCA
    $ExcludeCAGroup = Get-AzureADGroup -All $true | Where-Object DisplayName -eq $ExcludeCAGroupName
}
else {
    Write-Host "Exclude from CA group already exists"
}

function Create-CAPolicyIfNotExists {
    param (
        [string]$PolicyName,
        [hashtable]$Conditions,
        [hashtable]$Controls = $null,
        [hashtable]$SessionControls = $null
    )

    $existingPolicy = Get-AzureADMSConditionalAccessPolicy | Where-Object {$_.DisplayName -eq $PolicyName}

    if ($existingPolicy -eq $null) {
        try {
            New-AzureADMSConditionalAccessPolicy -DisplayName $PolicyName -State "Disabled" -Conditions $Conditions -GrantControls $Controls -SessionControls $SessionControls
            Write-Host "Policy '$PolicyName' created" -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to create policy '$PolicyName'. Error: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "Policy '$PolicyName' already exists" -ForegroundColor Yellow
    }
    Start-Sleep -Seconds 2
}

# GLOBAL POLICIES:

########################################################
## CA001: Require multi-factor authentication for admins

$conditions = @{
    Applications = @{
        IncludeApplications = "All"
    }
    Users = @{
        IncludeRoles = @('62e90394-69f5-4237-9190-012177145e10', 'f28a1f50-f6e7-4571-818b-6a12f2af6b6c', '29232cdf-9323-42fd-ade2-1d097af3e4de', 'b1be1c3e-b65d-4f19-8427-f6fa0d97feb9', '194ae4cb-b126-40b2-bd5b-6091b380977d', '729827e3-9c14-49f7-bb1b-9608f156bbb8', '966707d0-3269-4727-9be2-8c3a10f19b9d', 'b0f54661-2d74-4c50-afa3-1ec803f12efe', 'fe930be7-5e62-47db-91af-98c3a49a38b1')
        ExcludeGroups = $ExcludeCAGroup.ObjectId
    }
}
$controls = @{
    _Operator = "OR"
    BuiltInControls = "MFA"
}

Create-CAPolicyIfNotExists -PolicyName "CA001: Require multi-factor authentication for admins" -Conditions $conditions -Controls $controls

########################################################
## CA002: Securing security info registration

$conditions = @{
    Applications = @{
        IncludeUserActions = "urn:user:registersecurityinfo"
    }
    Users = @{
        IncludeUsers = "All"
        ExcludeUsers = "GuestsOrExternalUsers"
        ExcludeGroups = $ExcludeCAGroup.ObjectId
        ExcludeRoles = "62e90394-69f5-4237-9190-012177145e10"
    }
    Locations = @{
        IncludeLocations = "All"
        ExcludeLocations = "AllTrusted"
    }
}
$controls = @{
    _Operator = "OR"
    BuiltInControls = "MFA"
}

Create-CAPolicyIfNotExists -PolicyName "CA002: Securing security info registration" -Conditions $conditions -Controls $controls

########################################################
## CA003: Block legacy authentication

$conditions = @{
    Applications = @{
        IncludeApplications = "All"
    }
    Users = @{
        IncludeUsers = "All"
        ExcludeGroups = $ExcludeCAGroup.ObjectId
    }
    ClientAppTypes = @('ExchangeActiveSync', 'Other')
}
$controls = @{
    _Operator = "OR"
    BuiltInControls = "Block"
}

Create-CAPolicyIfNotExists -PolicyName "CA003: Block legacy authentication" -Conditions $conditions -Controls $controls

########################################################
## CA004: Require multi-factor authentication for all users

$conditions = @{
    Applications = @{
        IncludeApplications = "All"
    }
    Users = @{
        IncludeUsers = "All"
        ExcludeGroups = $ExcludeCAGroup.ObjectId
    }
}
$controls = @{
    _Operator = "OR"
    BuiltInControls = "MFA"
}

Create-CAPolicyIfNotExists -PolicyName "CA004: Require multi-factor authentication for all users" -Conditions $conditions -Controls $controls

########################################################
## CA005: Require multifactor authentication for guest access

$conditions = @{
    Applications = @{
        IncludeApplications = "All"
    }
    Users = @{
        IncludeUsers = "GuestsOrExternalUsers"
        ExcludeGroups = $ExcludeCAGroup.ObjectId
    }
}
$controls = @{
    _Operator = "OR"
    BuiltInControls = "MFA"
}

Create-CAPolicyIfNotExists -PolicyName "CA005: Require multifactor authentication for guest access" -Conditions $conditions -Controls $controls

########################################################
## CA006: Require multi-factor authentication for Azure management

$conditions = @{
    Applications = @{
        IncludeApplications = "797f4846-ba00-4fd7-ba43-dac1f8f63013"
    }
    Users = @{
        IncludeUsers = "All"
        ExcludeGroups = $ExcludeCAGroup.ObjectId
    }
}
$controls = @{
    _Operator = "OR"
    BuiltInControls = "MFA"
}

Create-CAPolicyIfNotExists -PolicyName "CA006: Require multi-factor authentication for Azure management" -Conditions $conditions -Controls $controls

########################################################
## CA010: Block access for unknown or unsupported device platform

$conditions = @{
    Applications = @{
        IncludeApplications = "All"
    }
    Users = @{
        IncludeUsers = "All"
        ExcludeGroups = $ExcludeCAGroup.ObjectId
    }
    Platforms = @{
        IncludePlatforms = "All"
        ExcludePlatforms = @('Android', 'IOS', 'Windows', 'macOS')
    }
}
$controls = @{
    _Operator = "OR"
    BuiltInControls = "Block"
}

Create-CAPolicyIfNotExists -PolicyName "CA010: Block access for unknown or unsupported device platform" -Conditions $conditions -Controls $controls

########################################################
## CA011: Session duration

$conditions = @{
    Applications = @{
        IncludeApplications = "All"
    }
    Users = @{
        IncludeUsers = "All"
        ExcludeGroups = $ExcludeCAGroup.ObjectId
    }
}
$sessionControls = @{
    PersistentBrowser = @{
        IsEnabled = $true
        Mode = "always"
    }
    SignInFrequency = @{
        IsEnabled = $true
        Value = 1
        Type = "day"
    }
}

Create-CAPolicyIfNotExists -PolicyName "CA011: Session duration" -Conditions $conditions -SessionControls $sessionControls

########################################################
## CA012: Require app protection

$conditions = @{
    Applications = @{
        IncludeApplications = "All"
    }
    Users = @{
        IncludeUsers = "All"
        ExcludeGroups = $ExcludeCAGroup.ObjectId
    }
}
$controls = @{
    _Operator = "OR"
    BuiltInControls = @('ApprovedApplication', 'CompliantApplication')
}

Create-CAPolicyIfNotExists -PolicyName "CA012: Require app protection" -Conditions $conditions -Controls $controls 

########################################################
## CA014: Use application enforced restrictions for unmanaged devices

$conditions = @{
    Applications = @{
        IncludeApplications = "All"
    }
    Users = @{
        IncludeUsers = "All"
        ExcludeGroups = $ExcludeCAGroup.ObjectId
    }
    ClientAppTypes = @('Browser')
}
$sessionControls = @{
    ApplicationEnforcedRestrictions = @{
        IsEnabled = $true
    }
}

Create-CAPolicyIfNotExists -PolicyName "CA014: Use application enforced restrictions for unmanaged devices" -Conditions $conditions -SessionControls $sessionControls 

########################################################
## CA015: Block Directory Synchronization account from unknown locations

$conditions = @{
    Applications = @{
        IncludeApplications = "All"
    }
    Users = @{
        IncludeUsers = "All"
        ExcludeGroups = $ExcludeCAGroup.ObjectId
    }
    Locations = @{
        IncludeLocations = "All"
        ExcludeLocations = "AllTrusted"
    }
}
$controls = @{
    _Operator = "OR"
    BuiltInControls = "Block"
}

Create-CAPolicyIfNotExists -PolicyName "CA015: Block Directory Synchronization account from unknown locations" -Conditions $conditions -Controls $controls 

########################################################
## CA016: Sign-in frequency for high risk apps

$conditions = @{
    Applications = @{
        IncludeApplications = "All"
    }
    Users = @{
        IncludeUsers = "All"
        ExcludeGroups = $ExcludeCAGroup.ObjectId
    }
}
$sessionControls = @{
    SignInFrequency = @{
        IsEnabled = $true
        Value = 1
        Type = "hour"
    }
}

Create-CAPolicyIfNotExists -PolicyName "CA016: Sign-in frequency for high risk apps" -Conditions $conditions -SessionControls $sessionControls

Write-Host "Script completed" -ForegroundColor Cyan
