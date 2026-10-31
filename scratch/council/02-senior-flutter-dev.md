# COUNCIL MEMBER #2 — Senior Mobile Engineer (Flutter)

Verified locally: `ios/Runner` and `android/app` are stock Flutter templates — no widget extension, no native targets exist; every native feature starts from zero.

## VERDICTS

1. **Widget-first acquisition — MIXED.** `home_widget` 0.10.0 (Sep 2026, 2.2k likes, active) only moves data; every widget is 100% native SwiftUI WidgetKit + Kotlin Glance code, iOS caps background refreshes at ~40–70/day (photo/mood are snapshots, not live), and interactive widgets need Swift App Intents (iOS 17+). Real effort: 3–5 dev-weeks solo for photo+countdown+mood across both platforms — a native-mobile project, not a Flutter task.
2. **Daily-question ritual — SUPPORT.** Existing channels + Supabase cron Edge Function + push covers it; 0.5–1 dev-week. Cheapest retention loop on the list.
3. **Wrapped recap cards — SUPPORT.** RepaintBoundary→image + share sheet is well-trodden Flutter; 1 dev-week. Only shareable item that needs zero native code.
4. **LDR wedge — MIXED.** Timezone widget = same native cost as #1. "Synced lofi room" is a genuinely hard problem: free-running device audio clocks drift, requiring NTP-style offset estimation, clock-master election, and rate adjustment (Lund thesis, Roon clock-drift threads) — 4+ dev-weeks for a mediocre result. Cut or ship async playlist.
5. **Privacy-first, self-hostable Supabase — MIXED.** Self-hosting realtime+storage is real ops burden for a 2-user app, and push still routes through FCM/APNs (Apple/Google in the trust chain regardless). Fine as brand; engineering-wise pointless at n=2.
6. **AI memory layer — SUPPORT (conditional).** Supabase has pgvector + Edge Functions; 2–3 dev-weeks. But sending private couple memories to an embeddings API contradicts the brand — needs local/self-hosted embeddings or it's a positioning landmine.
7. **Freemium + one-time license — SUPPORT (engineering-wise).** Standard `in_app_purchase`/RevenueCat work, 1–2 dev-weeks; also necessary — Supabase free tier pauses after 7 days of inactivity, and a 2-user hobby project *will* hit that without Pro ($25/mo) or a keep-alive cron.
8. **Native store apps as prerequisite — SUPPORT, emphatically.** Currently web-only: no push in Safari tabs (iOS web push works only for added-to-home-screen PWAs, iOS 16.4+, gesture-gated permission prompts, no sound), no widgets, no IAP. Play requires target API 36 by Aug 31 2026; repo sits on vendored Flutter 3.41.9 (Apr 2026) vs current stable 3.47.8 (Oct 2026). 2–3 dev-weeks of upgrade/compliance before any feature work.

## KEY EVIDENCE

- Repo (verified locally): last commit 2026-05-12, 13,155 LOC / 37 Dart files, no widget/watch/notification extension targets — `ios/Runner` + `android/app` are stock templates; scratch files `fix_cache.py`, `fix_home_screen.py` signal fragile prior patching.
- https://pub.dev/packages/home_widget — v0.10.0, published ~Sep 2026, 160 points; widgets written natively, plugin = data plumbing only.
- https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date — ~40–70 reloads/day, ≥5-min timeline entries; https://developer.apple.com/videos/play/wwdc2025/278 — budgets still enforced in 2025/26, push-based reloads recommended (extra server work).
- https://medium.com/@ABausG/interactive-homescreen-widgets-with-flutter-using-home-widget-83cb0706a417 — interactive = native AppIntent (iOS) / BroadcastReceiver (Android); https://github.com/ABausG/home_widget/issues/326 shows common setup failures.
- https://stackoverflow.com/questions/73758507/is-it-possible-to-create-ios-16-lock-screen-widgets-with-flutter — no Flutter API for lock-screen accessory widgets (also render in StandBy); watchOS requires a fully native companion target.
- https://supabase.com/docs/guides/troubleshooting/realtime-handling-silent-disconnections-in-backgrounded-applications-592794 — OS kills realtime websockets in background; must resubscribe/re-track presence on resume.
- https://supabase.com/docs/guides/functions/examples/push-notifications + https://github.com/orgs/supabase/discussions/13930 — push = notifications table → webhook → Edge Function → FCM HTTP v1/APNs; not built into realtime. 1–2 dev-weeks new infra.
- https://github.com/orgs/supabase/discussions/37922 — free-tier 7-day inactivity pause; Pro removes it.
- Web: skwasm ~2x frame times vs CanvasKit ([Medium writeup](https://medium.com/@flutter-app/is-flutter-web-finally-production-ready-i-flipped-the-wasm-switch-to-find-out-a56d2031f199)); Safari MediaRecorder codec failures for voice notes; WebKit ITP deletes Safari-tab IndexedDB/localStorage after 7 days of non-use ([Dexie issue #739](https://github.com/dexie/Dexie.js/issues/739)) — the sqflite web cache of non-installed Safari users gets wiped; only home-screen-installed PWAs are exempt.
- https://pub.dev/packages/flutter_earth_globe — 87 likes, 3.5k weekly downloads, single maintainer, last publish ~Mar 2026, requires `--wasm` on web; fragment-shader globe = GPU/battery cost on low-end Android while visible.
- https://www.progamespoint.com/blog/google-play-target-api-level-2026 — Play target API 36 mandatory Aug 31 2026; https://docs.flutter.dev/install/archive — current stable 3.47.8 vs project's 3.41.9.

## MY RECOMMENDATIONS (engineering domain)

1. **Do #8 first, scoped: 3–4 dev-weeks.** Flutter SDK upgrade (3.41.9→3.47.x, unvendor it), dep bumps, Play API-36 compliance, iOS archive pipeline, then ONE shipped store build before any new feature. Everything else is blocked behind it.
2. **Ship the ritual + cards (2 dev-weeks) before widgets.** Retention features #2/#3 are pure Dart on existing infra; widget effort (3–5 weeks, two languages you've never shipped in) should follow a proven-activated user base, not precede it.
3. **Drop the synced lofi room; keep web as install-only PWA.** Audio-sync alone exceeds the widget budget; and maintaining Safari-tab web is a data-loss liability (ITP wipes) plus a voice-recording broken surface — gate web to "Add to Home Screen" or funnel-only.

## BIGGEST RISK

**The native-platform cliff under a solo, web-era Flutter codebase frozen 5.5 months.** Every acquisition/retention pillar (#1 widgets, push, #8 stores) lives in Swift/Kotlin/developer-console territory the repo has never touched (verified: zero native targets), on an SDK two stable releases behind and vendored into git. The widget budget (40–70 reloads/day), Play's Aug-2026 API-36 gate, and Supabase's 7-day free-tier pause are hard external constraints converging on one maintainer — the strategy's sequencing (widgets before store presence, before push) inverts the actual dependency order and is the most likely failure point.
