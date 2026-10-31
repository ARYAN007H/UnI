# Plans — "When do we meet next?"

The countdown tab — the LDR heartbeat. The next meeting is the loudest thing on the screen, because it's the thing both people are waiting for.

## Layout (top → bottom)

1. **Countdown hero** (next upcoming plan only):
   - Big Fraunces numeral ("12" + "days" Inter label beneath) — the single boldest element in the tab.
   - Plan title ("Goa trip ✈"), location caption, date.
   - LDR detail line when partners are in different timezones: "They land 6:40 PM their time · 9:10 PM yours" (uses partner timezone from presence data).
   - Tap hero → plan detail `Sheet`.
2. **Add plan** — `AppButton(primary)` full-width: "Plan the next hug". Opens create `Sheet`: title, date picker, location (free text v1), note. Creating posts a `plan`-type message to Chat (existing behavior — partner sees it in conversation too).
3. **Upcoming list** — plan cards (`AppCard`): title, date + relative ("Sat · in 3 days"), location, status chip (upcoming = accent outline). Swipe or ⋯ → edit/complete/delete (existing `Plan` model operations).
4. **Past plans** — collapsed `SectionHeader` ("Past · 8"), tap to expand; completed plans with muted checkmark chips.

## States
- **Loading:** skeleton hero + two skeleton cards.
- **Empty:** `EmptyState` — "Nothing planned yet." / "Distance counts down better with a date on the calendar." + primary "Plan the next hug".
- **Error:** inline card + retry (reads from local DB per §7.1, so errors are rare — mostly first-run).

## Wires to
Existing `Plan` model + plan messages via `ChatService` `API-TBD (board)` · partner timezone: agent2 presence API · countdown computed client-side (no server dependency — same philosophy as §7.4).

**11pm test:** countdown numeral in warm ink, not accent-red; "days" never pluralizes as "DAYS!!"; past section collapsed by default keeps the screen short at night.
