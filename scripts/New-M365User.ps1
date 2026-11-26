#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Users, Microsoft.Graph.Groups
<#
.SYNOPSIS
    Creates Microsoft 365 cloud users from a CSV and licenses them through group membership.

.DESCRIPTION
    For each row: creates the user (usage location DE, department, job title, temporary password,
    must change at first sign-in), sets the manager, and adds the user to the licence group and the
    department group. Licences are NOT assigned directly: group-based licensing does that.

.PARAMETER CsvPath
    Columns: FirstName, LastName, Department, JobTitle, Manager (UPN prefix, optional)

.EXAMPLE
    .\New-M365User.ps1 -CsvPath ..\data\m365-users.csv -Domain nordlicht-lab.onmicrosoft.com -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][ValidateScript({ Test-Path $_ -PathType Leaf })][string]$CsvPath,
    [Parameter(Mandatory)][string]$Domain,
    [string]$LicenceGroup = 'LIC_M365_BusinessPremium',
    [string]$UsageLocation = 'DE'
)

$ErrorActionPreference = 'Stop'

# Username + password helpers (same module as project 03, copied into src/ so this repo is self-contained)
Import-Module (Join-Path (Split-Path $PSScriptRoot -Parent) 'src\NordLichtTools.psm1') -Force

Connect-MgGraph -Scopes 'User.ReadWrite.All', 'Group.ReadWrite.All', 'Directory.Read.All' -NoWelcome

function Get-GroupId([string]$Name) {
    $g = Get-MgGroup -Filter "displayName eq '$Name'" -ConsistencyLevel eventual -CountVariable c
    if (-not $g) { throw "Group '$Name' not found. Create it first (see docs/02-user-lifecycle.md)." }
    return @($g)[0].Id
}

$licenceGroupId = Get-GroupId $LicenceGroup
$results = foreach ($row in (Import-Csv $CsvPath -Encoding UTF8)) {
    try {
        $alias = ConvertTo-NLUsername -FirstName $row.FirstName -LastName $row.LastName
        $upn   = "$alias@$Domain"

        if (Get-MgUser -Filter "userPrincipalName eq '$upn'" -ErrorAction SilentlyContinue) {
            Write-Warning "$upn already exists - skipped"
            [pscustomobject]@{ UPN = $upn; Status = 'Exists'; TempPassword = $null }
            continue
        }
        if (-not $PSCmdlet.ShouldProcess($upn, 'Create M365 user + add to licence and department group')) { continue }

        $temp = New-NLRandomPassword -Length 16
        $user = New-MgUser -AccountEnabled `
            -DisplayName "$($row.FirstName) $($row.LastName)" `
            -GivenName $row.FirstName -Surname $row.LastName `
            -UserPrincipalName $upn -MailNickname ($alias -replace '\.', '') `
            -Department $row.Department -JobTitle $row.JobTitle `
            -CompanyName 'NordLicht Handel GmbH' -UsageLocation $UsageLocation `
            -PasswordProfile @{ Password = $temp; ForceChangePasswordNextSignIn = $true }

        New-MgGroupMember -GroupId $licenceGroupId -DirectoryObjectId $user.Id
        $deptGroup = "GG_$($row.Department)"
        try { New-MgGroupMember -GroupId (Get-GroupId $deptGroup) -DirectoryObjectId $user.Id }
        catch { Write-Warning "Department group $deptGroup missing - $upn not added" }

        if ($row.Manager) {
            $mgr = Get-MgUser -Filter "userPrincipalName eq '$($row.Manager)@$Domain'" -ErrorAction SilentlyContinue
            if ($mgr) {
                Set-MgUserManagerByRef -UserId $user.Id -BodyParameter @{ '@odata.id' = "https://graph.microsoft.com/v1.0/users/$($mgr.Id)" }
            }
        }

        Write-Host "[+] $upn created" -ForegroundColor Green
        [pscustomobject]@{ UPN = $upn; Status = 'Created'; TempPassword = $temp }
    } catch {
        Write-Warning "FAILED $($row.FirstName) $($row.LastName): $($_.Exception.Message)"
        [pscustomobject]@{ UPN = "$($row.FirstName) $($row.LastName)"; Status = "Failed: $($_.Exception.Message)"; TempPassword = $null }
    }
}

$results | Format-Table UPN, Status -AutoSize
Write-Host 'Licences are assigned by the group within a few minutes. Check: Entra > Groups > ' -NoNewline
Write-Host "$LicenceGroup > Licenses." -ForegroundColor Cyan
Write-Host 'Temporary passwords are in $results (not written to disk). Give them to the manager by phone.' -ForegroundColor Yellow
