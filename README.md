# Casama 🦉

> **Making shared living simpler, warmer, and more coordinated.**
>
> Mobile application built with **Flutter**, **Supabase**, **Riverpod**, and **GoRouter**.
> *Final Project for Application Development*

[![Android APK](https://img.shields.io/badge/Android-APK%20Ready%20(59.5MB)-3DDC84?logo=android&logoColor=white)](#-android-apk-build--installation)
[![Tests](https://img.shields.io/badge/Tests-Passing-success)](#-testing--analysis)
[![Backend](https://img.shields.io/badge/Backend-Supabase%20PostgreSQL%20%2B%20RLS-3ECF8E?logo=supabase&logoColor=white)](#-database-schema--security)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Web-1C2E4A)](#)

---

## 📱 Overview

**Casama** (from *Casa* — house — and *Kasama* — companion) solves everyday living coordination breakdowns in shared dorms, apartments, and family households. Instead of letting delivery schedules, COD amounts, household chores, utility bills, or missing items get buried in busy group chats, Casama organizes them into structured, realtime household records backed by Supabase.

### Navigation Shell
Casama uses a **5-slot bottom navigation bar** paired with a slide-over household drawer (`CasamaHouseholdDrawer`):
1. **Home** — Greeting hero, manual presence, live attention alerts, Shared CASnaps preview, and Casa Schedule.
2. **Boards** — Unified 4-tab swipeable hub (`Parcels`, `Tasks`, `Bills`, `Items`) with a morphing contextual action FAB.
3. **CASnap** — Raised center camera shutter button for instant household photo sharing.
4. **Chat** — Casama Connect directory (Household Group Chat, Household-Wide Chat Spaces, Direct Messages, and Meet-ups).
5. **Profile** — Good Kasama Points rank, personal details, invite-only household code sharing, appearance themes, and settings.

---

## ✨ Core Features

### 1. Home Dashboard, Presence & Casa Schedule
* **Split Mascot Hero & Status Summary:** Greets the signed-in member by nickname and summarizes how many housemates are currently home alongside active parcels and alerts.
* **Manual "Who's Home" Presence:** Housemates manually toggle between **Home** and **Out** with optional status notes (e.g., *"Studying"*, *"At library"*). Every update appends an auditable row to `presence_events` with a visible last-updated timestamp—**zero GPS or background location tracking** is used.
* **Live Attention Needed:** Highlights overdue bills and urgent open tasks, routing directly to the relevant Board tab.
* **Shared CASnaps Preview Card:** Displays a 3×2 rounded tile grid of the 5 latest shared household shots plus a `+N View all` entry into the full gallery.
* **Casa Schedule (`HouseholdCalendarView`):** Compact calendar strip with month navigation and category filter pills (`All`, `Parcels`, `Tasks`, `Bills`, `Meetups`) synced to real household data.

### 2. Unified Boards Hub (`BoardsHubScreen`)
Four swipeable household tools share a unified header tab switcher (`250ms` directional transitions) and an animated contextual FAB (`Add parcel`, `Add task`, `Edit billings`, `Report item`):

* **Parcels & Deliveries**
  * Track upcoming couriers (`Shopee`, `Lazada`, etc.), expected arrival date/time, payment type (`Paid` or `COD`), PHP (`₱`) COD amount, and delivery notes.
  * Roommates toggle availability (`Available` / `Unavailable`); if every eligible housemate is unavailable, a visible conflict alert warns the buyer.
  * Tapping **I Got It** records the receiver, prevents duplicate claims (`parcel_claims.parcel_id` unique constraint), tracks COD settlement status (coordination record only—no payment processing), and awards **+5 Kasama Points**.
* **Household Tasks & Embedded Task Roulette**
  * Create unassigned tasks across four categories: **Cleaning** (`cleaning`), **Repair / Maintenance** (`repair_maintenance`), **Restock** (`restock`), and **Personal Request** (`personal_request`), with urgency levels (`Low`, `Medium`, `Urgent`), optional due dates, and `Open → In Progress → Done` status tracking.
  * Tapping a task card smoothly expands an inline action tray with **Spin** and **Mark as Done** (`+5 pts` for general tasks, `+2 pts` for restocks).
  * **Embedded Task Roulette (`TaskRouletteSheet`):** Launches as a slide-up bottom sheet directly inside Household Tasks (via the **Spin Roulette** header pill or an individual task's **Spin** action). Spins a `4000ms` decelerating wheel of eligible **Home** housemates, enforces a **24-hour spin cooldown** per user, and notifies the selected housemate with **Accept (+2 bonus pts)** or **Reject (-3 pts)**. Pending spins auto-expire after 2 hours or immediately when another roommate accepts.
* **Bills & Payments**
  * Track shared utilities (`Internet`, `Electricity`, `Water`, `Gas`, `Rent`, `Appliance`, `Association Dues`, `Maintenance Fee`, `Other`) with PHP (`₱`) formatting, due dates, overdue borders/badges, and push-reminder schedules (`On due date`, `1 day before`, `3 days before`, `1 week before`).
  * Add or edit bills via the **Setup Billing** slide-up sheet and mark bills paid with payer attribution. Stores shared household records only—never bank or payment credentials.
* **Lost & Found**
  * Focused two-tab tracker (**Lost** and **Found**) backed by dedicated `lost_items` (`open → found → returned`) and `found_items` (`unclaimed → claimed → returned`) tables.
  * Supports owner/finder status transitions, duplicate-claim protection, and **+3 Kasama Points** when a lost item is found and returned.

### 3. CASnap (Household Photo Sharing)
* **Camera Viewfinder (`QuickSnapCameraScreen`):** Full-screen dark capture frame (`#070C16`) with a 1:1 corner-bracketed viewfinder, `450ms` shutter flash animation, `350ms` `180°` camera flip toggle, and a `#141B29` recipient picker sheet (**Everyone in the Casa** or **Selected Friends**).
* **Household Gallery & Lightbox (`QuickSnapFeedScreen`):** Date-grouped 3-column photo grid with sticky filter pills (`All`, `Your Shots`, per-housemate filters, `Direct`), a `200ms` Hero/fade Lightbox viewer, emoji reactions, and comments. Photos upload to Supabase Storage (`casnaps` bucket).

### 4. Casama Connect (Chat & Meet-ups)
* **Household Group Chat:** Shared room automatically provisioned for every member of the household.
* **Household-Wide Chat Spaces:** Topic rooms (e.g., *Grocery & Supplies*) with custom icons and descriptions. Every member of the Casa is automatically included—no space join codes or per-member checklists.
* **Direct Messages:** Private 1-on-1 conversations strictly isolated via `conversation_members`.
* **Unread Tracking & Idempotency:** Per-user unread badges driven by `conversation_reads.last_read_at` and duplicate-safe message sending via `client_message_id`.
* **Meet-up Invitations:** Slide-up **Plan a Meet-up** sheet using manual shared-spot text labels (zero GPS) that posts an interactive RSVP card (**Going**, **Maybe**, **Can't make it**) directly inside the chat thread.

### 5. Good Kasama Points, Leaderboard & Profile
| Eligible Action | Points |
| --- | --- |
| Parcel received & confirmed | `+5` |
| Household task completed (Cleaning / Repair / Personal) | `+5` |
| Restock task completed | `+2` |
| Lost item found & returned | `+3` |
| Task Roulette challenge accepted | `+2` bonus |
| Task Roulette challenge rejected | `-3` |

Points are stored in an auditable `points_ledger` protected by a composite unique constraint `(user_id, action_type, reference_id)` so retries never double-award points. **ProfileScreen** provides monthly leaderboard rankings, profile editing, avatar uploads (`avatars` bucket), invite-only household code sharing (`InviteHousemateSheet`), Light/Dark/System theme switching, and Terms/Privacy documentation.

---

## 🎨 Design System, Mascot & Motion

### Visual Tokens (`CasamaPalette`)
| Token | Hex | Usage |
| --- | --- | --- |
| **Forest Teal** | `#37655E` | Stepped organic wave headers, active filter pills, group chat card |
| **Muted / Misty Sage** | `#688C83` / `#A5B9B0` | Layered wave horizon transitions |
| **Soft Warm Beige** | `#EAE4D7` | Light-mode canvas background |
| **Pure White / Hairline** | `#FFFFFF` / `#DCE3E0` | Cards (`20px` radius), modal sheets (`28px` top radius), `1px` borders |
| **Soft Warm-Gray** | `#EAE6DF` | Input fills, segmented tracks, neutral chips |
| **Primary Coral / Accent** | `#C44938` / `#E87461` | Primary CTAs, raised CASnap button, FABs, unread dots |
| **Deep Navy / Muted Slate** | `#1C2E4A` / `#54646C` | Primary ink and secondary metadata |
| **Warm Gold** | `#F4B544` | Header orbital ring ornaments, camera shutter ring, Gold Tier accents |
| **Semantic Success / Error** | `#2E7D32` / `#C62828` | Home status, Accept/Paid states, Overdue/Reject states |

* **Typography:** `Plus Jakarta Sans` (Bold/SemiBold) for headlines, titles, and summary numbers; `Inter` (Regular/Medium/SemiBold, tabular numerals) for body text, metadata, and chips.
* **Theme Parity & Accessibility:** Full Light, Dark, and System Default themes (`theme_provider.dart`), minimum `48×48` logical-pixel touch targets, semantic labels on icon buttons, and non-color status indicators.
* **Brand Mascot (Cas the Owl):** Rendered via `CasMascotView` using background-free transparent PNG illustrations in `assets/images/cas/` (`migo_chat.png`, `migo_chores.png`, `migo_deliveries.png`, `migo_roulette.png`, `migo_tasks.png`, `together_cards.png`), peeking cleanly behind opaque summary cards and headers with zero box frames or cast drop shadows.
* **Motion Primitives (`casama_motion.dart`):**
  * `CasamaPressable`: `150ms` tactile press scale (`0.95` standard, `0.90` FABs).
  * `CasamaDirectionalSwitcher`: `250ms` `Curves.easeOut` directional slide/fade across Boards tabs.
  * `CasamaMorphingFab`: `320ms` spring overshoot entrance (`Cubic(0.34, 1.56, 0.64, 1.0)`) and `180ms` exit.
  * `CasamaSheetScaffold` & `CasamaHouseholdDrawer`: `280ms` slide-up sheets, `250ms` slide-over drawer, and `200ms` scrim fades.
  * **Reduced Motion:** All motion primitives inspect `MediaQuery.disableAnimationsOf(context)` and collapse animations cleanly when reduced motion is enabled.

---

## 🛠️ Tech Stack & Architecture

* **Framework:** Flutter (Dart 3.5+, Material 3)
* **Architecture:** Feature-first layered architecture (`lib/core`, `lib/features`, `lib/shared`, `lib/data`)
* **State Management:** Flutter Riverpod (`flutter_riverpod: ^2.6.1`)
* **Routing:** GoRouter declarative routing (`go_router: ^14.8.1`) with auth & household membership guards
* **Backend Platform:** Supabase (PostgreSQL 15+, Auth, Realtime, Storage)
* **Local Preferences:** `shared_preferences` (theme persistence & optimistic cooldown caching)
* **Typography:** Google Fonts (`Plus Jakarta Sans` + `Inter`)

### 📂 Project Structure
```text
Casama/
├── assets/
│   └── images/
│       └── cas/                        # Transparent PNG Cas mascot assets (migo_*.png, together_cards.png)
├── supabase/
│   ├── migrations/                     # PostgreSQL schema, RLS policies, triggers & storage setup
│   └── seed.sql                        # Optional demo scenario seed script
├── lib/
│   ├── main.dart                       # Supabase initialization & app entrypoint
│   ├── core/
│   │   ├── constants/                  # colors.dart (CasamaPalette), dimensions.dart (8pt spacing scale)
│   │   ├── theme/                      # app_theme.dart (Light & Dark), theme_provider.dart
│   │   └── router/                     # app_router.dart (GoRouter routes & guards)
│   ├── shared/
│   │   └── widgets/                    # casama_motion.dart, wave headers, cards, filters, sheets, CasMascotView
│   ├── data/
│   │   ├── casama_repository.dart      # Abstract repository interface
│   │   ├── models.dart                 # Domain models & Supabase JSON serialization
│   │   ├── supabase_config.dart        # Environment config (--dart-define)
│   │   ├── supabase_repository.dart    # Live Supabase CRUD, Storage & Realtime implementation
│   │   ├── mock_repository.dart        # In-memory repository powering automated tests
│   │   └── repository_provider.dart    # Active runtime Riverpod provider (SupabaseRepository)
│   └── features/
│       ├── auth/                       # Splash, Auth (Sign Up / Log In / Demo), Optional Profile
│       ├── legal/                      # TermsConsentScreen & TermsPrivacyScreen
│       ├── onboarding/                 # Intro, DevicePermissions, Interactive Tour
│       ├── dashboard/                  # MainNavigationShell, DashboardScreen, BoardsHubScreen, Drawer
│       ├── calendar/                   # HouseholdCalendarView (Casa Schedule)
│       ├── parcels/                    # Parcels tab, AddParcelSheet, COD & availability tracking
│       ├── items/                      # LostFoundScreen (Lost & Found tabs) & ReportItemSheet
│       ├── tasks/                      # Household Tasks tab, NewTaskSheet & embedded TaskRouletteSheet
│       ├── bills/                      # Bills tab, SetupBillingSheet, BillDetailScreen
│       ├── quicksnap/                  # CASnap camera, recipient picker, Home card, gallery & lightbox
│       ├── chat/                       # Casama Connect: Directory, Group/Space/DM threads, Meet-up & Space sheets
│       ├── household/                  # HouseholdSetupScreen & invite-only InviteHousemateSheet
│       ├── points/                     # LeaderboardScreen & Good Kasama Points history
│       ├── profile/                    # ProfileScreen, EditProfileDialog, ProfileCameraSheet
│       └── settings/                   # AppSettingsScreen (Account, Appearance, Notifs, Privacy, About)
└── test/
    ├── phase1_design_system_test.dart  # Design tokens, motion & mascot tests
    ├── unit_test.dart                  # Business logic, roulette & repository unit tests
    ├── widget_test.dart                # UI & form widget tests
    └── e2e_integration_test.dart       # End-to-end workflow & QA tests
```

---

## 🗄️ Database Schema & Security

The live PostgreSQL schema consists of **24 tables** isolated by `household_id`:

| Domain | Tables |
| --- | --- |
| **Identity & Households** | `profiles`, `households`, `household_members` |
| **Presence & Activity** | `presence_events`, `notifications`, `points_ledger` |
| **Parcels** | `parcels`, `parcel_availability`, `parcel_claims` |
| **Tasks & Roulette** | `maintenance_tasks`, `chore_roulette_records` |
| **Lost & Found** | `lost_items`, `found_items` |
| **Bills** | `bills` |
| **CASnap** | `quick_snaps`, `quick_snap_recipients`, `quick_snap_reactions`, `quick_snap_comments` |
| **Casama Connect** | `conversations`, `conversation_members`, `conversation_reads`, `messages`, `meet_up_invitations`, `meet_up_responses` |

### Key Backend Safeguards
* **Row Level Security (RLS):** Enabled across all 24 tables. Policies validate household membership server-side via `public.is_household_member(target_household_id)`, while direct messages verify explicit `conversation_members` participation.
* **Automatic Profile Provisioning:** An `after insert` trigger (`on_auth_user_created` → `handle_new_user()`) automatically inserts a `public.profiles` row on Supabase Auth sign-up.
* **Storage Buckets:** `casnaps` and `avatars` buckets store shared photos and profile pictures with authenticated upload and owner update/delete policies.
* **Realtime Publication:** All active household tables are registered in `supabase_realtime` for sub-2-second cross-device updates.
* **Database Integrity Constraints:** Enforced in PostgreSQL via `CHECK` constraints (4 task categories, positive COD only when `payment_type = 'cod'`, roulette `decision`/`status` sync) and `UNIQUE` constraints (`household_members`, `parcel_availability`, `parcel_claims.parcel_id`, `points_ledger`, `messages.client_message_id`).
* **Zero Secrets & Zero GPS:** Only the Supabase publishable/anon key is passed to the Flutter client (never the `service_role` key). Presence is strictly manual and meet-up spots are plain text labels.

---

## 🚀 Getting Started

### 1. Prerequisites
* Flutter SDK (`3.24+`) & Dart SDK (`3.5+`)
* Android Studio / Xcode (or Chrome / macOS for desktop testing)
* A Supabase project

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Configure Supabase
1. Copy `.env.example` to `.env` (if using local env tooling):
   ```bash
   cp .env.example .env
   ```
2. In the **Supabase SQL Editor**:
   * Create the 24-table schema (`casama_init.sql` / `supabase/migrations/`).
   * Execute the RLS, `handle_new_user()` Auth trigger, Storage bucket (`casnaps`, `avatars`), and `supabase_realtime` publication script.
3. Under **Authentication → Providers → Email**, turn **OFF** **Confirm email** during local development/demos so newly registered users immediately obtain an active `auth.uid()` session for household creation.

### 4. Run the App
Casama connects to your live Supabase backend via `SupabaseRepository` using `--dart-define`:

```bash
# Run on Android emulator or connected physical device
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key

# Or target a specific platform
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

*(Automated tests continue to run offline in-memory against `MockRepository` with zero network setup required.)*

---

## 📦 Android APK (Build & Installation)

You can build and install Casama directly onto any Android device (phone, tablet, or emulator) without needing an app store.

### 1. Pre-built Release APK
* **Path:** `build/app/outputs/flutter-apk/app-release.apk`
* **Size:** `~59.5 MB` (Self-contained with all assets, transparent PNG mascots, and fonts)
* **Android Target:** Android 5.0 (API 21) up to Android 15 (API 35+)

### 2. How to Build the APK
Pass your Supabase credentials at build time so the release binary connects to your live project:

```bash
# Build standalone release APK
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key

# Or build split APKs (~18 MB per CPU architecture)
flutter build apk --split-per-abi \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

### 3. How to Install on Your Android Phone

#### Method A: Direct Install via USB (ADB)
Connect your phone with **USB Debugging** enabled and run:
```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

#### Method B: Wireless / Direct Sideloading
1. Transfer `build/app/outputs/flutter-apk/app-release.apk` to your phone via Google Drive, Telegram, USB, or AirDrop/Nearby Share.
2. Open your phone's **Files** or **Downloads** app and tap `app-release.apk`.
3. If prompted, allow *"Install unknown apps"* in Android settings.
4. Tap **Install** and launch Casama.

#### Method C: GitHub Releases (For evaluators & classmates)
1. Go to your GitHub repository → **Releases** → **Draft a new release**.
2. Tag a version (e.g., `v1.0.0`).
3. Drag and drop `build/app/outputs/flutter-apk/app-release.apk` into the release binaries section.
4. Click **Publish release** for 1-click download and installation.

---

## 🧪 Testing & Analysis

Run static analysis and the full automated test suite (unit, widget, design-system, and end-to-end integration tests backed by `MockRepository`):

```bash
# Run static analysis (must report: No issues found!)
flutter analyze

# Run full unit, widget, and E2E test suite
flutter test
```

### Verified Coverage
* **Design System & Accessibility:** Light/Dark `CasamaPalette` contrast, transparent PNG `CasMascotView` rendering, responsive phone/tablet layouts, and `MediaQuery.disableAnimationsOf(context)` reduced-motion behavior.
* **Auth, Legal & Household Setup:** Account registration, login/logout, invite-only code joining, zero-GPS privacy disclosures, and onboarding flow.
* **Home Dashboard & Presence:** Live presence event derivation, status notes, attention alerts, Shared CASnaps preview card, and Casa Schedule filtering.
* **Unified Boards Hub:** Horizontal swipe navigation, morphing contextual FAB, COD parcel validation & duplicate-claim prevention, 4-category tasks with expandable `Spin` / `Mark as Done` actions, `TaskRouletteSheet` wheel alignment & 24h cooldown / Accept-Reject / expiry transitions, Bills CRUD & reminders, and split `lost_items` / `found_items` lifecycles.
* **CASnap & Casama Connect:** Camera capture & recipient selection, Gallery/Lightbox filtering, household-wide Chat Spaces (no join codes), private DMs, `conversation_reads` unread badges, idempotent message retries, and Meet-up RSVP cards.
* **Security & Realtime:** Cross-household RLS isolation (`SELECT`, `INSERT`, `UPDATE`, `DELETE`) across separate households and live multi-device synchronization.

---

## 🎬 Live Demo Walkthrough (10 Steps)

1. **Splash & Auth:** Launch Casama to showcase the stepped teal-to-beige wave header, transparent Cas mascot, and Sign Up / Log In flow.
2. **Household Setup:** Create a new household (generating a unique invite code) or join an existing household from a second device.
3. **Live Presence & Casa Schedule:** Toggle **You: Home / Out** with a status note and filter scheduled activities on the Home calendar.
4. **Parcels & COD:** Swipe to **Parcels**, add a COD delivery, toggle availability (triggering a conflict alert if everyone is unavailable), and tap **I Got It** to record receipt and earn **+5 pts**.
5. **Household Tasks & Task Roulette:** Create an unassigned task under one of the 4 categories, tap a task tile to reveal **Spin** and **Mark as Done**, spin **Task Roulette** for a Home housemate, and demonstrate **Accept (+2 bonus pts)** / **Reject (-3 pts)** and the 24h cooldown.
6. **Bills & Payments:** Open **Setup Billing** to add or edit a shared utility bill and mark an overdue bill paid.
7. **Lost & Found:** Switch between the **Lost** and **Found** tabs, post a missing item, and mark it found/returned (**+3 pts**).
8. **CASnap:** Tap the raised center camera button, choose recipients (**Everyone** or specific roommates), snap a photo, and inspect it in the **Gallery / Lightbox**.
9. **Casama Connect:** Send a message in the household group chat, create a household-wide **Chat Space**, and RSVP on an embedded **Meet-up Invitation** card.
10. **Profile, Leaderboard & Themes:** Inspect **Good Kasama Points**, upload a profile photo, and toggle **Light, Dark, and System Default** themes across all screens.

---

## 🔮 Future Enhancements

* Opt-in geofencing with manual presence fallback and explicit permission prompts.
* Offline write queue and automatic conflict-aware synchronization (including offline chat message queuing).
* Push notifications (FCM/APNs) for urgent household alerts, Task Roulette picks, and chat messages.
* Multi-household switching per account and Filipino/English localization.
* Shared grocery/pantry lists and household activity analytics.

---

*Final Project for Application Development — Built with care for better shared living.*