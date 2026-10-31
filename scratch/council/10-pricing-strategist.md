# COUNCIL MEMBER #10 — Monetization/Pricing Strategist

## VERDICTS (1–8)

1. **Widget-first acquisition — MIXED.** Widgetable proves widgets acquire (10M+ installs) but monetize poorly: premium is only $19.99/yr, $4.99/mo, charged *per partner* ([store data](https://play.google.com/store/apps/details?id=com.lovewidget.petpn)), and its #1 review complaint is ads. Widgets are a funnel, not a price ceiling — keep them free.
2. **Daily-question ritual — SUPPORT.** Paired's free tier = one daily question; the entire premium library is gated ([paired.com](https://www.paired.com/articles/relationship-support-theres-an-app-for-that)). This free-hook/pay-gated-library split is the category's proven conversion architecture. Keep the ritual free; charge for depth.
3. **Monthly recap cards — MIXED.** No evidence recaps convert; with 72% of year-1 annual subscribers cancelling ([RevenueCat 2026](https://www.revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026)), recaps are better deployed as winback assets than headline paywall features.
4. **LDR wedge — MIXED.** Agapé ("Feel Close When Apart") prices at $29.99/yr, the *low* end of the category ([App Store](https://apps.apple.com/us/app/agap%C3%A9-feel-close-when-apart/id1507907556)) — distance positioning exists but shows no measurable price premium. Wedge for positioning, not for pricing above market.
5. **Privacy-first brand — MIXED.** No category app charges a privacy premium; it supports a one-time-license trust story but forfeits ad revenue entirely. Zero quantified willingness-to-pay found.
6. **AI memory layer — MIXED.** RevenueCat 2026: AI apps earn +41% LTV ($30.16 vs $21.37) but retain 36% worse on monthly plans. Sell AI inside subscriptions; never inside a lifetime SKU (per-use cost vs. one-time revenue is structurally negative-margin).
7. **Freemium + $59 couple license + gifting — REFUTE the $59; MIXED on gifting.** Category lifetime precedents: Between $26.99 (vs $24.99/yr), Couply ~$26.99, Agapé $199.99. RevenueCat's lifetime guide: price at 2.1x–11.5x annual, often 5–12x; $59 is ~1.5x a $40 annual — below market floor, cannibalizes, and "moving a customer from lifetime to subscription later is basically impossible" ([RevenueCat](https://www.revenuecat.com/blog/growth/lifetime-subscriptions)). Gifting: Apple has allowed developer-implemented IAP gifting since the Dec 2018 guideline 3.1.1 change ([guidelines](https://developer.apple.com/app-store/review/guidelines)) — no native API; Google Play has none. Build only iOS-first.
8. **Native store apps — SUPPORT.** Trials, IAP gifting, and hard-paywall economics (10.7% D35 vs 2.1% web-less freemium) only exist through the stores. Note: Flutter shows the *lowest* revenue-per-install ($0.29 vs React Native $0.51) — expect weaker monetization than median.

## KEY EVIDENCE

- **Category prices (one sub covers both, unless noted):** Paired $14.99/mo, $39.99–$74.99/yr, 7-day trial, soft paywall after onboarding ([ourcouple.app](https://ourcouple.app/blog/ourcouple-vs-paired)); Flamme $9.99/mo, $29.99/yr; Official $11.99/mo, $39.99/yr; Couply $10.99/mo, $79.99/yr ([App Store](https://apps.apple.com/ke/app/couply-couples-relationship/id1484241314)); Lovewick $9.99/mo, $29.99/yr; Between $2.99/mo, $24.99/yr, $26.99 lifetime; Agapé $14.99/mo, $29.99/yr, $199.99 lifetime.
- **RevenueCat 2026** ([blog](https://www.revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026); 115k apps, $16B): freemium download→paid (D35) median **2.1%**; hard paywall **10.7%**; revenue/install day 60 **$3.09 vs $0.38**. Trials 17–32 days convert **42.5%**; <4-day trials **25.5%**; 80% of trials start day 1 ([2025 report](https://www.revenuecat.com/state-of-subscription-apps-2025)). **72%** of year-1 annual subscribers cancel (2026; was 56% in 2025); 35% of annual cancellations happen in month 1. Billing failures = 31% of Play cancellations; dunning recovers 15–20%.
- **Lifetime:** 39.4% of Social/Lifestyle apps already mix lifetime + subscription ([2025](https://www.revenuecat.com/state-of-subscription-apps-2025)); loyal subscribers downgrade to lifetime, capping LTV ([guide](https://www.revenuecat.com/blog/growth/lifetime-subscriptions)).
- **Gifting:** IAP gifting legal on iOS since 2018 but fully developer-built; gifts refundable only to original purchaser, non-transferable. No Play equivalent — the Android half of the gift loop must be custom redemption codes.
- **Widgetable ads:** $19.99/yr + diamonds + unskippable ads = dominant 1–2★ review theme ("pay-to-win"). Ads in this intimate category buy revenue with brand damage.

**The math at 5,000 couples (10,000 installs):** median freemium 2.1% → **~210 paying couples**. At category-median packaging (65% annual $39.99 / 35% monthly $9.99): **~$1,190 peak MRR**, decaying toward **$400–500 MRR** within a year at 72% year-1 annual churn without continuous new installs. Top-quartile execution (3x median conversion): ~$3,600 MRR. A $59 couple license converts the same cohort into a one-time **~$12,400, ever** — roughly one median subscriber-lifetime ($40/yr × 1.4-yr expected tenure ≈ $56) each, forfeiting all rebills.

## MY RECOMMENDATIONS

1. **Annual-first freemium: $49.99/yr (intro $39.99) / $12.99/mo anchor / one sub covers both**, soft paywall at end of onboarding, free daily question + widgets. This is the category median where every competitor sits; do not price outside $29.99–$79.99/yr.
2. **14-day trial, not 7.** Trials 17–32 days convert 42.5% vs 25.5% for short trials; a two-person product needs time for the second partner to activate.
3. **If keeping lifetime: $99–$149 "couple license" (2.5–4x annual), subscription-first, AI digests excluded or usage-capped.** Ship iOS gifting as a promo/gift-card flow later — it's a nice-to-have, not a pillar.

## BIGGEST RISK

**Niche-scale conversion arithmetic.** At the median 2.1% D35, even 5,000 couples yields ~$1,200 peak MRR collapsing toward ~$500 within 12 months (72% year-1 annual churn, RevenueCat 2026). A couple app that converts like the median freemium app cannot sustain a solo dev on anything but top-of-funnel volume — which makes widget virality (verdict 1) the load-bearing wall of the entire business, not an acquisition experiment. If installs stall below ~50k, no paywall design fixes the MRR.
