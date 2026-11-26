# 1 – Tenant setup

## Get a tenant
- Start a **Microsoft 365 Business Premium** free trial from the Microsoft 365 business plans page (25 licences, about one month). It includes Exchange Online, Teams, SharePoint, **Entra ID P1** (needed for Conditional Access and group-based licensing) and **Intune**.
- If you are eligible for the Microsoft 365 Developer Program sandbox, that works as well.
- Use a lab-only tenant name, e.g. `nordlicht-lab`. Put a reminder in your calendar to cancel the trial before it converts to a paid subscription.

## Admin accounts
| Account | Purpose | Roles |
|---|---|---|
| `cedric@…` | Daily use (mail, Teams) | none |
| `adm-cedric@…` | Administration | Global Administrator (lab); in production: User Administrator, Exchange Administrator, Intune Administrator as needed |
| `bg-admin1@…`, `bg-admin2@…` | **Break-glass** emergency access | Global Administrator, excluded from all Conditional Access policies, very long random password stored offline, sign-ins monitored |

Why separate admin accounts? If a daily account is phished, the attacker doesn't get admin rights.

## Turn off Security Defaults (only once CA is ready)
Security Defaults already enforce basic MFA. Conditional Access gives finer control but **can't be used at the same time**. Order:
1. Create break-glass accounts
2. Create the CA policies in **Report-only**
3. Entra admin center › *Overview › Properties › Manage security defaults* → Disabled
4. Switch CA001/CA002 to **On** the same day

## Company branding
Entra › *Company branding*: logo, background image, sign-in text in German ("Melden Sie sich mit Ihrem NordLicht-Konto an"). Users recognise the real sign-in page, which helps against phishing.

📸 `screenshots/admin-roles.png`, `screenshots/branding.png`
