# Home — "Where are we, right now?"

The emotional anchor screen. Partner first, ritual second, everything else whispers.

## Layout (top → bottom)

1. **AppBar** — today's date in Fraunces title ("Thursday, 30 October"), settings ghost-icon right. No logo here.
2. **Partner presence card** (`AppCard`, hero):
   - Large `Avatar` + presence dot; display name in Fraunces headline.
   - Their local time + day-part line: "Their morning ☀ · 8:42 AM" — the LDR empathy line.
     Offline fallback: "Asleep in Delhi · 9 hours ahead" style, from last_seen.
   - Online = soft accent pulse on the dot (2s loop, opacity only). Tap → Chat.
3. **Today's question card** (`AppCard`, the ritual — plan §5/§7.4):
   - Category caption in Inter caption ("Just for today"), question text in Fraunces title.
   - State machine (drives the whole card):
     a. **Neither answered** → `AppButton(primary)` "Answer today's question" → answer `Sheet`.
     b. **Me answered, partner not** → sealed card: lock icon + "Sent to {partner} — unlocks when they answer". My answer NOT visible (not blurred — sealed: tinted surface + icon). Tapping shows "You answered: 🤍 (sealed until they answer)". Editable until reveal.
     c. **Both answered** → reveal: both answers side by side, partner's on accent-tinted surface; "Reply in chat" ghost link. Caption: "Answered {N} together" (soft, never a streak).
   - No question available → "Taking a breath today" quiet state, no CTA.
4. **Next countdown chip** (from Plans): "✈ 12 days until Goa" → tap → Plans tab. Hidden when none.
5. **Unread pulse**: if unread > 0, a calm line "2 new from {partner}" with warm dot → tap → Chat. No red badge.

## States
- **Loading:** skeleton matching card shapes (presence card + question card bones).
- **Empty:** not reachable — pairing flow guarantees a partner before Home. Defensive fallback = presence card shows "Waiting for {them}…" + link to pairing.
- **Error:** presence/question fail independently; each card degrades alone (question card → quiet state; presence → "—"). Never a full-screen error for partial data.

## Wires to
Presence + local time: agent2 presence API `API-TBD (board)` · Question of day + answer state: agent2 `DailyQuestionService` `API-TBD (board)` · Countdown: existing `Plan` model via ChatService/Plans query · Unread: ChatService count.

**11pm test:** presence card is the only hero; question card warm-tinted, not bright; countdown/pulse lines are Inter caption gray-ink — nothing louder than the person's name.
