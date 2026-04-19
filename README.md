# 💜 Couple Chat

A private, 1-on-1 digital sanctuary for exactly two users — your relationship operating system and memory vault.

Built with **Flutter** + **Supabase** for Android, iOS, and Web.

---

## ✨ Features (Phase 1)

- **🔐 Auth & Pairing** — Email/password signup with invite-code couple pairing
- **📢 Discord-style Channels** — Organize chats into `#general`, `#photos`, `#plans`, `#random` (customizable)
- **⚡ Real-time Messaging** — Instant delivery via Supabase Realtime with optimistic UI
- **✍️ Typing Indicators** — Animated dots when your partner is typing (Supabase Broadcast)
- **✅ Read Receipts** — Single ✓ (sent) → Double ✓✓ (read)
- **🟢 Presence** — Live online/offline status with "last seen" timestamps
- **🎨 Premium Dark UI** — Glassmorphism, gradient buttons, smooth animations via `flutter_animate`
- **🗑️ Message Actions** — Reply, copy, edit, delete with haptic feedback
- **📜 Infinite Scroll** — Paginated message history (50 per page)
- **🔒 Row Level Security** — Bulletproof Supabase RLS policies for complete data privacy

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| **Frontend** | Flutter 3.29+ (Dart 3.7+) |
| **Backend** | Supabase (PostgreSQL, Auth, Realtime, Storage) |
| **Styling** | Material 3 with custom dark theme, Google Fonts (Inter) |
| **Animations** | `flutter_animate` |
| **State** | `ChangeNotifier` + `ListenableBuilder` |
| **Platforms** | Android, iOS, Web |

---

## 🚀 Quick Start

### Prerequisites
- Flutter SDK 3.29+ ([install](https://docs.flutter.dev/get-started/install))
- A [Supabase](https://supabase.com) project (free tier works)

### 1. Clone & Install

```bash
cd couple_chat
flutter pub get
```

### 2. Set Up Supabase

1. Create a new project at [supabase.com](https://supabase.com)
2. Go to **SQL Editor** and run the migration:
   ```
   supabase/migrations/001_initial_schema.sql
   ```
3. Go to **Settings → API** and copy your **Project URL** and **anon key**

### 3. Configure

Edit `lib/config/supabase_config.dart`:

```dart
class SupabaseConfig {
  static const String url = 'https://YOUR_PROJECT.supabase.co';
  static const String anonKey = 'YOUR_ANON_KEY';
}
```

### 4. Enable Realtime

In Supabase Dashboard:
1. Go to **Database → Replication**
2. Enable replication for the `messages` table
3. Go to **Database → Extensions** and ensure `uuid-ossp` is enabled

### 5. Run

```bash
# Web
flutter run -d chrome

# Android
flutter run -d android

# iOS
flutter run -d ios
```

---

## 📁 Project Structure

```
lib/
├── config/
│   ├── supabase_config.dart    # Supabase credentials
│   └── theme.dart              # Premium dark theme + color system
├── models/
│   └── models.dart             # Profile, Couple, Channel, Message
├── services/
│   ├── auth_service.dart       # Auth + couple pairing logic
│   ├── chat_service.dart       # Channels, messages, typing, read receipts
│   └── presence_service.dart   # Online/offline tracking
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart   # Login/signup with glassmorphism
│   │   └── pair_screen.dart    # Couple pairing flow
│   ├── chat/
│   │   └── chat_screen.dart    # Full chat interface
│   └── home/
│       └── home_screen.dart    # Channel list + partner status
├── widgets/
│   ├── message_bubble.dart     # Animated message bubbles
│   └── typing_indicator.dart   # Pulsing dots indicator
└── main.dart                   # App entry point + service wiring

supabase/
└── migrations/
    └── 001_initial_schema.sql  # Complete DB schema + RLS policies
```

---

## 🗺️ Roadmap

- **Phase 2**: Rich media (photos/video), custom themes, dynamic accent colors
- **Phase 3**: Spaced-repetition trivia, 3D memory globe, time capsules, ambient audio room, relationship XP system, Android widget, AI weekly newsletter

---

## 🔒 Data Sovereignty

This app is designed for complete data ownership:
- **Self-host** Supabase on Oracle Cloud Always Free Tier (4 ARM cores, 24GB RAM, $0/month)
- Zero third-party telemetry or analytics
- All data encrypted at rest and in transit
- RLS policies ensure only couple members can access their data
