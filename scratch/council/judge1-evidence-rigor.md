# JUDGE 1 — Evidence & Rigor

All 12 reports read. Ruling on the record — the two estimate-vs-estimate contradictions (Locket/Paired download counts, 7M vs 14M US LDR couples) are aggregator-vs-aggregator with no primary provenance on either side; ruling on source quality instead.

## A. EVIDENCE QUALITY SCOREBOARD

| # | Member | Rating | Reason |
|---|--------|--------|--------|
| 1 | Growth Marketer | STRONG | Multiple dated primary records (TechCrunch ×3, Business Insider 2025, Sensor Tower); flags weak sources as weak. LDR stats from a roundup is the only blemish. |
| 2 | Flutter Dev | STRONG | Only member who verified the actual repo (zero native targets, frozen May 2026); all package/doc citations current and checkable. |
| 3 | Infra Engineer | STRONG | Same-day fetched Supabase/LiveKit pricing, named Oracle-termination records; cost model is transparent extrapolation on documented unit prices. |
| 4 | Relationship Researcher | STRONG | Peer-reviewed citations with DOIs plus a COI teardown of the Paired study — the panel's most rigorous sourcing. |
| 5 | UX Researcher | STRONG | Canonical benchmarks (Chen, Branch 12M-link study, Adjust); funnel math shown with labeled assumptions. Reddit/Medium fillers. |
| 6 | Gen Z Consumer | MEDIUM | Real audience insight, but leans on SEO/marketing content (Sprinklr, LinkedIn, cybernews) and Reddit anecdote. |
| 7 | Millennial Couple | MEDIUM | Useful teardowns and the Couple/Pair post-mortem, but aggregator blogs (gobundled, Appstle) and single-user anecdotes. |
| 8 | Indie Founder | STRONG | PitchBook/TechCrunch funding records, RevenueCat base rates, dated graveyard; explicitly flags where no data exists. |
| 9 | Legal Counsel | STRONG | Primary statutes and dated regulations (§2258A, DPDP Rules notified 13 Nov 2025, AI Act Art. 50 from 2 Aug 2026). |
| 10 | Pricing Strategist | STRONG | RevenueCat 2025/2026 datasets (115k apps/$16B), 8-app price table, lifetime math shown — best quantitative base on the panel. |
| 11 | Competitive Analyst | MEDIUM | App map is checkable and corroborated; revenue figures are single-source "est." figures and white space is absence-based by its own admission. |
| 12 | Platform Expert | STRONG | Official Apple/Google docs plus documented timeline evidence (enrollment stalls, 14-day/12-tester Play test, ~40% rejection rate). |

## B. CLAIMS THAT SURVIVE UNANIMOUSLY OR NEAR-UNANIMOUSLY

1. **Native store apps first (point 8) — 12/12.** Decisive: #2's local repo verification (no widget/push/IAP targets exist), #8's "zero successful web-only couple apps found in the category record," #12's documented 3–6 month store gauntlet.
2. **Daily-question ritual as table stakes — 7 SUPPORT / 4 MIXED / 1 REFUTE-as-novel; zero refute utility.** #8 and #11 refute only the "moat" framing. Decisive: Paired's revenue record (#1, #10) plus Agapé's both-answer dose-response signal (#4). Streaks are stripped out (see C).
3. **LDR wedge as positioning — 8 SUPPORT / 4 MIXED / 0 REFUTE.** Decisive: Jiang & Hancock 2013 (LDR couples communicate more, #4), corroborated market scale (#1/#5/#8), Locket's LDR origin (#1, #5). Survives as acquisition wedge, not pricing power (#10: Agapé sits at the category's *low* end).
4. **Privacy-first brand (self-hosting removed)** — #4's passive-use/harm RCT literature, #7's payer-trust argument, #11's documented incumbent trust-failure corpus (Between Sept 2025 deletion, Official/Honeydue shutdowns).
5. **Freemium entry with post-pairing paywall** — universal; #5's Paired teardown (value before paywall) + #10's free-hook/gated-library architecture.

## C. CLAIMS REFUTED

1. **$59 one-time couple license as primary model** — refuted by #10 (RevenueCat: lifetime floor is 2.1–11.5x annual; $59 ≈ one median subscriber's lifetime value ≈ $56, forfeiting all rebills), #8 (every revenue-proven couple app is subscription), #3 (recurring media costs vs one-time revenue = negative margin within a year), #1 (LTV capped at 1–3x CPI).
2. **Streak mechanics** — #4 (Mogavi 2022, Hristova 2022, van Essen 2023: loss aversion, obligation, relationship strain), #6, #7.
3. **Self-hosting / Oracle free tier** — #3 (documented idle reclamation and account terminations with data purge), #2 (push still routes through FCM/APNs), #8 (wrong audience), #9 (transfers infrastructure, not controller duties).
4. **Widget-first as the opening move** — #5 (downstream of #8), #12 (native-gated 3–6 months), #11 (Widgetable occupies the ground; clones arrive in 2–3 weeks), #8 (2022 window closed).
5. **AI memory layer as branded pillar** — #9 (GDPR Art. 9 special-category data + AI Act Art. 50 compliance stack), #11 (Arya's $29.5M), #6/#7 (AI backlash; Ask Photos rollback).
6. **Monthly Wrapped as novel pillar** — #11 (a "Relationship Wrapped" app already ships monthly recaps), #8 (zero audited numbers).
7. **Gifting as an easy platform win** — #9/#10/#12: Apple has no IAP-gifting API, Play has none; fully custom build, iOS-only.
8. **Efficacy marketing à la Paired's "35.5%"** — #4's teardown: no control group, self-selection, lead author held a paid Paired role. Unusable as a claim template.

## D. GENUINELY CONTESTED ITEMS

1. **One-time license vs subscription.** Pro-lifetime's data (#7: 72% subscription-overwhelmed, 30–70% prefer one-time) is *stated* preference from commercial surveys. Anti-lifetime's data (#10, #8, #3) is *revealed* preference — actual payment records and the category's complete revenue history. Revealed preference wins. **Ruling: subscription-first $29.99–79.99/yr, one sub covers both; lifetime as secondary SKU at $99–149 if at all.** #7's insights survive as packaging (gifting, cancel-safe billing), not model.
2. **Widget priority.** #6 is the strongest pro voice but MEDIUM evidence; the anti side carries STRONG engineering (#2's dependency order), platform (#12), and competitive (#11) evidence. Operationally the "tie" resolves trivially: widgets require native (unanimous), so widget-first *sequencing* is dead — widget as launch surface after #8 ships, with #1's own caveat: retention built before the spike.
3. **Recap cadence.** #4's capitalization research supports the format but tests no cadence; #6's "annual only" rests on a Sprinklr marketing post #8 correctly dissects. Tie means: build it (1 dev-week, #2), ship monthly recap + annual Wrapped, decide by data, never as paywall headline (#10: winback asset).
4. **AI layer.** Cost data (#3: ~$0.15/couple/mo) and legal data (#9) don't conflict — it's cheap and legally heavy. Deciding evidence: sequencing (#8: unfunded spend pre-PMF) plus brand risk (#6, #11). **Defer; if shipped, invisible utility with on-device processing** (#2 and #9 converge here).

## E. UNCHALLENGED BUT SHOULD HAVE BEEN

1. **Where to launch.** #8 reasons from an India home market (Android-first, 15% fee, DPDP); #1/#5/#6 reason from a US LDR audience (iOS wedge, dollar CPI). The panel split by unexamined assumption about the founder's market, and nobody forced the contradiction into the open.
2. **The question-content pipeline.** Nine members endorsed the daily ritual; nobody asked who authors, licenses, or reviews 365 prompts/year — Paired fields a content team, and #9 shows bad claims carry FTC substantiation risk.
3. **Founder continuity.** The verified repo dormancy (frozen since May 2026) appears as color in three testimonies; nobody gated the strategy on it. A daily-ritual product with a lapsed maintainer is the documented category failure mode at founder level; only #8's kill-line addresses it.
4. **Breakup/deletion data rights.** The category's worst trauma (Couple/Pair 2019 data loss, Between Sept 2025) was used as marketing ammo (#7, #11) but never converted into the product requirement it obviously is: what happens to shared memories when one partner deletes, and who controls export.
5. **Internal brand contradiction.** Points 1 and 3 (filmed widgets, shareable cards) grow via the attention economy point 5 defines the brand against. #6 grazed it ("nowhere to share"); nobody adjudicated whether TikTok-fueled growth and a privacy manifesto can coexist — the answer determines the messaging, not just the feature list.
