# Chat — "What did we say?"

One continuous conversation (no channels). Media strip keeps memories visible while talking.

## Layout (top → bottom)

1. **AppBar** — partner display name + presence dot ("Maya · online"), back to Home. No per-channel theme (old system is cut).
2. **Media strip**: horizontal `BlurHashedImage` thumbs (64dp, 12r) of recent shared photos; tap → image viewer. Hidden when zero media.
3. **Conversation** — full-bleed, reverse-list, paginated 50/page (existing behavior):
   - Day separators: Fraunces caption ("October 30"), hairline rule.
   - `Bubble` variants per plan §4.2: text / media (BlurHash placeholder → fade-in) / voice (waveform + duration + play).
   - Sent = accent-tinted, right; received = surfaceContainer, left. Received bubble in *couple-accent-tinted neutral*, never partner-colored gimmicks.
   - Message states: pending (clock, 60% opacity, outbox-queued — sends offline per §7.1) → sent → read (soft double-check). Failed = inline retry affordance on bubble tap.
   - Edited shows "(edited)" caption; deleted renders "message deleted" tombstone.
   - Long-press → `Sheet`: Reply, Copy, React (6 fixed reactions), Edit (own, text only), Delete (own).
   - Reply = inline reply-preview bar above composer (quoting snippet), swipe-to-reply on bubble.
4. **Scroll-to-bottom** ghost FAB with unread count when scrolled up.
5. **Composer** (pinned): `AppTextField` grows to 4 lines, mic (hold-to-record → inline waveform preview → send/cancel), photo button (system picker via agent2 media API), send. Voice recording permission = just-in-time prompt (plan §6).

## States
- **Loading:** skeleton bubbles (3 sent / 2 received alternating).
- **Empty:** `EmptyState` — "Your story starts here." / "Say anything — it's just the two of you." + ghost button "Send a voice note".
- **Error:** load failure = inline card + retry. Send failure = bubble marked failed + tap-to-retry (outbox already holds it — plan §7.1: user data never lost).

## Wires to
`ChatService` single-channel stream + send API `API-TBD (board)` · outbox status for pending states §7.1 · `MediaService` pick/upload/BlurHash `API-TBD (board)` · read receipts + typing (broadcast topics §7.3) → typing dots under partner name only when partner is typing.

**11pm test:** bubbles at ~surface contrast (no pure-white received bubbles), media strip dims with theme, typing indicator is three soft dots not a spinner, composer never brighter than accent.
