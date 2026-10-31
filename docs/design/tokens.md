# Warm Editorial — token cheat sheet (Agent 1 → Agent 3)

Everything below is **already implemented** in `lib/core/theme/` — import the barrel:

```dart
import 'package:couple_chat/core/theme/theme.dart';
```

Access pattern in widgets (never hardcode):

```dart
final cs = Theme.of(context).colorScheme;          // standard roles
final t  = AppTheme.tokensOf(context);             // raw ColorTokens (AppRadii/AppSpacing too)
final u  = Theme.of(context).extension<UAndiThemeData>()!; // tokens, palette, sentBubble, onSentBubble
final tc = context.read<ThemeController>();        // palette.seed for vivid moments, mode switching
```

## Color roles (via `colorScheme`)
| Role | Value |
|---|---|
| `primary` / `onPrimary` | couple accent (contrast-fixed, AA vs white) / white |
| `primaryContainer` / `onPrimaryContainer` | soft accent tint / accent (light) or ink (dark) |
| `surface` | cards, sheets · `scaffoldBackgroundColor` = `tokens.base` (paper `#FAF6F1` / warm dark `#171412`) |
| `surfaceContainerHighest` | strongest surface |
| `onSurfaceVariant` | secondary text |
| `outline` / `outlineVariant` | hairlines / subtle borders (cards have 1px outlineVariant side) |

## Bubbles (via `UAndiThemeData` extension)
- Sent: `u.sentBubble` bg + `u.onSentBubble` text (soft tint on paper, deep accent on dark)
- Received: `t.receivedBubble` bg + `t.onSurface` text

## Typography
- **Fraunces** (w600): `displayLarge` 36, `displayMedium` 28, `headlineLarge` 24, `headlineMedium` 21, AppBar titles, Dialog titles → emotional voice: names, dates, screen headers
- **Inter**: everything else (`title*` 17/15 w600, `body*` 16/14, `label*` 14/12/10)
- Coupled color: couple accent for vivid moments only — `palette.seed`

## Scales
- Radii: `AppRadii` 4 / 8 / 12 / 16 / 24 / full — cards 16, inputs 12, sheets+dialogs 24, chips full
- Spacing: `AppSpacing` 4 / 8 / 16 / 24 / 32 / 48
- Motion: `AppDurations` 150 / 200 / 300 ms on `AppMotion.emphasized` (`easeOutCubic`); routes via `AppRouter.fadeThrough` / `slideUp` (`lib/core/router/app_router.dart`)

## Hard rules (plan §4.3)
1. No gradient on interactive elements — splash only
2. No blur/glass behind text, ever
3. Must look calm at 11pm
4. WCAG AA on every text/accent pair (palette derivation enforces it — don't override)
5. One empty/loading/error pattern — build them once in `lib/core/widgets/`

## Mode & palette control (main.dart wiring hint)
`ThemeController` (ChangeNotifier) → `MaterialApp(theme: AppTheme.light(tc.palette), darkTheme: AppTheme.dark(tc.palette), themeMode: tc.mode)`; call `tc.applyCoupleColor(couple.themeColorHex)` when the couple loads/changes.
