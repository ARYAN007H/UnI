# 💜 U&i

A private, exactly-two-people app for couples — built as the couple app that **can't betray
its users**: no ads, no AI training, one-click export, encrypted media, cancel-safe billing.

Flutter + Supabase. Android-first at launch, iOS second, web as demo/funnel.

> **Status: full rebuild in progress** (Oct 2026). The app is being revived and redesigned
> from the ground up — new design system, new information architecture, local-first data
> layer, private R2 media pipeline. The active plan lives in
> [`docs/revival-plan.md`](docs/revival-plan.md); weekly progress in [`BUILDLOG.md`](BUILDLOG.md).
> Built in public, one entry at a time.

## What it is

- **Home** — your partner's presence, their local time, today's shared question, next countdown
- **Chat** — one continuous conversation: text, photos, video, voice notes
- **Us** — the memory timeline: photos, recaps, shared stats
- **Plans** — countdowns to the next time you actually meet

Designed for long-distance couples first ("built for when you can't hug them"), because
they need it most and everyone else gets it free.

## Architecture (short version)

| Layer | Choice |
|---|---|
| App | Flutter (single codebase; native Swift/Kotlin only for widgets) |
| Backend | Supabase — Postgres + Auth + Realtime, RLS on everything |
| Media | Private Cloudflare R2, presigned direct uploads, client-side encrypted |
| Data flow | Local-first: on-device SQLite is primary, Supabase is the sync relay, offline outbox |
| Ritual | Daily question derived client-side (`hash(coupleId + date)`) — works with zero server |

Full rationale (and the evidence council that chose it): `docs/revival-plan.md`, `scratch/council/`.

## Development

```bash
flutter pub get
flutter run                 # pick your device
flutter analyze             # keep it clean, always
```

- **Flutter**: system stable (3.47.x). The old vendored `.flutter-sdk/` is deprecated and gitignored.
- **Secrets**: `.env` (SUPABASE_URL, SUPABASE_ANON_KEY) via flutter_dotenv — never committed.
- **DB**: incremental migrations in `supabase/migrations/` — never rewrite applied ones.
- **Web**: demo/funnel only (`build.sh` → Vercel). Not a target platform.

## History

Started as a Phase-1 chat app in early 2026, went dormant in May, revived Oct 2026 with a
strategy council (12 experts, 3 judges — transcripts in `scratch/council/`) that overturned
the original growth thesis and produced the Trust-Displacement direction this rebuild follows.
