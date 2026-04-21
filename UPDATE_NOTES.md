# Update notes (2026-04-21)

## UI overhaul (entire app)
- Added a centralized **AppTheme** (modern Material 3 styling) for better typography, cards, inputs, buttons, list tiles, and snackbars.
- Restyled key screens for a cleaner, more premium look:
  - Home
  - Account
  - Paywall
  - Auth screens (sign-in / sign-up)
- Improved consistency across the app by removing hardcoded `inversePrimary` AppBar backgrounds.
- Refreshed shared UI widgets used across Server/Client flows (`StatusCard`, `ConnectionCodeDisplay`, `ConnectionCodeInput`).

## Branding
- Replaced all user-facing **NATProxy** text with **CDN-NETSHARE** (app title, auth screens, headers, and Android notifications).

## Auth hardening (Supabase)
- Signup now blocks any email that already exists in `auth.users` (including users who signed up but have not verified email yet).
- Added “resend verification email” flows in both signup and sign-in.

## What was NOT changed
- Core P2P / NAT / tunnel functionality was **not** modified.

## Database change applied (Supabase project: `bztwadpqoohabbemqutp`)
A migration was applied to add an RPC used by the app:
- `public.check_signup_email(p_email text) -> jsonb { exists: bool, confirmed: bool }`
