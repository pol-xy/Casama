# Casama 🦉

> **Making shared living simpler, warmer, and more coordinated.**
>
> Mobile application built with **Flutter**, **Supabase**, **Riverpod**, and **GoRouter**.
> *Final Project for Application Development*

[![Android APK](https://img.shields.io/badge/Android-APK%20Build-3DDC84?logo=android&logoColor=white)](#-android-apk-build--installation)
[![Tests](https://img.shields.io/badge/Tests-162%20Passing-success)](#-testing--analysis)
[![Backend](https://img.shields.io/badge/Backend-Supabase%20PostgreSQL%20%2B%20RLS-3ECF8E?logo=supabase&logoColor=white)](#-database-schema--security)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Web-1C2E4A)](#)

---

## 📱 Overview

**Casama** (from *Casa* — house — and *Kasama* — companion) solves everyday living coordination breakdowns in shared dorms, apartments, and family households. Instead of letting delivery schedules, COD amounts, household chores, or missing items get buried in busy group chats, Casama organizes them into structured, realtime household records backed by Supabase.

### Navigation Shell
Casama uses a **5-slot bottom navigation bar** paired with a slide-over household drawer (`CasamaHouseholdDrawer`) and a unified top-right **Notifications** bell (`CasamaNotificationBellButton` → `CasamaNotificationsSheet`) across top-level tabs:
1. **Home** — Greeting hero, manual presence, live attention alerts, Shared CASnaps preview, and Casa Schedule.
2. **Boards** — Unified 3-tab swipeable hub (`Parcels`, `Tasks`, `Items`) with a morphing contextual action FAB.
3. **CASnap** — Raised center camera shutter button for instant household photo sharing.
4. **Chat** — Casama Connect directory (Household Group Chat, Custom Chat Spaces, Individual Conversations, and Housemates Agenda).
5. **Profile** — Good Kasama Points rank, personal details, invite-only household code sharing, appearance themes, and settings.

---

## ✨ Core Features

### 1. Home Dashboard, Presence & Casa Schedule
* **Split Mascot Hero & Status Summary:** Greets the signed-in member by nickname and summarizes how many housemates are currently home alongside active member counts.
* **Manual "Who's Home" Presence:** Housemates manually toggle between **Home** and **Out** with optional status notes (e.g., *"Studying"*, *"At library"*). Every update appends an auditable row to `presence_events` with a visible last-updated timestamp—**zero GPS or background location tracking** is used.
* **Live Attention Needed:** Highlights urgent open tasks and COD handoffs, routing directly to the relevant Board tab.
* **Shared CASnaps Preview Card:** Displays a 3×2 rounded tile grid of the 5 latest shared household shots plus a `+N View all` entry into the full gallery.
* **Casa Schedule (`HouseholdCalendarView`):** Compact calendar strip with month navigation and category filter pills (`All`, `Parcels`, `Tasks`, `Agenda`) synced to real household data.

### 2. Unified Boards Hub (`BoardsScreen`)
Three swipeable household boards share a unified header tab switcher (`250ms` directional transitions) and an animated contextual FAB (`Add parcel`, `Add task`, `Report item`):

* **Parcels & Deliveries**
  * Three segmented views (**My Parcels**, **Upcoming**, **History**) for tracking couriers (`Shopee`, `Lazada`, etc.), expected arrival date/time, payment type (`Paid` or `COD`), PHP (`₱`) COD amount, and delivery notes.
  * Roommates toggle availability (`Available` / `Unavailable`); if every eligible housemate is unavailable, a visible conflict alert warns the buyer.
  * Tapping **I Got It** records the receiver, prevents duplicate claims (`parcel_claims.parcel_id` unique constraint), tracks COD settlement status (coordination record only—no payment processing), and awards **+5 Kasama Points**.
* **Household Tasks & Embedded Task Roulette**
  * Open-task board with **Ongoing Tasks** and **Completed Tasks** segments across four categories: **Cleaning** (`cleaning`), **Repair / Maintenance** (`repair_maintenance`), **Restock** (`restock`), and **Personal Request** (`personal_request`), with urgency levels (`Low`, `Medium`, `Urgent`), optional due dates, and dynamic Category + Urgency rewards (`+7 to +11 pts` for Cleaning/Restock; `+10 to +14 pts` for Repair/Personal Request).
  * Tapping an ongoing task card expands an inline action tray with **Spin** (for unspun tasks) and **Mark as Done**. Completing a task you created yourself strictly awards **0 pts** (and hides bonus indicators) to prevent self-farming.
  * **Embedded Task Roulette (`TaskRouletteSheet`):** Launches as a slide-up bottom sheet directly inside Household Tasks (via the **Spin Roulette** header pill or an individual task's **Spin** action). Spins a `4000ms` decelerating wheel across eligible **Home** housemates with **zero cooldown** (back-to-back spins across unspun tasks work immediately). Each task allows **strictly one irreversible spin** (`spin_task_roulette` RPC + `UNIQUE (task_id)`): spinning immediately sets the roulette assignment, notifies the chosen housemate (`roulette_chosen`), and stacks **+4 bonus pts** on top of base points when completed by a non-creator (`11–18 pts` total).
* **Lost & Found**
  * Four-tab tracker (**My Activity**, **Lost**, **Found**, **Resolved**) backed by `lost_items` and `found_items`, plus sub-filters under **My Activity**.
  * Supports linked find submissions with owner **Confirm Match / Not a Match** review (**+5 pts** when a lost item is found and returned) as well as standalone found-item claims (**+2 pts** awarded to the finder when claimed).

### 3. CASnap (Household Photo Sharing)
* **Camera Viewfinder (`QuickSnapCameraScreen`):** Full-screen dark capture frame (`#070C16`) with a 1:1 corner-bracketed viewfinder, `450ms` shutter flash animation, `350ms` `180°` camera flip toggle, and a `#141B29` recipient picker sheet (**Everyone in the Casa** or **Selected Friends**).
* **Household Gallery & Lightbox (`QuickSnapFeedScreen`):** Date-grouped 3-column photo grid with sticky filter pills (`All`, `Your Shots`, per-housemate filters, `Direct`), a `200ms` Hero/fade Lightbox viewer, emoji reactions, and comments. Photos upload to Supabase Storage (`casnaps` bucket).

### 4. Casama Connect (Chat & Housemates Agenda)
* **Household Group Chat:** Shared room automatically provisioned for every member of the household, supporting photo attachments (`chat-attachments` bucket), invite code cards, **Plan Housemates Agenda**, and **Spin Chore Roulette** (Group Chat tiebreaker wheel posting a formatted multi-line `🎡 Wheel Spin!` summary).
* **Custom Chat Spaces:** Household-wide topic rooms (e.g., *Grocery & Supplies*) with custom emoji icons and descriptions. Every member of the Casa is automatically included—no space join codes or per-member checklists.
* **Individual Conversations:** Private 1-on-1 DMs strictly isolated via `conversation_members`, automatically sorted by **latest message first** with live per-row **unread counter badges** matching Group Chat and Custom Spaces.
* **UTC Unread Tracking & Idempotency:** Per-user unread badges across Group Chat, Spaces, DMs, and the bottom navigation bar are driven by UTC `conversation_reads.last_read_at` (`nowSupabaseUtcIso()`), with duplicate-safe sends via `client_message_id`.
* **Housemates Agenda (`housemates_agenda_invitations` & `housemates_agenda_responses`):**
  * Household-wide plans with manual location/link labels (zero GPS); a database trigger auto-seeds `'going'` for the creator and `'maybe'` for all other housemates.
  * **4-Status Lifecycle:** `upcoming` → `ongoing` → `done` / `missed`, supported by 1-minute `pg_cron` arrival reminders/chat announcements and automatic missed transitions.
  * **Directory Filtering & Detail Sheet:** Filter pills (`All Active`, `My Agendas` with an ongoing dot indicator, `History`) and full-card `"Tap to view"` cards across every status opening a slide-up sheet with interactive **Going / Maybe / Can't** RSVPs plus creator controls (**Mark as Done**, **Mark as Missed**, **Delete** with cascade).

### 5. Good Kasama Points, Leaderboard & Profile
| Eligible Action | Points |
| --- | --- |
| Receive & confirm a delivery (Parcel) | `+5` |
| Complete Cleaning or Restock task | `+7 to +11` |
| Complete Repair / Maintenance or Personal Request task | `+10 to +14` |
| Task Roulette assignment bonus (non-creator) | `+4 bonus` |
| Find & return a housemate's lost item | `+5` |
| Post a found item claimed by a housemate | `+2` |

*(Self-created tasks always award `0 pts` on completion or Task Roulette spin.)*

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
| **Semantic Success / Error** | `#2E7D32` / `#C62828` | Home status, Going/Paid states, Urgent/Missed/Alert states |

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
* **Environment & Preferences:** `flutter_dotenv` (`.env` / `--dart-define`) & `shared_preferences` (theme persistence, onboarding & camera permission flags)
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
│   │   ├── motion/                     # casama_motion.dart (tactile, directional & reduced-motion primitives)
│   │   ├── theme/                      # app_theme.dart (Light & Dark), theme_provider.dart
│   │   ├── router/                     # app_router.dart (GoRouter routes & guards)
│   │   └── utils/                      # date_time_utils.dart (UTC timestamp helpers)
│   ├── shared/
│   │   └── widgets/                    # wave headers, cards, filters, notifications sheet, CasMascotView
│   ├── data/
│   │   ├── casama_repository.dart      # Abstract repository interface
│   │   ├── models.dart                 # Domain models & Supabase JSON serialization
│   │   ├── supabase_config.dart        # Environment config (.env & --dart-define)
│   │   ├── supabase_repository.dart    # Live Supabase CRUD, RPCs, Storage & Realtime implementation
│   │   ├── mock_repository.dart        # In-memory repository powering automated tests
│   │   └── repository_provider.dart    # Active runtime Riverpod provider (SupabaseRepository)
│   └── features/
│       ├── auth/                       # Splash, Auth (Sign Up / Log In / Demo), Optional Profile
│       ├── legal/                      # TermsConsentScreen & TermsPrivacyScreen
│       ├── onboarding/                 # Intro, DevicePermissions, Interactive Tour
│       ├── dashboard/                  # MainNavigationShell, DashboardScreen, BoardsScreen, Drawer
│       ├── calendar/                   # HouseholdCalendarView (Casa Schedule)
│       ├── parcels/                    # Parcels tab, AddParcelSheet, COD & availability tracking
│       ├── items/                      # LostFoundScreen (My Activity / Lost / Found / Resolved) & sheets
│       ├── tasks/                      # Household Tasks tab (Ongoing / Completed) & NewTaskSheet
│       ├── chore_roulette/             # Embedded TaskRouletteSheet (1-spin-per-task + Chat Wheel Spin)
│       ├── quicksnap/                  # CASnap camera, recipient picker, Home card, gallery & lightbox
│       ├── chat/                       # Casama Connect: Directory, Group/Space/DM threads, Housemates Agenda & Space sheets
│       ├── household/                  # HouseholdSetupScreen, CreateHouseholdSheet & AddHousemateDialog
│       ├── points/                     # LeaderboardScreen & Good Kasama Points history
│       ├── profile/                    # ProfileScreen, EditProfileDialog, ProfileCameraSheet
│       └── settings/                   # AppSettingsScreen (Account, Appearance, Notifs, Privacy, About)
└── test/
    ├── phase1_design_system_test.dart  # Design tokens, motion & mascot tests
    ├── phase2_auth_onboarding_test.dart# Auth, onboarding & terms validation tests
    ├── phase3_shell_home_test.dart     # Shell nav, household switcher & Home tests
    ├── phase4_boards_roulette_test.dart# Boards hub, Parcels & Task Roulette tests
    ├── phase5_casnap_test.dart         # CASnap camera, gallery & reactions tests
    ├── phase6_chat_sheets_test.dart    # Connect directory, spaces, DMs & Housemates Agenda tests
    ├── phase7_profile_secondary_test.dart # Leaderboard, profile & settings tests
    ├── unified_notifications_header_test.dart # Shared header bell & notifications sheet tests
    ├── task_item_chat_refinements_test.dart   # Tasks, Lost & Found & chat template tests
    ├── timestamp_utc_test.dart         # UTC read cursor & message timestamp tests
    ├── supabase_repository_wiring_test.dart   # Repository RPC & serialization tests
    ├── unit_test.dart                  # Business logic, points & repository unit tests
    ├── widget_test.dart                # UI & form widget tests
    └── e2e_integration_test.dart       # End-to-end workflow & QA tests
```

---

## 🗄️ Database Schema & Security

The active Flutter application connects to **23 live Supabase PostgreSQL tables** isolated by `household_id`:

| Domain | Tables |
| --- | --- |
| **Identity & Households** | `profiles`, `households`, `household_members` |
| **Presence & Activity** | `presence_events`, `notifications`, `points_ledger` |
| **Parcels** | `parcels`, `parcel_availability`, `parcel_claims` |
| **Tasks & Roulette** | `maintenance_tasks`, `chore_roulette_records` |
| **Lost & Found** | `lost_items`, `found_items` |
| **CASnap** | `quick_snaps`, `quick_snap_recipients`, `quick_snap_reactions`, `quick_snap_comments` |
| **Casama Connect** | `conversations`, `conversation_members`, `conversation_reads`, `messages`, `housemates_agenda_invitations`, `housemates_agenda_responses` |

### Key Backend Safeguards
* **Row Level Security (RLS):** Enabled across all active tables. Policies validate household membership server-side via `public.is_household_member(target_household_id)`, while direct messages verify explicit `conversation_members` participation.
* **Automatic Profile & Agenda Seeding:** `handle_new_user()` automatically inserts a `public.profiles` row on Supabase Auth sign-up, and `trg_seed_housemates_agenda_default_responses` seeds default `'going'` / `'maybe'` responses whenever a Housemates Agenda is created.
* **Atomic RPCs & Cron Automation:** `spin_task_roulette(p_task_id, p_selected_user_id)` atomically validates membership, enforces one spin per task, awards `+4` bonus eligibility, and emits `'roulette_chosen'` notifications; `pg_cron` transitions agenda statuses (`upcoming` → `ongoing` → `missed`) and posts Group Chat arrival updates.
* **Storage Buckets:** `casnaps`, `avatars`, and `chat-attachments` buckets store shared photos, profile pictures, and chat media with authenticated upload and owner update/delete policies.
* **Realtime Publication:** Active household tables are registered in `supabase_realtime` for cross-device updates.
* **Database Integrity Constraints:** Enforced in PostgreSQL via `CHECK` constraints (4 task categories, positive COD only when `payment_type = 'cod'`, 4 agenda statuses) and `UNIQUE` constraints (`household_members`, `parcel_availability`, `parcel_claims.parcel_id`, `chore_roulette_records.task_id`, `points_ledger`, `messages.client_message_id`).
* **Zero Secrets & Zero GPS:** Only the Supabase publishable/anon key is passed to the Flutter client (never the `service_role` key). Presence is strictly manual and agenda locations/links are plain text labels.

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
1. Copy `.env.example` to `.env` and fill in your project URL and publishable/anon key:
   ```bash
   cp .env.example .env
   ```
2. In the **Supabase SQL Editor**, apply the schema (`supabase/setup_all.sql` / `supabase/migrations/`), RLS policies, triggers, Storage buckets (`casnaps`, `avatars`, `chat-attachments`), RPCs, and `supabase_realtime` publication.
3. Under **Authentication → Providers → Email**, turn **OFF** **Confirm email** during local development/demos so newly registered users immediately obtain an active `auth.uid()` session for household creation.

### 4. Run the App
Casama loads credentials from `.env` automatically or via `--dart-define`:

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

*(Automated tests run offline in-memory against `MockRepository` with zero network setup required.)*

---

## 📦 Android APK (Build & Installation)

You can build and install Casama directly onto any Android device (phone, tablet, or emulator) without needing an app store.

### 1. Build the Release APK
Pass your Supabase credentials via `.env` or `--dart-define` so the release binary connects to your live project:

```bash
# Build standalone release APK
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key

# Or build split APKs per CPU architecture
flutter build apk --split-per-abi \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

The output binary is written to `build/app/outputs/flutter-apk/app-release.apk`.

### 2. Install on Your Android Phone

#### Method A: Direct Install via USB (ADB)
Connect your phone with **USB Debugging** enabled and run:
```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

#### Method B: Wireless / Direct Sideloading
1. Transfer `build/app/outputs/flutter-apk/app-release.apk` to your phone via Google Drive, Telegram, USB, or Nearby Share.
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

Run static analysis and the full automated test suite (162 tests across unit, widget, design-system, UTC, notification, and end-to-end integration suites backed by `MockRepository`):

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
* **Unified Boards Hub:** Horizontal swipe navigation, morphing contextual FAB, COD parcel validation & duplicate-claim prevention, 4-category open tasks (`Ongoing Tasks` / `Completed Tasks`) with dynamic Category + Urgency points and strict `0 pts` self-request guard, `TaskRouletteSheet` wheel spin with zero cooldown, 1-spin-per-task enforcement & `+4 bonus pts`, and 4-tab `Lost & Found` (`My Activity`, `Lost`, `Found`, `Resolved`) lifecycles.
* **CASnap & Casama Connect:** Camera capture & recipient selection, Gallery/Lightbox filtering, Custom Chat Spaces (no join codes), private DMs sorted by latest message with live unread badges, UTC `conversation_reads` cursors, idempotent message retries, Group Chat tiebreaker Wheel Spin, and 4-status Housemates Agenda RSVP/detail sheets.
* **Unified Notifications & Security:** Shared header notification bell & sheet (`parcel_received`, `roulette_chosen` with self-request bonus guard, `housemates_agenda_reminder`), cross-household RLS isolation, and live multi-device synchronization.

---

## 🎬 Live Demo Walkthrough (9 Steps)

1. **Splash & Auth:** Launch Casama to showcase the stepped teal-to-beige wave header, transparent Cas mascot, and Sign Up / Log In flow.
2. **Household Setup:** Create a new household (generating a unique invite code) or join an existing household from a second device.
3. **Live Presence & Casa Schedule:** Toggle **You: Home / Out** with a status note and filter scheduled activities on the Home calendar.
4. **Parcels & COD:** Swipe to **Parcels**, add a COD delivery, toggle availability (triggering a conflict alert if everyone is unavailable), and tap **I Got It** to record receipt and earn **+5 pts**.
5. **Household Tasks & Task Roulette:** Create an open task under one of the 4 categories, tap a task tile to reveal **Spin** and **Mark as Done**, spin **Task Roulette** for an eligible Home housemate (one irreversible spin per task, zero cooldown, **+4 bonus pts**), and complete a housemate's task to earn boosted points.
6. **Lost & Found:** Switch across **My Activity**, **Lost**, **Found**, and **Resolved**, post a missing item, verify a match (**+5 pts**), or claim a standalone found item (**+2 pts**).
7. **CASnap:** Tap the raised center camera button, choose recipients (**Everyone** or specific roommates), snap a photo, and inspect it in the **Gallery / Lightbox**.
8. **Casama Connect:** Send a message or run **Spin Chore Roulette** in Household Group Chat, create a household-wide **Chat Space**, message a housemate directly (sorted by latest message with unread badges), and RSVP or manage an agenda in **Housemates Agenda**.
9. **Profile, Leaderboard & Themes:** Inspect **Good Kasama Points**, upload a profile photo, check unified **Notifications**, and toggle **Light, Dark, and System Default** themes across all screens.

---

## 🔮 Future Enhancements

* Opt-in geofencing with manual presence fallback and explicit permission prompts.
* Offline write queue and automatic conflict-aware synchronization (including offline chat message queuing).
* Push notifications (FCM/APNs) for urgent household alerts, Task Roulette picks, and chat messages.
* Multi-household switching per account and Filipino/English localization.
* Shared grocery/pantry lists and household activity analytics.

---

*Final Project for Application Development — Built with care for better shared living.*
* Jon Paul S. Berana
* Trixter Lanz Donatos
* Vinz Gabriel S. De Castro
