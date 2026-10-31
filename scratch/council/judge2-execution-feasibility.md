# JUDGE 2 — Execution & Feasibility

*Convention: dev-week (dw) ≈ 30–35 focused hours. Where testimonies conflict, the higher estimate is used.*

## A. THE DEPENDENCY MAP

| Stage | Work | dw | Source | Blocks |
|---|---|---|---|---|
| S0 (calendar, ~0 dev) | Apple + Play accounts, W-8BEN, recruit 12+ closed testers | 2–6 wk clock | #12 | All submission |
| S1 | SDK 3.41.9→3.47.x, unvendor, deps, Play API-36, iOS archive pipeline, one store build | 3–4 | #2 | Everything native |
| S2 | Compliance shell: UGC report/block/filter, 18+ gate, account deletion (both stores), privacy labels/Data Safety, minimal export | 1.5 | #9 (24–36 h) + deletion flows | First submission |
| S3 | Push infra (Supabase→FCM/APNs) | 1–2 | #2 | Ritual on native |
| S4 | Daily ritual + 365-prompt seed content | 1–1.5 | #2, J1§E2 | Launch |
| S5 | Recap cards (RepaintBoundary→share) | 1 | #2 | Launch — parallel |
| S6 | Funnel rebuild: OAuth, magic-link pairing, solo value pre-pairing | ~2 | inferred from #5 | Launch — parallel |
| S7 | IAP: single annual subscription SKU | 1–2 | #2 | Launch — parallel |
| S8 | Widget v1 (non-interactive, 1 reload/day timeline) | 3–5 | #2, #12 | After production |

**Critical path:** S0→S1→S2→S3→S4→submit→14-day closed test→review→production→S8. Parallelizable: S5–S7, R2 media migration (~1 dw), listing/ASO assets (#1), question-content authoring. The original strategy inverts this order (widgets before stores); #2, #5, #12 independently confirm that inversion is the top failure mode. Note: Play's API-36 deadline (Aug 31, 2026) has already passed — S1 is not sequencing advice, it is blocking compliance today.

## B. WHAT GETS CUT

1. **Synced lofi room.** Cost: 4+ dw for "a mediocre result" (#2) plus ~$875/mo LiveKit at 1k couples (#3). Value: zero evidence in the record. **CUT** (async playlist at most).
2. **AI memory layer.** Cost: 2–3 dw (#2) + 12–20 h legal re-scope + $2,000–5,000 counsel + DPIA + AI Act Art. 50 disclosures (#9). Value: Arya's $29.5M owns the lane (#11); branded AI reads as slop to Gen Z (#6); Ask Photos rolled back (#7). **CUT pre-PMF**; revisit as invisible on-device utility.
3. **Self-hosting/Oracle.** Cost: permanent ops load; Oracle documented account terminations with data purge (#3). Value: homelabbers, not couples (#8). **CUT**; keep one-click export in S2 as the trust artifact (#7, J1§E4).
4. **Gifting + one-time-license ledger.** Cost: no gifting API on either store — custom two-user IAP ledger plus Android redemption codes (#9, #10, #12), 2+ dw. Value: unproven demand (#11); model refuted (J1§D1). **CUT from v1.**
5. **Streaks.** Cost ~0, value negative (loss-aversion/obligation literature, #4). **CUT by design.**
6. **Interactive widgets / App Intents / lock-screen & watch targets.** Cost: native Swift/Kotlin beyond scope (#2, #12). **DEFER to v2.**
7. **EXIF globe.** Cost: single-maintainer 87-like dependency, shader GPU cost, `--wasm` requirement (#2). Value: absence-based white space only (#11 concedes). **CUT from launch.**

## C. WHAT GETS BUILT — "launch" ≈ 12 dw

Sprints (1 sprint = 1 dw): **S1** SDK/compliance upgrade, unvendor, CI → **S2** API-36 + archive pipeline + internal-track build → **S3** compliance shell, deletion, export → **S4** funnel rebuild (Paired's sequence: OAuth, magic link, solo-value preview, #5) → **S5** ritual backend + prompt seed → **S6** push → **S7** recap cards + share sheet (works pre-widget; #12 verdict 3) → **S8** annual IAP + restore + listings + long-tail ASO ("long distance app for couples," #1) → submit. That pair of native apps with ritual, push, cards, funnel and one subscription **is** launch; widgets are post-launch.

## D. TIMELINE & MILESTONES

Assumption: ~20–25 h/wk → 1 dw ≈ 1.5–2 calendar weeks; store clocks run regardless. (Full-time floor = #12's 12–16 weeks to stores.)

- **Wk 0–2:** accounts filed; Apple enrollment is the serial risk (48 h official, 12–40+ days documented, #12); W-8BEN for 15% treaty withholding (#8). Testers recruited now, not month 4.
- **M1 (mo 2):** internal build ships. **Mo 2–4:** compliance + funnel. **M2 (mo 4):** feature-complete beta.
- **M3 (wk ~18–20):** Play closed test starts (14 days, fixed) ∥ Apple submission. Add 1–2 wk for a rejection cycle (~40% first-submission odds; Apple 48 h–10+ days, Play 1–7 days).
- **M4 (mo 6, range 5–7):** production on both stores.
- **M5 (mo 8–10):** widget v1 (S8's 3–5 dw post-production). #12's 4–6-month floor holds only full-time.
- **Kill-line (#8, adopted):** if <5,000 installs and <$500 MRR at day 90 post-launch, stop and preserve the asset.

## E. THE OPERATING BUDGET

**At 0 users:** Supabase Pro **$25/mo** (spend cap ON — not optional: free tier pauses after 7 days idle, silently killing ritual/push, #2/#3); R2 ~$0–1; Vercel $0; FCM $0. **Total ≈ $25–30/mo.** One-time: Apple $99/yr, Play $25, legal $0 (the $2–5k counsel attaches only to the cut AI layer).

**At 1,000 couples** (media-heavy, #3: 10 GB egress + 5 GB storage each): Supabase-only ≈ **$1,050/mo**; with R2 ≈ **$100–110/mo** ($25 + ~$75 storage, egress $0) — which is why the R2 migration is existential, not optional. Media-light collapses to ~$30/mo.

**Cross-check (#10):** 1,000 couples = 2,000 installs × 2.1% D35 ≈ 42 payers ≈ $240 peak MRR decaying at 72% year-1 churn. The only real constraint is not features — it is founder hours surviving the month-6-to-9 gap between stores live and the widget spike.
