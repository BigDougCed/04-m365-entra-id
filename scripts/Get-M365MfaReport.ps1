#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Reports
<#
.SYNOPSIS
    MFA registration report: who is protected, who isn't, admins first.

.DESCRIPTION
    Uses the Entra authentication methods registration report (needs Entra ID P1, included in Business Premium).
    Output: console summary + CSV. Use it before switching CA001 from Report-only to On.

.EXAMPLE
    .\Get-M365MfaReport.ps1
    .\Get-M365MfaReport.ps1 -OutputPath C:\Temp\mfa.csv
#>
[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path (Split-Path $PSScriptRoot -Parent) ('output\mfa-report-{0:yyyyMMdd}.csv' -f (Get-Date)))
)

$ErrorActionPreference = 'Stop'
Connect-MgGraph -Scopes 'AuditLog.Read.All', 'UserAuthenticationMethod.Read.All' -NoWelcome

$details = Get-MgReportAuthenticationMethodUserRegistrationDetail -All

$report = $details | ForEach-Object {
    [pscustomobject]@{
        User              = $_.UserPrincipalName
        Name              = $_.UserDisplayName
        IsAdmin           = $_.IsAdmin
        MfaRegistered     = $_.IsMfaRegistered
        MfaCapable        = $_.IsMfaCapable
        PasswordlessReady = $_.IsPasswordlessCapable
        DefaultMethod     = $_.DefaultMfaMethod
        Methods           = ($_.MethodsRegistered -join ', ')
        Risk              = if ($_.IsAdmin -and -not $_.IsMfaRegistered) { 'CRITICAL' }
                            elseif (-not $_.IsMfaRegistered) { 'HIGH' }
                            elseif ($_.MethodsRegistered -contains 'mobilePhone' -and $_.MethodsRegistered.Count -eq 1) { 'MEDIUM (SMS only)' }
                            else { 'OK' }
    }
} | Sort-Object @{ e = { switch -Wildcard ($_.Risk) { 'CRITICAL' { 0 } 'HIGH' { 1 } 'MEDIUM*' { 2 } default { 3 } } } }, User

$dir = Split-Path $OutputPath -Parent
if (-not (Test-Path $dir)) { New-Item $dir -ItemType Directory -Force | Out-Null }
$report | Export-Csv $OutputPath -NoTypeInformation -Encoding UTF8 -Delimiter ';'

$total = @($report).Count
$ok    = @($report | Where-Object Risk -eq 'OK').Count
Write-Host "`nMFA coverage: $ok of $total users OK ($([math]::Round(100 * $ok / [math]::Max($total,1)))%)" -ForegroundColor Cyan
$report | Group-Object Risk | Format-Table Name, Count -AutoSize
$report | Where-Object Risk -ne 'OK' | Format-Table User, IsAdmin, Methods, Risk -AutoSize
Write-Host "CSV: $OutputPath"
