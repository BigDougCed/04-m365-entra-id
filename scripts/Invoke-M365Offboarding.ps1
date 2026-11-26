#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Users, Microsoft.Graph.Groups, Microsoft.Graph.Users.Actions, ExchangeOnlineManagement
<#
.SYNOPSIS
    Microsoft 365 leaver process: block, revoke, shared mailbox for the manager, auto-reply, remove groups.

.DESCRIPTION
    Order matters: the mailbox is converted to shared BEFORE the licence group is removed,
    otherwise the mailbox would be deleted 30 days after the licence is gone.

.EXAMPLE
    .\Invoke-M365Offboarding.ps1 -UserPrincipalName rene.lefevre@nordlicht-lab.onmicrosoft.com `
        -ManagerUpn marek.nowak@nordlicht-lab.onmicrosoft.com -TicketNumber REQ-1077 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][string]$UserPrincipalName,
    [Parameter(Mandatory)][string]$ManagerUpn,
    [Parameter(Mandatory)][ValidatePattern('^(INC|REQ)-\d+$')][string]$TicketNumber
)

$ErrorActionPreference = 'Stop'
Connect-MgGraph -Scopes 'User.ReadWrite.All', 'Group.ReadWrite.All', 'Directory.ReadWrite.All' -NoWelcome
Connect-ExchangeOnline -ShowBanner:$false

$user = Get-MgUser -UserId $UserPrincipalName -Property Id, DisplayName, AccountEnabled, Mail
$manager = Get-MgUser -UserId $ManagerUpn -Property Id, DisplayName, Mail
if (-not $PSCmdlet.ShouldProcess("$($user.DisplayName) <$UserPrincipalName>", "Offboard ($TicketNumber)")) { return }

function Write-Step($text) { Write-Host ("[{0:HH:mm:ss}] {1}" -f (Get-Date), $text) -ForegroundColor Green }

# 1. Block sign-in + revoke all refresh tokens / sessions
Update-MgUser -UserId $user.Id -AccountEnabled:$false
Revoke-MgUserSignInSession -UserId $user.Id | Out-Null
Write-Step 'Sign-in blocked and sessions revoked'

# 2. Mailbox -> shared, manager gets access
Set-Mailbox -Identity $UserPrincipalName -Type Shared
Add-MailboxPermission -Identity $UserPrincipalName -User $ManagerUpn -AccessRights FullAccess -AutoMapping $true | Out-Null
Write-Step "Mailbox converted to shared, FullAccess for $($manager.DisplayName)"

# 3. Auto-reply in German and English
$reply = @"
<p>Vielen Dank f&uuml;r Ihre Nachricht. $($user.DisplayName) ist nicht mehr bei der NordLicht Handel GmbH t&auml;tig.
Bitte wenden Sie sich an $($manager.DisplayName) ($($manager.Mail)).</p>
<p>Thank you for your message. $($user.DisplayName) no longer works at NordLicht Handel GmbH.
Please contact $($manager.DisplayName) ($($manager.Mail)).</p>
"@
Set-MailboxAutoReplyConfiguration -Identity $UserPrincipalName -AutoReplyState Enabled `
    -InternalMessage $reply -ExternalMessage $reply -ExternalAudience All
Write-Step 'Auto-reply set'

# 4. Remove from all groups (frees the licence via the licence group)
$memberships = Get-MgUserMemberOf -UserId $user.Id -All |
               Where-Object { $_.AdditionalProperties.'@odata.type' -eq '#microsoft.graph.group' }
foreach ($g in $memberships) {
    $name = $g.AdditionalProperties.displayName
    if ($g.AdditionalProperties.groupTypes -contains 'DynamicMembership') { Write-Host "    skip dynamic group $name"; continue }
    try {
        Remove-MgGroupMemberDirectoryObjectByRef -GroupId $g.Id -DirectoryObjectId $user.Id
        Write-Host "    removed from $name"
    } catch {
        Write-Warning "Could not remove from $name (mail-enabled security / distribution groups need Exchange): $($_.Exception.Message)"
    }
}
Write-Step "Removed from $(@($memberships).Count) group(s)"

# 5. Audit note on the account
Update-MgUser -UserId $user.Id -Department ("LEAVER {0:yyyy-MM-dd} {1}" -f (Get-Date), $TicketNumber)
Write-Step 'Done. Remaining: Intune wipe/retire of devices (project 05), hardware return, delete account after retention period.'
