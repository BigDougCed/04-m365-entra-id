# 04 – Microsoft 365 & Entra ID Administration

![CI](https://github.com/BigDougCed/04-m365-entra-id/actions/workflows/ci.yml/badge.svg)

> 🇩🇪 **Kurzfassung:** Administration eines Microsoft-365-Tenants für die fiktive *NordLicht Handel GmbH*: Benutzer- und Lizenzverwaltung (gruppenbasiert), **MFA und Conditional Access** (inkl. Notfallkonten und Report-only-Test), Exchange Online (freigegebene Postfächer, Verteiler, Berechtigungen) sowie Onboarding/Offboarding per **Microsoft Graph PowerShell**. Dazu ein MFA-Registrierungsbericht für den Service Desk.

## 🎯 Scenario
NordLicht moves e-mail and files to Microsoft 365. IT has to:
1. Create users and assign licences automatically (no manual licence clicking)
2. Enforce MFA for everyone and block old, insecure sign-in protocols
3. Set up shared mailboxes for `info@` and `buchhaltung@`
4. Offboard leavers safely: block sign-in, revoke sessions, keep the mailbox for the team

## 🏗️ Tenant design
| Item | Value |
|---|---|
| Tenant | Microsoft 365 Business Premium trial (25 licences, includes Entra ID P1 + Intune) |
| Domain | `nordlicht.onmicrosoft.com` (a custom domain is optional for the lab) |
| Licensing | **Group-based:** member of `LIC_M365_BusinessPremium` → licence assigned automatically |
| Admin model | Daily work with a normal account; admin roles only on separate `adm-` accounts; 2 break-glass accounts excluded from CA |
| Usage location | `DE` (required before a licence can be assigned) |

## 📚 Guides
| # | Topic | Guide |
|---|---|---|
| 1 | Tenant setup, admin accounts, break-glass | [docs/01-tenant-setup.md](docs/01-tenant-setup.md) |
| 2 | User lifecycle and group-based licensing | [docs/02-user-lifecycle.md](docs/02-user-lifecycle.md) |
| 3 | MFA and Conditional Access baseline | [docs/03-mfa-conditional-access.md](docs/03-mfa-conditional-access.md) |
| 4 | Exchange Online: shared mailboxes, groups, permissions | [docs/04-exchange-online.md](docs/04-exchange-online.md) |

## 🧩 Scripts (Microsoft Graph PowerShell SDK)
| Script | What it does |
|---|---|
| [`New-M365User.ps1`](scripts/New-M365User.ps1) | Creates cloud users from CSV, sets usage location, adds them to the licence group and department group, temporary password |
| [`Invoke-M365Offboarding.ps1`](scripts/Invoke-M365Offboarding.ps1) | Blocks sign-in, revokes sessions, removes groups/licences, converts the mailbox to shared and grants the manager access, sets an auto-reply |
| [`Get-M365MfaReport.ps1`](scripts/Get-M365MfaReport.ps1) | Lists who has / hasn't registered MFA, admins without MFA first, exports CSV |

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
Install-Module ExchangeOnlineManagement -Scope CurrentUser

.\scripts\New-M365User.ps1 -CsvPath .\data\m365-users.csv -WhatIf
.\scripts\Get-M365MfaReport.ps1
```

## 🔐 Conditional Access baseline
| Policy | Users | Condition | Control | Start in |
|---|---|---|---|---|
| `CA001-AllUsers-RequireMFA` | All (excl. break-glass) | All cloud apps | Require MFA | Report-only → On |
| `CA002-AllUsers-BlockLegacyAuth` | All (excl. break-glass) | Client apps: Exchange ActiveSync, other clients | Block | On |
| `CA003-Admins-RequirePhishResistantMFA` | Directory roles (Global Admin, User Admin, …) | All cloud apps | Authentication strength: phishing-resistant | Report-only |
| `CA004-AllUsers-BlockOutsideEU` | All (excl. break-glass) | Locations: all except named location "EU" | Block | Report-only |
| `CA005-AllUsers-RequireCompliantDevice` | All (excl. break-glass) | Office 365 | Require compliant device (Intune, [project 05](https://github.com/BigDougCed/05-intune-endpoint-management)) | Report-only |

## ✅ Proof
- [ ] Users and licence group in the Entra admin center → `screenshots/users-licences.png`
- [ ] Conditional Access policy list → `screenshots/ca-policies.png`
- [ ] Sign-in log showing "Report-only: success/failure" for CA001 → `screenshots/ca-report-only.png`
- [ ] MFA prompt on first sign-in of a test user → `screenshots/mfa-registration.png`
- [ ] Shared mailbox with member permissions → `screenshots/shared-mailbox.png`
- [ ] Output of `Get-M365MfaReport.ps1` → `screenshots/mfa-report.png`

## 🧪 Help desk scenarios practised
| Ticket | Resolution |
|---|---|
| "I got a new phone, the Authenticator doesn't work anymore" | Verify identity → Entra › User › Authentication methods → *Require re-register MFA* / delete old method → user re-registers at aka.ms/mysecurityinfo |
| "Outlook keeps asking for my password" | Check sign-in logs for the failure reason (CA block? legacy client?), clear credentials in Credential Manager, new Outlook profile |
| "I can't see the shared mailbox" | FullAccess permission + AutoMapping; replication delay up to 60 min; restart Outlook |
| "Sign-in blocked" | Sign-in logs → *Conditional Access* tab shows which policy blocked and why |

## 🧰 Skills shown
Microsoft 365 admin center · Entra ID (users, groups, roles, sign-in logs) · group-based licensing · MFA & Conditional Access · Exchange Online · Microsoft Graph PowerShell · ExchangeOnlineManagement module

---
← [03 PowerShell automation](https://github.com/BigDougCed/03-powershell-ad-automation) · [Portfolio](https://github.com/BigDougCed) · [05 Intune](https://github.com/BigDougCed/05-intune-endpoint-management) →
