# 2 – User lifecycle & group-based licensing

## Groups
| Group | Type | Purpose |
|---|---|---|
| `LIC_M365_BusinessPremium` | Security | Licence assignment: members get Business Premium automatically |
| `GG_Sales`, `GG_Accounting`, … | Security (or Microsoft 365 group for Teams) | Department access (SharePoint, Teams, CA targeting) |
| `DYN_AllStaff` | Dynamic security (Entra ID P1) | Rule: `(user.accountEnabled -eq true) and (user.userType -eq "Member")` |

Setting it up: Entra admin center › *Groups › LIC_M365_BusinessPremium › Licenses › Assignments* → Business Premium.
Check errors under *Licenses*; the most common one is a **missing usage location**.

## Joiner (new hire)
1. HR ticket with name, department, start date, manager
2. `New-M365User.ps1` creates the user (usage location DE, department, job title, manager, temporary password + change at first sign-in) and adds them to `LIC_…` + department group
3. On day 1: the user signs in → **MFA registration** (Microsoft Authenticator) at aka.ms/mysecurityinfo
4. Ticket: resolution note "user created, licence assigned via group, credentials handed to manager by phone"

## Mover (department change)
- Change `Department` attribute, swap department group, review shared-mailbox access. Licence stays (group-based).

## Leaver
`Invoke-M365Offboarding.ps1`:
| Step | Why |
|---|---|
| Block sign-in (`accountEnabled = false`) | Stops new sign-ins immediately |
| **Revoke sessions** (`Revoke-MgUserSignInSession`) | Existing tokens on phones/laptops stop working (otherwise they can stay valid for up to an hour or more) |
| Remove from groups (incl. licence group) | Frees the licence, removes Teams/SharePoint access |
| Convert mailbox to **shared** + manager FullAccess | Team keeps reading customer e-mails; shared mailboxes under 50 GB need no licence |
| Auto-reply (DE/EN) | Customers know who to contact |
| Device wipe / retire | Intune ([project 05](https://github.com/BigDougCed/05-intune-endpoint-management)) |

Important: convert the mailbox **before** the licence is removed. After the licence is gone the mailbox is deleted after 30 days.

## Hybrid note
In a hybrid company, users come from on-prem AD (project 02/03) through **Entra Connect Sync**. Then the leaver is disabled in AD and the change syncs to the cloud. Optional lab extension: install Entra Connect on a member server and sync `OU=NordLicht`.
