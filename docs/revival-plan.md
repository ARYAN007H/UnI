# U&i Revival Plan — v3 FINAL

> The one plan: rebuild the app properly at $0 during the build year, beta with real couples
> via APK/web, launch on stores the week we turn 18. Written 2026-10-30. Supersedes `vision-v2.md`.
> Strategy basis: the Oct 2026 evidence council (`scratch/council/`) — the Trust-Displacement Play.
> v3 FINAL adds the five architecture upgrades (§7), baked into the phase order (§8).

---

## 1. The thesis in one paragraph

U&i is a private, exactly-two-people app for couples — rebuilt as **the couple app that
can't betray its users**: no ads, no AI training, one-click export, encrypted media,
cancel-safe billing. Launched into the long-distance wedge ("built for when you can't hug
them"), discovered via long-tail ASO + build-in-public, monetized at category median
($49.99/yr, one sub covers both, 14-day trial). The category's only reliable product is
incumbents' trust failure (Official shut May 2025, Between deleted albums Sept 2025,
Couple/Pair 2019). We are the durable alternative. Realistic ceiling: a clean, maintained
1–5K-couple asset — with an honest kill line at day 90 post-launch.

## 2. Constraints (non-negotiable)

- **Age 17, no bank account** → no store registration, no payments until 18. Nothing in
  this plan requires money. Costs arrive only at 18 ($25 Play, $99 Apple, $25/mo Supabase Pro).
- **Solo dev, limited hours** → 1 dev-week (dw) ≈ 30–35 focused hours; ship in small
  increments; every phase must leave the app *runnable*.
- **Supabase free tier** — fine while developing daily; the 7-day inactivity pause only
  bites dormant projects. Weekly heartbeat commit even when idle.
- **Compliance is not optional at beta** — 18+ gate, report/block, account deletion, export.
  The moment one real couple uses the beta, these exist.

## 3. What we keep vs. rebuild (the chassis swap)

**KEEP (the engine — verified solid):**
- `services/` domain logic — auth flows, chat queries, presence, local cache, backup, notifications
- `models/models.dart` — Profile, Couple, Channel, Message, Plan (schema-aligned)
- `supabase/migrations/` — 7 migrations incl. RLS (add incremental ones, never rewrite)
- Per-couple accent color (`couples.theme_color_hex`) — survives, re-expressed in the new system

**REBUILD (the body — learner UI, admits it):**
- `config/theme.dart` (OLED-black + coral gradients + per-channel palettes + liquid glass
  everywhere → §4 design system) · all `screens/` → feature-first structure · all `widgets/`
  → new component kit · IA (Discord channels → 4-tab home, §5) · onboarding (7-gate funnel
  → 3 steps, §6)

**CUT (council-verified):** streaks, synced lofi room, self-hosting/Oracle, branded AI layer,
gifting ledger, custom channels, EXIF globe from launch (returns post-launch as the shareable
"wow" feature — verified white space, just not launch-critical).

## 4. Design system — "Warm Editorial"

A well-set book, not a gamer's dark mode: calm, warm, typography-led, photos as the payload.

| Token | Decision | Why |
|---|---|---|
| Default theme | **Light warm ("paper")**: cream base `#FAF6F1`, ink text `#1A1613` | Paired/Between/Lovewick all skew light-warm; couples use this in daylight and in bed |
| Dark theme | True dark, warm-tinted (`#171412` base), same token structure | Candlelight, not gaming rig |
| Accent | One warm accent per couple (seed terracotta `#C4573B`), mapped from `theme_color_hex` | Personalization survives; accent on text/buttons only — never behind glass (NN/g legibility warning) |
| Type | Display: **Fraunces** (warm serif — headers, names, dates). Body/UI: **Inter** | Editorial intimacy, instantly un-Discord |
| Shape | One radius scale (4/8/12/16/24/full) | Cohesion over decoration |
| Elevation | Shadows ≤ 2 levels; hairline borders over glows | Flat-calm |
| Motion | flutter_animate, 200–300ms, `easeOutCubic`, one entrance pattern per element type | Kill the shimmer spam |
| Icons | Material Symbols Rounded, one stroke weight | Free consistency |
| Media | Photos full-bleed; chrome recedes around images | Photos ARE the product |

**Component kit (build once, reuse):** `AppText` · `AppButton` (primary/secondary/ghost/destructive)
· `AppCard` · `AppTextField` · type-led `AppBar` · 4-tab `BottomNav` · `Bubble` (text/media/voice)
· `EmptyState` · `Avatar`+presence dot · `Countdown` chip · `SectionHeader` · `Sheet` · `Toast`
· `Skeleton` (one loader pattern) · `BlurHashedImage` (see §7.2).

**Hard rules:** (1) No gradient on any interactive element — gradients only on the splash.
(2) No blur/glass behind text. Ever. (3) Every screen passes the 11pm test — it must look
calm when couples actually use it. (4) WCAG AA contrast on every text/accent pair.
(5) One empty-state, one loading, one error pattern across the entire app.

## 5. Information architecture — from Discord to a home

Old: channel sidebar (general/photos/plans/random) — a work-tool mental model for a love letter.
New: **4 tabs**, each answering one question:

| Tab | Question | Contents |
|---|---|---|
| **Home** | "Where are we, right now?" | Partner presence card (avatar, their local time — "their morning ☀ / your night 🌙"), today's daily question state, next countdown, unread pulse |
| **Chat** | "What did we say?" | One continuous conversation; media strip on top; voice notes, reactions, replies |
| **Us** | "What have we been?" | Photo/memory timeline (month-grouped, BlurHash placeholders), recap cards, shared stats (days together, photos, voice minutes) — future home of the globe |
| **Plans** | "When do we meet next?" | Countdown hero, plan cards (date/location/status), past plans archive |

Daily question lives on Home, answered in a sheet, **revealed only when both partners have
answered** (Agapé mechanic — the only couple-app design with a dose-response signal in the
research). No streak counter — a soft "answered N together" only.

## 6. Onboarding — 3 steps (target ≥25% pair activation)

Old: 7 gates, ~1–3% survive (signup → email verify → create couple → share code → partner
signup+verify → polling wait → permissions wall).

1. **Sign in with Google** (email-link fallback). No verification wall.
2. **Solo value immediately**: name yourself, answer today's question *right now* — "your
   answer unlocks when they join" (it waits for them). Write a first memory note.
3. **Pair in one tap**: deep-link/magic link via the share sheet — no code typing. The
   waiting screen shows the populated app with the pending answer, not a spinner.

Permissions are just-in-time: notifications after pairing (warm-up sheet first), media on
first photo send. 18+ gate at first launch, plain-language why.

## 7. Architecture — the five upgrades (baked into the phases)

Each upgrade: current state (verified in code) → target state → why it wins.

### 7.1 Local-first data flow — the device DB is primary, Supabase is the relay
**Today:** cache is optional (`main.dart` degrades to `null`); reads hit network; optimistic
UI exists only as the `isPending` flag; offline = dead app.
**Target:** on-device SQLite is what the UI always renders from. Writes go: local DB first
→ outbox queue → sync to Supabase when online → Realtime confirms/repairs. Reconnect =
drain outbox + catch-up query. Export becomes nearly free: the user's data already lives
on their phone (§8 Phase 3 wires export to it).
**Why:** instant UI everywhere; genuinely works offline (LDR couples: flights, hostel wifi,
data limits); the privacy brand gets literal — "your words live on your device."
**Effort:** ~1.5 dw. **Phase 2** (chat rebuild is the right moment).

### 7.2 Media pipeline — private R2, presigned direct uploads, client-side prep
**Today:** `MediaService.uploadFile()` reads the *whole file into memory* and uploads
through Supabase Storage, then mints a **public URL** for intimate media — the exact
failure mode the brand claims to be the alternative to. Big videos = OOM on mid-range
Androids. Every view = paid Supabase egress.
**Target:** Edge Function mints a presigned PUT URL → phone uploads **directly to a private
R2 bucket** → metadata row written after. Reads via short-lived signed URLs + local cache.
Client-side before upload: strip/compute EXIF (dep already present), generate thumbnail +
**BlurHash** so the partner's UI renders instant placeholders, never spinners.
**Why:** privacy (private bucket, signed access only), cost (zero egress), stability
(resumable multipart, no RAM spikes), perceived speed (BlurHash).
**Effort:** ~1.5 dw. **Phase 3**.

### 7.3 One Realtime channel per couple + event fan-out
**Today:** three websocket channels (`messages:$channelId`, `typing:$coupleId`,
`presence:$coupleId`) — three reconnect surfaces after every background-kill.
**Target:** one channel per couple; typing/presence ride `broadcast` topics on it; DB
changes as a single filtered `postgres_changes` stream. Backend-side: one **event fan-out**
pipeline (Postgres trigger or Edge Function on "message sent / reaction / plan created")
that fans out to push notifications now and **widget reloads later**.
**Why:** one-third the reconnect surface, less battery, and the fan-out pipe is what makes
the Phase 5 widget strategy cheap — build it once, launch feature pre-paid.
**Effort:** ~1 dw (fold fan-out into the push work). **Phase 1** (channel) + **Phase 3** (fan-out + push).

### 7.4 Derivable daily question — the ritual is math, not infrastructure
**Today:** nothing (ritual doesn't exist yet).
**Target:** `questionOfDay = questions[hash(coupleId + UTC date) % questions.length]`,
computed **on the client**. No cron, no Edge Function, no delivery to fail. Both partners'
clients independently land on the same question; the server only stores answers.
**Why:** the core ritual can never "fail to deliver," works offline, zero backend cost —
and it fits the brand (the app works even when the server barely does).
**Effort:** ~0 dw (replaces the scheduler work). **Phase 2**.

### 7.5 Per-couple media encryption — the provable trust artifact
**Today:** plaintext blobs at a public URL.
**Target:** asymmetric E2E — text stays plaintext (RLS-protected, searchable, recap-able);
**photos/videos encrypted client-side with a per-couple key derived during pairing**
(`cryptography`/libsodium sealed boxes). Encrypted blob → R2. Even a bucket leak is noise.
Key escrow: the couple key is itself encrypted under the account password, documented in
Settings — the recovery story is honest, not hidden.
**Why:** "even we can't read your photos" is a trust claim no incumbent can copy without
breaking their own search/AI features. This is the Trust-Displacement Play made literal.
**Effort:** ~1 dw. **Phase 3** (after 7.2 — same code paths).

**Rejected alternatives** (so past-me doesn't relitigate): full Signal-protocol E2EE
(breaks search/recaps; solo-dev crypto risk), PowerSync/ElectricSQL sync engines (real
tech, wrong scale — design the seam instead), event-sourced schema (overkill for solo),
React Native/KMP/native-only (burns 13k working LOC for zero user gain).

## 8. The build phases

~15 dw total to launch-grade (12 base + ~3 for the upgrades). At student hours ≈ 1 dw per
2 calendar weeks → **Phases 0–4 ≈ 7 calendar months**, then the launch quarter at 18.
Every phase ends runnable.

### Phase 0 — Hygiene & foundation (week 1–2)
- [ ] Fix 2 analyzer warnings (`backup_service.dart:228,233`); delete `fix_*.py` + `scratch/` cruft
- [ ] Unvendor `.flutter-sdk` (gitignore; system flutter/FVM); upgrade Flutter 3.41.9 → 3.47.x; bump deps; Play API-36 compliance
- [ ] Truthful `README.md`; start `BUILDLOG.md` — one honest entry per week, public
- [ ] `docs/design/`: token sheet + 3 static reference screens (Home, Chat, Us)
- [ ] **Decision: name.** Recommendation: keep **U&i** — universal, clean. Decide before Phase 1 tokens.

### Phase 1 — Design system + skeleton + realtime refactor (weeks 3–6)
- [ ] `lib/core/`: `theme/` (tokens, light+dark, couple-accent mapping), `router/`, component kit (§4)
- [ ] Feature-first structure: `lib/features/{home,chat,us,plans,auth,pairing,settings}/`
- [ ] Shell app: 4-tab nav, empty/loading/error patterns, new icon + splash
- [ ] Auth rebuild: Google OAuth + email-link fallback; delete the 24h-grace verification flow
- [ ] **§7.3**: collapse to one Realtime channel per couple (broadcast typing/presence)
- [ ] Keep ChangeNotifier services; thin viewmodels per screen. No new state frameworks.

### Phase 2 — Core experience + local-first (weeks 7–11)
- [ ] Chat rebuild on the new kit: Bubble (text/media/voice), reply, reactions, media viewer, presence
- [ ] **§7.1**: mandatory local DB, write-through inserts, outbox queue, reconnect drain + catch-up
- [ ] **§7.4**: derivable daily question + both-answer reveal; seed 365 prompts in one batch (LDR, playful, deep, memory)
- [ ] Us tab: month-grouped photo timeline with BlurHash placeholders, days-together counter
- [ ] Plans tab: countdown hero + plan cards (existing Plan model)

### Phase 3 — Media, trust & compliance (weeks 12–15)
- [ ] **§7.2**: presigned direct-to-R2 uploads, private bucket, signed reads, thumbnails + BlurHash client-side
- [ ] **§7.5**: per-couple media encryption + key escrow under account password
- [ ] **§7.3 completion**: event fan-out → FCM push (the ritual's delivery channel)
- [ ] Recap card: RepaintBoundary → image → share sheet (monthly; works pre-widgets)
- [ ] Compliance shell: 18+ gate, report/block, in-app account deletion, **one-click full export** (JSON + media) — wired to the local-first DB
- [ ] Web stays demo/funnel only (guided add-to-home-screen)

### Phase 4 — Closed beta (weeks 16–19)
- [ ] APKs via **GitHub Releases** + Vercel web — real couples install without a store
- [ ] Recruit 10–20 real LDR couples: r/LongDistance, LDR Discords, college networks, the build log
- [ ] Instrument: pair activation %, D7 retention, daily-question answer rate — funnel targets
- [ ] Fix what beta breaks; polish pass on every screen
- [ ] Widget v1 on a branch (Android Glance: countdown + partner photo, 1 reload/day, fed by §7.3 fan-out)

### Phase 5 — At 18: the launch quarter
1. Bank account week 1 → Play Console ($25) + Apple ($99) in parallel
2. Closed test: the beta couples **are** the 12 required testers (recruited in Phase 4)
3. Play production + App Store review (compliance shell already built in Phase 3)
4. Launch playbook: long-tail ASO ("long distance app for couples", "couple countdown widget"),
   the build-log story ("I built this at 17"), LDR Reddit/TikTok presence
5. Monetization: $49.99/yr (intro $39.99) / $12.99/mo anchor, 14-day trial, one sub covers both
6. **Kill line (pre-committed):** <5,000 installs and <$500 MRR at day 90 → 60-day notice,
   export for every user, open-source, close honestly. An honest death is the brand's final proof.

## 9. Definition of done (build year)

- A stranger goes link → paired couple → photos/voice/daily question exchanged in under 10 minutes
- 10–20 real couples active in beta, D7 ≥ 30%
- Airplane-mode test: open the app with no network — chat history, daily question, and *sending* all work (outbox drains on reconnect)
- Privacy test: public URL for any media file → 403; R2 bucket leak → encrypted noise
- Every screen passes the 11pm test; design system documented in `docs/design/`
- ≥ 20 honest BUILDLOG entries. Zero dollars spent.

## 10. Weekly rhythm (the anti-dormancy system)

- **1 heartbeat minimum**: any commit + one BUILDLOG.md line, every week — even "no progress."
  Dormancy is the category's #1 documented killer; the log is discipline and marketing at once.
- Ship something visible every 2 weeks (a screen, a flow) — feed motivation with output, not vibes.
- When the repo hurts to open (see personal context), do a design task instead of the Chat tab.
  The work still moves; the trigger doesn't.

---

*Sources: council transcripts `scratch/council/` (12 experts + 3 judges); code audit of
`lib/services/` (2026-10-30); RevenueCat SoSA 2025/26; JMIR Aicken et al. 2025; Rogge et al.
2023 (Agapé); Apple/Google store policy docs.*
