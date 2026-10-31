# Pairing — "How do we connect?"

Deep-link first, code entry dead (plan §6: invite conversion 5–20% typical; code-typing is the floor).
Three screens: invite-share, invite-confirm, waiting/celebration.

## Screen 1 — Invite share (shown to user #1, from onboarding Step 3 or Home when unpaired)
- Fraunces line: "Bring them in"
- Inter body: "Send them one link. One tap and you're connected — no codes."
- `AppButton(primary)`: **Share invite link** → system share sheet with deep link (`https://<host>/pair?c=<coupleId>&u=<userId>` — tokenized; exact scheme waits for agent2/router API-TBD).
- Quiet fallback: "Having trouble? Copy link" ghost option (clipboard + Toast).
- Below: the populated app preview is VISIBLE behind/around this card (user #1 already has value from Step 2) — this screen is a card in Home, never a dead-end page.

## Screen 2 — Invite confirm (partner's device, deep link landed)
- "Maya invited you to U&i" — inviter name + avatar, Fraunces welcome.
- If not signed in → auth.md first, then return here (state preserved via link params).
- `AppButton(primary)` "Accept — pair up". Ghost: "Not now" (link stays valid; re-openable).
- Error states as inline cards: expired link → "This invite expired — ask for a new one" (regenerable by inviter); already-paired user → "You're already paired with someone — account deletion required first" (link to settings.md); self-pair → gentle Toast, no error screen.

## Screen 3 — Waiting (user #1, after sharing, pre-acceptance)
- NEVER a polling spinner (old funnel's worst screen is deleted).
- Home renders fully populated (Step 2 value visible: sealed question card reads "waits for Maya" using pending-partner placeholder name if known).
- Waiting card on Home: "Invite sent to {name/handle} · we'll ping you when they join" + "Share again" ghost. On partner accept → push notification (agent2 fan-out §7.3) + card dissolves into presence card.

## Celebration (both, on pair completion)
- One quiet moment, 1.5s: both avatars slide together into the presence card, soft accent pulse. No confetti. No modal. Then → Home.
- `anniversary_date` set to pairing timestamp (existing model); editable later in settings.

## Wires to
`AuthService` couple join/create APIs — existing join-by-deep-link needs agent2 to expose link parsing + auto-pair RPC `API-TBD (board)` (agent2 §7.1 may fold this into outbox sync) · invite token/link generation: REQUEST posted to @agent2 (see board) · notification on accept: agent2 fan-out.

**11pm test:** waiting state shows a populated app, not a progress bar; celebration is a breath, not a fireworks loop.
