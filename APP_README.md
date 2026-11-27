# Casama 🦉

> **Making shared living simpler, warmer, and more coordinated.**
>
> Mobile application built with **Flutter**, **Supabase**, **Riverpod**, and **GoRouter**.
- Final Project For Application Development

[![Android APK](https://img.shields.io/badge/Android-APK%20Ready%20(59.5MB)-3DDC84?logo=android&logoColor=white)](#-android-apk-build--installation)
[![Tests](https://img.shields.io/badge/Tests-78%20Passed-success)](#-testing--analysis)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Web-navy)](#)

---

## 📱 Overview

Casama solves everyday living coordination breakdowns in shared dorms, apartments, and households. The app provides structured records and real-time updates for:
* **Manual Presence**: Know who is *Home* or *Out* at a glance, with contextual status notes.
* **Delivery & COD Board**: Track incoming couriers (Shopee, Lazada, etc.), roommate availability, conflict alerts, and Cash-on-Delivery owed records.
* **Lost & Found / Shared Housewares**: Report lost items, claim found goods, and ping housemates ("Who has it?").
* **Maintenance & Restock**: Categorized task tracking (DIY/Roommate, Landlord/Admin, Household Restock) with urgency prioritization.
* **Good Kasama Points**: Idempotent event ledger rewarding helpful housemates, paired with a monthly leaderboard.
* **Casama Connect**: In-app group chat, private direct messaging, and structured face-to-face meet-up invitations.
* **Chore Roulette**: An interactive animated spinning wheel to fairly and playfully settle household chores.
* **Brand Mascot (Cas the Owl)**: Friendly companion embedded across onboarding, empty states, and milestone celebrations.

---

## 🛠️ Tech Stack & Architecture

* **Framework**: Flutter (Dart 3)
* **Architecture**: Feature-first layered architecture (`lib/core`, `lib/features`, `lib/shared`, `lib/data`)
* **State Management**: Flutter Riverpod (`flutter_riverpod: ^2.6.1`)
* **Routing**: GoRouter declarative routing (`go_router: ^14.8.1`)
* **Backend Platform**: Supabase (PostgreSQL 15+, Auth, Realtime, Storage)
* **Typography**: Google Fonts (Inter)

---

## 🚀 Getting Started

### 1. Prerequisites
* Flutter SDK (3.24+)
* Dart SDK (3.5+)
* Android Studio / Xcode (or Chrome/macOS for desktop testing)

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Running the App

#### High-Fidelity Mock Mode (Zero Setup Required)
Out of the box, Casama boots into a high-fidelity in-memory demo environment pre-loaded with **Casa 204** (JP, Maria, Alex, Ria) and all 10 screens matching `Casama Mockup Ui.png`:

```bash
# Run on Android emulator (e.g. Pixel 6 API 34)
flutter emulators --launch Pixel_6_API_34
flutter run -d Pixel_6_API_34

# Or run directly on macOS Desktop
flutter run -d macos

# Or run on Chrome
flutter run -d chrome
```

#### Connecting to your Supabase Project
1. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```
2. In your Supabase Dashboard:
   * Execute the schema migration in `supabase/migrations/20261109000001_initial_schema.sql` via SQL Editor.
   * (Optional) Pre-seed the demo scenario by running `supabase/seed.sql`.
   * Set **Authentication > Settings > Confirm email = OFF** to allow instantaneous demo registrations.
3. Launch the app with your Supabase credentials:
   ```bash
   flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-anon-key
   ```

---

## 📦 Android APK (Build & Installation)

You can build and install Casama directly onto any Android device (phone, tablet, or emulator) without needing an app store.

### 1. Pre-built Release APK
The optimized production APK has already been compiled:
* **Path**: `build/app/outputs/flutter-apk/app-release.apk`
* **Size**: `~59.5 MB` (Self-contained, includes all assets, mascot graphics, and fonts)
* **Android Target**: Android 5.0 (API 21) up to Android 15 (API 35+)

### 2. How to Build the APK
To recompile the APK at any time, run:

```bash
# Build standalone release APK
flutter build apk --release

# Or build split APKs (reduces size to ~18 MB per architecture)
flutter build apk --split-per-abi
```

### 3. How to Install on Your Android Phone

#### Method A: Direct Install via USB (ADB)
Connect your phone with **USB Debugging** enabled and run:
```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

#### Method B: Wireless / Direct Sideloading
1. Transfer `build/app/outputs/flutter-apk/app-release.apk` to your phone via Google Drive, Telegram, USB, or direct transfer.
2. Open your phone's **Files** or **Downloads** app and tap `app-release.apk`.
3. If prompted, allow *"Install unknown apps"* in Android settings.
4. Tap **Install** and open Casama!

#### Method C: GitHub Releases (For evaluators & classmates)
To share the APK via a direct download link:
1. Go to your GitHub repository ➔ **Releases** ➔ **Draft a new release**.
2. Tag a version (e.g. `v1.0.0`).
3. Drag and drop `build/app/outputs/flutter-apk/app-release.apk` into the release binaries section.
4. Click **Publish release**. Anyone can now download and install it with 1 click.

---

## 🧪 Testing & Analysis

Casama comes with a comprehensive suite of **78 automated tests** (30 unit tests + 48 widget/integration tests) verifying full application workflows, authorization rules, and state management:

```bash
# Run static analysis (zero warnings/errors enforced)
flutter analyze

# Run unit and widget test suite
flutter test
```

### Verified Features:
* **Splash & Welcome**: Brand mascot, tagline, and smooth authentication onboarding.
* **Auth & Profile Setup**: Account creation, one-tap demo login, and optional profile fields (Full Name, Nickname, Age, Avatar).
* **Legal & Device Permissions**: Explicit zero-tracking location privacy statement and camera/photos explanations.
* **Onboarding & Tutorial**: 3-step value carousel and interactive feature highlighting.
* **Home Dashboard & Calendar**: Time-based greeting, live presence, 2x2 quick access, and month-navigating household calendar.
* **Plus (+) Quick Actions**: Instant bottom sheet dispatching parcels, items, chores, meet-ups, and invites.
* **Chat & Connect**: Group chat with RSVP cards, 1-on-1 private messaging with strict household membership authorization.
* **Housemate Management**: Privacy-preserving user search, invite code sharing, and pending invite accept/decline.
* **Profile & Settings**: Full name, nickname, age editing, avatar replacement/removal, points audit ledger, and 5-section settings with persistent Light, Dark, and System theme switching.

---

## 📂 Project Structure

```text
Casama/
├── assets/
│   └── images/
│       └── cas/                  # Isolated Cas the Owl mascot illustrations & logos
├── supabase/
│   ├── migrations/               # PostgreSQL schema & RLS policies
│   └── seed.sql                  # One-click Casa 204 mock scenario pre-population
├── lib/
│   ├── core/
│   │   ├── constants/            # Colors, spacing tokens (8pt rhythm), dimensions
│   │   ├── theme/                # CasamaTheme (Light & Dark), Inter typography, ThemeProvider
│   │   └── router/               # GoRouter configuration (18 routes)
│   ├── shared/
│   │   └── widgets/              # Reusable Casama buttons, chips, avatar cards, Cas mascot views
│   ├── data/
│   │   ├── models.dart           # Pure data models (UserProfile, MemberPresence, etc.)
│   │   ├── mock_repository.dart  # High-fidelity mock repository with reactive StateNotifier
│   │   ├── repository_provider.dart
│   │   └── supabase_config.dart  # Supabase client integration & mock mode fallback
│   └── features/
│       ├── auth/                 # Splash, Login, Register, Optional Profile screens
│       ├── legal/                # Terms consent & privacy policy screens
│       ├── onboarding/           # Welcome intro, interactive tutorial, device permissions
│       ├── dashboard/            # Home dashboard, Presence cards, 2x2 grid, Navigation shell
│       ├── calendar/             # Interactive household calendar aggregating chores & deliveries
│       ├── parcels/              # Deliveries, COD accountability, Availability & Claims
│       ├── items/                # Lost & Found, Borrowed items
│       ├── tasks/                # Maintenance, Restock chores, Urgency badges
│       ├── chat/                 # Casama Connect: Directory, Group chat, DMs, Meet-ups
│       ├── household/            # Add housemate modal (search, code, pending invites)
│       ├── chore_roulette/       # Interactive animated spinning wheel mini-game
│       ├── profile/              # User profile, Edit Profile modal, Points ledger
│       └── settings/             # 5-section settings (Account, Appearance, Notifs, Privacy, About)
└── test/
    ├── unit_test.dart            # 27 comprehensive unit tests
    └── widget_test.dart          # 36 comprehensive widget tests
```
