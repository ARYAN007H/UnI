# COUNCIL MEMBER #3 — Backend/Infra Engineer

## VERDICTS — strategies 1–8

1. **Widget-first — MIXED.** Push is cheap (FCM $0 at any volume; Apple $99/yr) but iOS home-screen widgets are native-only; a web-only PWA cannot ship one. Vercel Hobby allows 2 cron jobs, each firing once per day, triggered "within the hour" — too coarse for widget background refresh. Widget-first requires native apps (point 8) first.
2. **Daily-question ritual — SUPPORT.** One daily cron fits Vercel Hobby's 2×once-daily crons, or pg_cron/Edge Functions scheduled invocations (500k free/2M Pro, then $2/M). Near-zero cost. Caveat: Supabase free projects pause after 1 week of inactivity — a dormant instance kills the ritual and push silently.
3. **Wrapped recap cards — SUPPORT.** SQL aggregation over text is trivial on the 8GB Pro disk. Only cost is media egress when cards embed images/video (see risk below). At couple scale, <$5/mo.
4. **LDR wedge — MIXED.** Timezone widget: cheap. Synced audio room: needs SFU/TURN. LiveKit Cloud Build is free (5,000 participant-min + 50GB), but 1,000 couples × 1h/day = 1.8M min → Ship plan $50/mo + ~1.65M × $0.0005 = $825/mo. Self-hosted LiveKit + coturn on a ~$5–20/mo VPS (Cloudflare free TURN: 1TB/mo, then $0.05/GB) is the sane route at this scale.
5. **Oracle Always Free self-host — REFUTE.** Documented idle reclamation (<20% CPU over 7 days), silent quota cuts (4 OCPU/24GB → 2/12GB), and full account terminations with data purge even on active accounts (HN Feb 2025; Oracle Community May 2025). "Free forever" means free until deleted; mandatory off-platform backups make it not-free in ops time. Ship self-hostable code; don't promise Oracle as the host. If self-hosting: Hetzner CAX11 (2 vCPU ARM, 4GB, 20TB traffic) at ~€4.49/mo post-April-2025.
6. **AI memory layer — SUPPORT.** Gemini 2.5 Flash-Lite at $0.10/$0.40 per 1M tokens ($0.05/$0.20 batch): ~1M tokens/couple/month ≈ $0.15. 10,000 couples ≈ $1,500/mo gross, less with batch. Opt-in keeps early cost ≈ $0. Genuinely viable.
7. **Freemium + one-time license — REFUTE (infra economics).** Recurring costs (egress $0.09/GB, storage $0.0213/GB, backups) recur forever while a couple's media archive grows unboundedly. A media-heavy couple costs ~$1–10/mo to host; a $20–40 one-time license turns negative-margin within a year. One-time pricing only works with hard storage caps/purge policies.
8. **Native store apps — SUPPORT.** FCM is free at any volume (no per-message charge); sole fixed cost is Apple Developer $99/yr + annual APNs key renewal. Unlocks reliable push, widgets, and removes iOS PWA web-push fragility (requires iOS 16.4+, Add-to-Home-Screen, standalone manifest; delivery issues tracked in ongoing WebKit bug reports).

## KEY EVIDENCE

- Supabase pricing (fetched 2026-10-29, supabase.com/pricing): Free — 500MB DB, 1GB storage, 5GB egress, 200 realtime connections, 2M realtime msgs, **50MB max upload**, 2 projects, **pause after 1 week inactivity**. Pro $25 — $10 compute credit (Micro), 8GB DB then $0.125/GB, 100GB storage then $0.0213/GB, **250GB egress then $0.09/GB** (cached $0.03), 100k MAU then $0.00325, compute Micro $10/Small $15/Medium $60.
- Realtime limits (supabase.com/docs/guides/realtime/limits): 200/500/10,000 concurrent connections (Free/Pro/no-spend-cap); 100/500/2,500 msgs/s; 20 presence msgs/s on Free.
- Oracle reclamation rules + reports: stackoverflow.com/questions/71209485; HN 42901897 ("Oracle Cloud deleting active user accounts without warning"); community.oracle.com discussion 875400 (May 2025 termination, data purged).
- iOS web push: webkit.org/blog/13878 — home-screen standalone only; iOS 16.4+.
- LiveKit pricing (livekit.com/pricing): Build free 5,000 min/50GB; Ship $50/mo, 150k min then $0.0005/min, 250GB then $0.12/GB.
- LLM rates: Gemini 2.5 Flash-Lite $0.10/$0.40 per 1M tokens.
- Egress horror: r/vibecoding "Insane Egress overages in Supabase while testing solo" — solo tester, database-driven overages; r/Supabase threads on egress and billing disputes.

**Modeled monthly cost, media-heavy (10GB egress + 5GB storage per couple):** 100 couples ≈ **$100** ($25 + $68 egress + $9 storage); 1,000 couples ≈ **$1,050**; 10,000 couples ≈ **$10,200** ($9,000 of it egress). Media-light usage collapses 100 couples to $25.

## MY RECOMMENDATIONS

1. **Move media to Cloudflare R2 immediately** (zero egress fees, ~$0.015/GB storage). This single change cuts the 10,000-couple bill from ~$10,200 to ~$1,600/mo. Keep Supabase for DB/auth/realtime.
2. **Stay on managed Supabase Pro ($25, spend cap ON) until ~1,000 couples.** Skip Oracle self-hosting; if self-host ever needed, Hetzner CAX11 ~€4.49/mo — never for primary data without off-site backups.
3. **Do native apps before widget-first** ($99/yr Apple + free FCM); drop the one-time license in favor of a cheap recurring plan or storage-capped lifetime tier, or hosting costs outrun revenue by year one.

## BIGGEST RISK

**Supabase Storage egress at $0.09/GB bills the product's core emotional loop.** Re-watching shared videos is what a couple app is for, and every replay is paid egress: one 30MB video re-watched twice weekly by 1,000 couples ≈ $2,160/mo — with zero corresponding revenue on a freemium/one-time model. The r/vibecoding solo-dev overage shows this bites even at testing scale. Egress-optimized storage (R2) is existential, not optional.
