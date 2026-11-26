# 4 – Exchange Online

```powershell
Connect-ExchangeOnline -UserPrincipalName adm-cedric@nordlicht-lab.onmicrosoft.com
```

## Shared mailboxes
```powershell
# info@ for Sales, buchhaltung@ for Accounting
New-Mailbox -Shared -Name 'NordLicht Info' -Alias info -PrimarySmtpAddress info@nordlicht-lab.onmicrosoft.com
New-Mailbox -Shared -Name 'Buchhaltung' -Alias buchhaltung -PrimarySmtpAddress buchhaltung@nordlicht-lab.onmicrosoft.com

# Read & manage + appear automatically in Outlook
Add-MailboxPermission -Identity info -User anna.schmidt@nordlicht-lab.onmicrosoft.com -AccessRights FullAccess -AutoMapping $true
# Send as the shared address
Add-RecipientPermission -Identity info -Trustee anna.schmidt@nordlicht-lab.onmicrosoft.com -AccessRights SendAs -Confirm:$false

# Keep a copy of sent items in the shared mailbox (not only in the user's own mailbox)
Set-Mailbox info -MessageCopyForSentAsEnabled $true -MessageCopyForSendOnBehalfEnabled $true

Get-MailboxPermission info | Where-Object User -notlike 'NT AUTHORITY*'
```

## Distribution list
```powershell
New-DistributionGroup -Name 'Alle Mitarbeitenden' -Alias alle -Type Distribution
Add-DistributionGroupMember -Identity alle -Member anna.schmidt@nordlicht-lab.onmicrosoft.com
Set-DistributionGroup alle -RequireSenderAuthenticationEnabled $true   # no external senders
```

## Mail flow rule: external sender warning
```powershell
New-TransportRule -Name 'External sender warning' -FromScope NotInOrganization -SentToScope InOrganization `
  -ApplyHtmlDisclaimerLocation Prepend -ApplyHtmlDisclaimerFallbackAction Wrap `
  -ApplyHtmlDisclaimerText '<p style="background:#fff3cd;padding:6px;border:1px solid #e0a800">ACHTUNG: Diese E-Mail kommt von außerhalb der NordLicht Handel GmbH. Klicken Sie nicht auf Links, wenn Sie den Absender nicht kennen.</p>'
```

## Troubleshooting toolkit
| Problem | Tool |
|---|---|
| "My e-mail didn't arrive" | Exchange admin center › *Mail flow › Message trace* (or `Get-MessageTraceV2`) |
| Mailbox full | `Get-EXOMailboxStatistics user | Select TotalItemSize`; enable archive: `Enable-Mailbox user -Archive` |
| Outlook can't connect | Microsoft Remote Connectivity Analyzer / Support and Recovery Assistant |
| Spam / phishing reported | Microsoft Defender portal › *Submissions* and *Quarantine* |

📸 `screenshots/shared-mailbox.png`, `screenshots/message-trace.png`
