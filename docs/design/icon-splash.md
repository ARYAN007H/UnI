# Icon + Splash brief — brand marks

## App icon
- **Mark:** "U&i" as a ligature — the U and i drawn as two forms leaning toward each other,
  the i's dot becoming a small heart-space (negative space, not a printed heart). Alternative
  direction: two overlapping rounded-square outlines (two rooms, one doorway).
- **Palette:** terracotta `#C4573B` mark on cream `#FAF6F1` field. No gradients, no gloss, no glass.
- **Shape:** full-bleed rounded-square (Android adaptive: foreground mark 66% safe zone, cream background layer).
- **Test:** legible at 48dp in a drawer of 200 icons; reads in dark-mode dock without a halo.
- Deliverable: SVG master + adaptive icon XML (agent3 builds; icon export via flutter_launcher_icons config — dep request to @agent1 if missing).

## Splash
- Cream field (paper), wordmark "U&i" in Fraunces centered, Inter subline "Your private space together" fading in.
- **The ONE allowed gradient in the app** (plan §4.3 rule 1): a barely-there vertical wash,
  cream → 2% terracotta at the bottom edge. Nothing else.
- Motion: wordmark fade + 8dp rise, 300ms easeOutCubic; holds until services init; total ≤ 2s
  (spinner lives here only while Supabase init runs — main.dart wiring, agent3).
- Dark theme splash: candlelight base `#171412`, warm-ink wordmark.

## In-app brand usage rules
- Wordmark appears ONLY on splash, auth, and settings About — never in AppBars (screens own their titles).
- The mark never carries a gradient, shadow, or blur. It's typography, not a mascot.
