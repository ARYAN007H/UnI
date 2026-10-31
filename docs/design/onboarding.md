# Onboarding — the 3-step flow (plan §6)

Replaces the 7-gate funnel (~1–3% activation) with 3 steps. One decision per screen.
Target: ≥25% pair activation. Value arrives BEFORE the partner must act.

## Step 0 — 18+ gate (once, before anything)
- Plain screen: Fraunces line "One thing first" + Inter body "U&i is for adults. Are you 18 or older?"
- `AppButton(primary)` "Yes, I'm 18+" → proceeds. Ghost link "No — take me back" → exits app.
- Stored locally, never asked again. No age estimation tricks, no scanner — honest gate (compliance shell, plan §8 Phase 3 owns the store-side age rating).

## Step 1 — Sign in
See [auth.md](auth.md). Google OAuth primary, email-link fallback.

## Step 2 — Solo value ("Make it yours") — the step that fixes the funnel
Runs immediately after sign-in, BEFORE pairing. User #1 gets real things to do:
1. **Name screen**: one `AppTextField` ("What should they call you?") + optional avatar (camera/gallery via just-in-time media permission — the ONLY permission asked so far). Continue button works with empty avatar.
2. **Today's question**: Home's question card, pre-seeded and answerable RIGHT NOW.
   Copy above card: "Answer your first question — it unlocks when they join." Answer submits to the normal answer flow (sealed until partner answers, per home.md state b).
3. **First memory note** (optional, skippable): one `AppTextField` multiline ("Write your first note to them — they'll see it when they join") → stored as a pending `system`-flavored message delivered on pairing (agent2 API-TBD).
- **No permissions wall. No channel setup. No tutorial carousel.**

## Step 3 — Pair ("Bring them in")
See [pairing.md](pairing.md) for the share/deep-link/wait screens.

## Rules
- Progress is resumable: kill the app mid-step → relaunch lands on the same step (local flag per step).
- Back is always available until pairing completes; after pairing, onboarding never re-appears.
- Every step has a one-line "why" in Inter caption under the action — no mystery modals.

## Wires to
`AuthService` (session) · `DailyQuestionService` (first answer, API-TBD board) · profile upsert (existing, agent2 confirmed resilient) · local step flags (SharedPreferences/local DB §7.1).

**11pm test:** zero screens with more than one input field; warm paper; the "unlocks when they join" seal card is the emotional hook — quiet anticipation, not a locked-padlock warning.
