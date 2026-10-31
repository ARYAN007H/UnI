# Auth — "How do I get in?"

One decision per screen. The sign-in screen sells nothing except privacy, in one line.

## Layout (top → bottom, single scroll)

1. **Brand block** (upper third, generous whitespace): "U&i" wordmark in Fraunces display (64pt+), one line beneath in Inter: "Your private space, together."
2. **Sign-in actions** (vertical stack, 12dp gaps):
   - `AppButton(primary)` full-width: **Continue with Google** (leading Google glyph). OAuth via Supabase (agent1 switched config to `publishableKey` — wire accordingly).
   - `AppButton(ghost)`: **Use an email link instead** → expands inline `AppTextField` (email) + "Send link" — magic-link fallback, no password field exists in v1 (removes the 24h-grace verification flow per plan §6).
3. **Trust footer** (pinned bottom, quiet): two Inter caption lines —
   "No ads. No tracking. Your words stay yours."
   "18+ only · Delete your account anytime"
4. **No splash-logo animation here** — splash has it (icon-splash.md); this screen must be usable in under 1 second.

## States
- **Loading:** spinner INSIDE the pressed button only; double-tap guarded.
- **Error:** OAuth cancel = silent return. OAuth/network failure = `Toast` "Couldn't sign in — try again". Email link sent = inline confirmation line under the field ("Check your inbox — the link works for 1 hour").
- **Already signed in:** never shown — router skips to Home/pairing (existing auth state machine decides; see pairing.md for entry states).

## Wires to
Existing `AuthService` OAuth/magic-link methods — API unchanged unless agent2 posts `API:` on board. No new backend in this lane.

**11pm test:** paper background, ink wordmark, one accent button — the darkest thing on screen is the text. No illustration shouting in the dark.
