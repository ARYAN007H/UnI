# BUILDLOG — U&i rebuild in public

One honest entry per week. Even "no progress this week" counts — that's the rule.
Dormancy is the category's #1 documented killer; this log is the antidote.

---

## Week 1 — 2026-10-30 · *the revival begins*

- Strategy council ran (12 expert agents + 3 judges, real evidence): original widget-viral
  thesis overturned → Trust-Displacement Play. Full transcripts in `scratch/council/`.
- Final plan written: `docs/revival-plan.md` (v3 FINAL) — Warm Editorial redesign, 4-tab IA,
  local-first outbox, private R2 media, per-couple media encryption, derivable daily question.
- Rebuild running as 3 parallel agents on a coordination board (`agentchat.md`):
  - **Agent 1 (foundation):** Flutter 3.29.3 → 3.47.9, 100+ deps, API-36 confirmed, truthful
    README, Warm Editorial token system in `lib/core/theme/`, router, CI, test suite,
    Inter+Fraunces fonts bundled (offline-first typography), JDK 17 pinned for Gradle,
    beta-release + CI workflows, orchestration of the other two lanes.
  - **Agent 2 (data/backend):** realtime collapsed to one channel per couple; local-first
    outbox (offline send, self-heal); derivable daily question + migrations; private-R2
    presigned media pipeline with EXIF-strip + BlurHash; **per-couple media encryption**
    (X25519+HKDF couple key, AES-256-GCM blobs, one-time recovery-code escrow); export
    service; deep-link pair parser. Service tests green.
  - **Agent 3 (UI):** 10 screen specs, new app icon generated, Warm Editorial component kit
    and screens under construction.
- 45/45 tests passing, `flutter analyze` clean.

- Agent 3 completed screens + main.dart wiring; Agent 2 shipped compliance backend
  (account deletion, report/block) — 50/50 tests green.
- Legacy UI (`lib/screens/`, `lib/widgets/`, old theme) deleted — zero importers.
- **First live two-device test: PASSED.** Phone + browser paired via invite code,
  encryption armed with recovery escrow, presence live, chat messages flowing
  both directions, verified in Supabase.
- Debugging marathon (all fixed): missing lat/long/media columns in messages
  (migration 013), missing `batch_mark_read` RPC, channels never seeded for new
  couples (migration 012 + DB trigger), realtime publication missing daily/key
  tables, a poisoned half-initialized cache blocking the whole init chain, and
  the chat never triggering its history fetch.

**Next:** clean up outbox retry-duplicates, web sqflite worker, orphan couples.
Store launch happens the week we turn 18.

**HUMAN checklist before beta:** run migrations `008`, `009`, `010` in the Supabase SQL editor.
