# 3 – MFA & Conditional Access

## Authentication methods policy
Entra › *Protection › Authentication methods › Policies*
| Method | Setting |
|---|---|
| Microsoft Authenticator | Enabled for all, **number matching** + app name and location shown |
| FIDO2 security keys / passkeys | Enabled for admins (phishing-resistant) |
| SMS / voice call | Disabled (weak against SIM swapping), or only as a temporary fallback |
| Temporary Access Pass | Enabled for the help desk to onboard users or replace lost phones |

## Named location
*Conditional Access › Named locations*: `EU`: countries = EU member states (+ countries where staff travel). Used by CA004.

## Policies
For each: *Users* → Include all users, **Exclude** `bg-admin1` and `bg-admin2`.

### CA001-AllUsers-RequireMFA
- Target resources: All cloud apps
- Grant: Require multifactor authentication
- Session: none
- State: Report-only for 2–3 days → check sign-in logs → **On**

### CA002-AllUsers-BlockLegacyAuth
- Conditions › Client apps: *Exchange ActiveSync clients*, *Other clients*
- Grant: **Block access**
- Why: legacy protocols (POP, IMAP, SMTP AUTH, old Office) can't do MFA, so attackers use them for password spraying

### CA003-Admins-RequirePhishResistantMFA
- Users: Directory roles (Global Administrator, Exchange Administrator, User Administrator, Intune Administrator, Helpdesk Administrator)
- Grant: Require **authentication strength** → *Phishing-resistant MFA*
- Report-only until admins have a FIDO2 key or passkey registered

### CA004-AllUsers-BlockOutsideEU
- Conditions › Locations: Include *Any location*, Exclude *EU*
- Grant: Block

### CA005-AllUsers-RequireCompliantDevice
- Target: Office 365
- Grant: Require device to be marked as compliant (Intune compliance from project 05)
- Report-only until all laptops are enrolled

## Testing
1. **What If** tool (*Conditional Access › Policies › What If*): choose a user, app and location → shows which policies apply
2. Sign in as a test user in a private browser window
3. *Sign-in logs* › open the entry › *Conditional Access* and *Report-only* tabs

## Help desk: lost phone
1. Verify identity (callback on the number in the HR system, or the manager confirms)
2. Entra › Users › *Authentication methods* → delete the old Authenticator, *Revoke multifactor authentication sessions*
3. Issue a **Temporary Access Pass** (valid 1 hour, one use)
4. User signs in with the TAP and registers the new phone
5. Document in the ticket (don't write the TAP itself in the ticket)

📸 `screenshots/auth-methods.png`, `screenshots/ca-policies.png`, `screenshots/ca-whatif.png`
