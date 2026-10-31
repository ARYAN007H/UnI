# Settings — "What do I control?"

A settings screen IS a trust surface for this brand (plan §1: can't betray users). The trust section is first-class, not buried.

## Layout (grouped list, `SectionHeader` + rows; no tabs)

1. **Profile** — avatar (tap → picker), display name, status text (existing fields).
2. **Us** — couple name, anniversary date (picker), **accent color**: 8 curated warm swatches + custom hex input → writes `theme_color_hex` (existing column; whole app restyles live — the surviving personalization feature, plan §3).
3. **Trust** (the brand section — never collapsed):
   - "Export everything" → full export: JSON + media zip (agent2 §7.1 export wires to local DB) → share sheet. Copy: "Your data, in your hands. One tap."
   - "What leaves your device" → static page: plaintext = Supabase (RLS-protected); photos/voice = encrypted to private R2 (§7.5); no ads, no AI training, no third-party analytics. Honest list.
   - "Delete account" → destructive confirm Sheet: explains what partner sees afterward, 72h undo window (compliance shell, plan Phase 3).
4. **Notifications** — daily question toggle, messages toggle (per-channel granular = cut with channels).
5. **Appearance** — theme: system / paper (light) / candlelight (dark). Default system.
6. **Vanilla mode** — existing toggle, reskinned, one-line description ("calmer colors, fewer animations").
7. **About** — version, build log link (BUILDLOG.md published URL), "Made by one person, for two." 

## States
All rows act immediately with `Toast` confirmation; destructive actions get confirm Sheets.
Export in progress: button → inline progress; success → share sheet auto-opens.

## Wires to
`AuthService` (profile/couple updates) · export service: agent2 `API-TBD (board)` (§7.1 makes this nearly free — local DB is the export) · `AppTheme` accent re-mapping via agent1 tokens (REQUEST to @agent1 if a `setCoupleAccent()` token API is needed).

**11pm test:** it's a list, not a dashboard; trust rows read like a promise, not a legal page.
