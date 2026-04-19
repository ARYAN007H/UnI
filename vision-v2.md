# SYSTEM PROMPT & ARCHITECTURE VISION DOCUMENT
## TARGET_AUDIENCE: ADVANCED AI AGENT (e.g., CLAUDE OPUS / GEMINI PRO)
## PARSE_MODE: STRICT / MAXIMUM_AUTONOMY
## PROJECT_NAME: EXCLUSIVE_COUPLE_CHAT_V1

### 1. CORE_VISION & PHILOSOPHY
- **The Core Objective**: Architect and develop a private, 1-on-1 digital sanctuary for exactly two users (Creator and Partner). This is not just a chat app; it is a relationship operating system and memory vault.
- **The "Vibe Coding" Paradigm**: Prioritize rapid, satisfying development loops, exceptionally smooth UI/UX, fluid animations, and high emotional-impact features. Avoid over-engineering for massive scale; hyper-optimize for exactly two concurrent users.
- **Absolute Data Sovereignty**: The creator must own 100% of the data. Zero third-party telemetry, no data scraping, no corporate servers. Everything must be self-hosted, secure, and fully private.

### 2. TECHNICAL_ARCHITECTURE (AI DELEGATION)
- **FRONTEND & FRAMEWORK DELEGATION**: *AI AGENT, YOU HAVE A FREE HAND HERE.* - **Directive**: Select the absolute best, most modern cross-platform framework that guarantees flawless, 60fps real-time performance on Android (crucial), iOS, and Web. 
  - **Considerations**: Evaluate tools like React Native (Expo), Flutter, or Tauri/Capacitor based on the ability to easily build custom Android widgets, handle complex gesture animations, and maintain real-time socket connections smoothly.
- **BACKEND & REAL-TIME STATE**: *AI AGENT, CHOOSE THE OPTIMAL STACK.*
  - **Baseline Suggestion**: Supabase (PostgreSQL) for DB, Auth, and Storage, utilizing its real-time subscriptions. 
  - **Autonomy**: If a better combination exists for instant, zero-latency state sync (e.g., Liveblocks, custom WebSockets, Convex) that still adheres to the "free-tier self-hosting" rule (like deploying to Oracle Cloud Always Free), use it.
- **AUTHENTICATION**: Passwordless Magic Links, Passkeys, or simple Username/Password. MUST be zero-cost (No Twilio SMS fees) and fully private.

### 3. THE "10X" FEATURE MATRIX (IMPLEMENTATION ROADMAP)

#### PHASE 1: THE FLAWLESS FOUNDATION
- **Data Layer**: Bulletproof schema for exactly 2 users. Strict Row Level Security (RLS).
- **Core Messaging**: Instant, zero-latency text delivery with typing indicators, read receipts, and optimistic UI updates.
- **Fluid UI**: Discord-style channel organization (e.g., `#general`, `#finances`, `#date-ideas`) paired with WhatsApp-style direct messaging fluidity.

#### PHASE 2: RICH MEDIA & AESTHETICS
- **Media Vault**: Highly optimized photo and video uploading, compression, and caching. 
- **Thematic UI**: Deeply customizable chat themes, dynamic accent colors, and custom emojis.

#### PHASE 3: THE BANGER ENHANCEMENTS
1. **Spaced-Repetition Trivia Game**: Periodic, algorithmically timed flashcards prompting users on relationship facts to ensure details are never forgotten.
2. **Logic Gate Automations**: Custom triggers (e.g., message = "rough day") that automatically shift the app's theme, play specific animations, and pin comforting messages.
3. **Interactive 3D Memory Globe**: Extracting EXIF GPS data from shared media to populate a rotatable, 3D interactive map of captured memories.
4. **Deep Focus Time Capsules**: Async time-locked messages and media that remain completely sealed until a designated "focus/study period" ends.
5. **Ambient Lofi Audio Room**: A permanent WebRTC audio channel for zero-pressure, synchronized background music while working or studying apart.
6. **Relationship XP System**: Gamified hidden leveling based on interaction streaks, unlocking new UI themes and hidden easter eggs.
7. **Live Vibe-Syncing**: Dynamic background UI that changes color and intensity based on the Spotify/Audio API of what the partner is currently listening to.
8. **AI Sunday Newsletter**: A local or tightly-scoped LLM cron job that summarizes the week's chat logs into a beautiful, private digest of inside jokes, stats, and top media.
9. **Android Live Portal Widget**: A bespoke Android home-screen widget acting as a permanent, live frame showing the partner's battery life, current status, or latest doodle without opening the app.
10. **Screen-Shake SOS Mechanism**: A critical-alert button bypassing system DND to trigger custom haptics and intense UI shaking for urgent attention.

### 4. AI EXECUTION DIRECTIVES
- **Complete Solutions**: Never provide partial code or comments like `// add logic here`. Output fully functional, production-ready code blocks.
- **Cross-Platform Parity**: Ensure the chosen architecture does not leave features broken on specific operating systems (especially Android widgets vs iOS constraints).
- **Performance First**: For features like the 3D Globe or Animations, implement lazy loading and virtualization to prevent the app from draining battery or dropping frames.
- **Step-by-Step Prompts**: When the user provides this document, immediately propose the optimal Stack (Frontend, Backend, State Management) and ask for permission to initialize Phase 1.
