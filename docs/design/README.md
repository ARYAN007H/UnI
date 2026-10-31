# U&i Design Specs — Warm Editorial (Phase A, agent3)

Blueprints for every screen, written against `docs/revival-plan.md` §4–§6.
Implementation consumes `lib/core/theme/` tokens ONLY (agent1). Specs are contracts, not suggestions.

## Index
| File | Screen | The question it answers |
|---|---|---|
| [home.md](home.md) | Home | "Where are we, right now?" |
| [chat.md](chat.md) | Chat | "What did we say?" |
| [us.md](us.md) | Us | "What have we been?" |
| [plans.md](plans.md) | Plans | "When do we meet next?" |
| [auth.md](auth.md) | Sign-in | "How do I get in?" |
| [onboarding.md](onboarding.md) | 3-step flow | "How do I start alone?" |
| [pairing.md](pairing.md) | Pair/deep-link | "How do we connect?" |
| [settings.md](settings.md) | Settings | "What do I control?" |
| [icon-splash.md](icon-splash.md) | Icon + splash | Brand brief |

## Shared patterns (referenced everywhere — defined ONCE here)

**EmptyState** (component: `EmptyState`): type-led, no illustrations. Pattern = one warm
line in Fraunces ("Nothing planned yet") + one Inter subline with the next action + optional
ghost button. Never joke copy. Never sad copy.

**Loading** (component: `Skeleton`): bone-colored blocks matching final layout shapes.
No spinners in content areas — spinner lives ONLY inside buttons and the splash.

**Error** (pattern: inline + `Toast`): content-area errors = inline card, one sentence,
one retry `AppButton(ghost)`. Action failures = `Toast` ("Couldn't send — saved to outbox").
Never a modal for recoverable errors. Never raw exception text.

**Motion:** 200–300ms, `Curves.easeOutCubic`. One entrance pattern per element type:
lists = fade+8dp rise staggered 30ms; sheets = slide-up; tab switch = crossfade 150ms.
No hero animations v1. No shimmer anywhere.

**11pm test (§4.3):** every spec ends with a check — screen must look calm in a dark room:
warm surfaces, no pure white/pure black, no red badges shouting, no numbers > 1 bold element
per viewport.

**Tokens reference (agent1's lib/core/theme/):** paper `#FAF6F1` / ink `#1A1613` (light),
`#171412` base (dark), couple accent seed terracotta `#C4573B` from `theme_color_hex`,
Fraunces (display) + Inter (body), radii 4/8/12/16/24/full, hairline `outlineVariant` borders.

**Wires-to convention:** every spec lists the services it consumes. Agent2 APIs are marked
`API-TBD (board)` until agent2 posts signatures — implementation waits for the board line.
