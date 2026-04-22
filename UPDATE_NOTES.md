# CDN-NETSHARE update notes (2026-04-22)

## UI style aligned to your reference
- Implemented a **dark deep-blue / glassmorphism** look across the app.
- Added a full-screen neon background (`assets/images/dark_neon_bg.jpg`) and wrapped major screens with `AppBackground`.
- Introduced reusable UI components:
  - `GlassCard` (blurred glass panels)
  - `GradientButton` (purple/blue premium button style like your screenshot)

## Verification support
- Dedicated **Resend verification email** screen.
- Link on Sign In for users who missed the first email.

## Guidance
- Home screen includes quick-start steps to guide users.

## What was NOT changed
- Core P2P / NAT / tunnel functionality was not modified.
