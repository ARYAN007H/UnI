# Us — "What have we been?"

The memory vault tab. Photos are the heroes; chrome recedes. Future home of the globe (cut from launch — plan §3 — spec leaves a placeholder note only).

## Layout (top → bottom)

1. **Header** — "Us" in Fraunces display + subtle couple name if set ("Maya & Aryan").
2. **Stats row** (one calm card, three numerals): days together (from `anniversary_date`), photos shared, voice minutes. Fraunces numerals, Inter labels. Static, no animations on numbers.
3. **Monthly recap entry** (existing feature, reskinned): latest recap card preview (1:1.4 card, accent border) + "Make this month's card" ghost button. Share via system sheet (plan §8 Phase 3 — RepaintBoundary → image).
4. **Photo timeline** — month-grouped:
   - Month header: Fraunces title ("October 2026") + count caption.
   - Grid: 3-col, full-bleed cells, 2dp gutters, `BlurHashedImage` placeholders everywhere (agent2 §7.2). Tall/landscape kept as-is (no forced crop in grid; viewer shows full).
   - Voice moments interleaved chronologically as mini player cards (waveform + date + play), not in the grid.
   - Tap photo → image viewer (existing `image_viewer_screen.dart` logic, reskinned: paper background, ink chrome, pinch-zoom, swipe between month items, download + delete-own actions in `Sheet`).
5. **Globe placeholder** — bottom quiet card: "A map of everywhere you've been — coming soon." Non-interactive. (Post-launch feature; keeps the promise visible without building it.)

## States
- **Loading:** skeleton stats row + skeleton grid (12 cells).
- **Empty:** `EmptyState` — "No memories yet." / "Every photo and voice note you share collects here, month by month." + ghost "Send your first photo" (deep-links to Chat composer).
- **Error:** grid fails per-month (inline retry on month section); stats fail silently to "—".

## Wires to
`MediaService` queries + BlurHash URLs `API-TBD (board)` (agent2 §7.2) · `Message` model (media/voice types) via local DB (§7.1 — this tab reads local SQLite, never network-first) · `Couple.anniversaryDate` for days-together · recap card: existing plan-item logic reskinned.

**11pm test:** grid photos render at slightly dimmed brightness in dark theme (like a photo album at night); stats are quiet; the only accent is the recap card border.
