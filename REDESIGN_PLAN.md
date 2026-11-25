# Casama Frontend UI/UX & Motion Redesign Plan

> **Scope & Boundary:** Strictly frontend-only redesign inside `lib/core/`, `lib/shared/widgets/`, `lib/features/`, `pubspec.yaml`, and `test/`.  
> Database schemas, Supabase configuration, `lib/data/models.dart`, `lib/data/casama_repository.dart`, `lib/data/mock_repository.dart`, `lib/data/supabase_repository.dart`, and `lib/data/repository_provider.dart` remain **untouched**.

---

## Source-of-Truth Hierarchy
1. **`docs/casama-app-mockup.html`** — Primary reference for 5-slot shell (`Home`, `Boards`, center raised `CASnap`, `Chat`, `Profile`), slide-over drawer, unified 4-tab swipeable `Boards` hub, morphing FAB, embedded `Task Roulette` sheet, `CASnap` camera/gallery/lightbox, slide-up sheets, and motion physics.
2. **`docs/starting.html`** — Split-tone wave auth/onboarding shell, rounded-top `28dp` surface card, filled inputs, inline terms row.
3. **`docs/core_screens.html`** — Stepped Forest-Teal-to-Warm-Beige wave headers, ambient wave backgrounds, white hairline-bordered cards, `Plus Jakarta Sans` + `Inter` typography scale, status pills, chat threads, and profile layout.

---

## Global Design Rules

### Color System (`CasamaPalette` ThemeExtension)
- **Light Mode:** Warm Cream/Beige scaffold (`#FAF7F2`), Pure White cards/sheets (`#FFFFFF`), Deep Forest Teal headers (`#1E433E` -> `#29534D` -> `#33635C`), Warm Coral primary actions (`#E87461` / `#E87961` / AA `#C44938` ink), Subtle Hairline borders (`#E4DED5`), Soft Sage/Blush semantic chips.
- **Harmonized Nocturnal Dark Mode:** Obsidian Teal scaffold (`#11191D`), Elevated Slate-Teal surfaces (`#1A252B`, cards `#202D34`), Nocturnal Forest headers (`#1D3B36` -> `#264B45` -> `#162A2D`), crisp WCAG AA contrast foregrounds.

### Transparent PNG Mascot Rules (`CasMascotView`)
- All 6 mascot illustrations in `assets/images/cas/` (`migo_chat.png`, `migo_chores.png`, `migo_deliveries.png`, `migo_roulette.png`, `migo_tasks.png`, `together_cards.png`) are **background-free transparent PNGs**.
- **Never** add `.jpg` fallbacks, solid-background clipping boxes, circular frames, borders, or cast drop shadows.
- **Never** draw custom SVG or `CustomPainter` owls—route every mascot through `CasMascotView`.
- Render mascots cleanly blended directly over stepped wave headers, tucked behind opaque white summary cards (Boards/Home) and the Profile avatar rim.

### Centralized Motion Specs (`lib/core/motion/casama_motion.dart`)
- **Tactile press (`CasamaPressable`):** `150ms` scale `0.95` on buttons/tabs/cards, `0.90` on FABs (`enableHaptic` optional).
- **Boards swipe & switcher (`CasamaDirectionalSwitcher`):** `250ms`, `Curves.easeOut`.
- **Morphing contextual Board FAB (`CasamaMorphingFab`):** `320ms` `Cubic(0.34, 1.56, 0.64, 1.0)` enter / `180ms` `Curves.easeIn` exit.
- **Drawer & Bottom Sheets (`showCasamaSheet`):** Drawer `250ms` `Curves.easeOut` left slide; Sheets `280ms` `Curves.easeOut`; Scrim fades `200ms`.
- **Task Roulette Wheel:** `4000ms`, `Cubic(0.12, 0.7, 0.1, 1.0)` multi-turn deceleration landing on `-π/2` top pointer slice alignment (`SharedPreferences` 24h cooldown).
- **CASnap Camera & Gallery:** `450ms` shutter flash fade-out, `350ms` `180°` flip, `200ms` gallery/lightbox Hero transition, `2200ms` dismissible top toast (`showCasamaToast`).
- **Reduced Motion:** Every animated duration/scale resolves cleanly via `CasamaMotion.resolve(context, ...)` honoring `MediaQuery.disableAnimationsOf(context)`.

---

## Complete Screen Inventory (`lib/features/`)

| Feature Screen | Disposition | Notes |
|---|---|---|
| `auth/splash_screen.dart` | **Full Redesign** | Forest Teal wave stage, transparent mascot, 28dp card |
| `auth/auth_screen.dart` | **Full Redesign** | `CasamaAuthShell`, segmented track, inline Terms/Privacy |
| `auth/login_screen.dart`, `register_screen.dart` | **Consolidate** | Thin wrappers forwarding to `AuthScreen` |
| `auth/optional_profile_screen.dart` | **Full Redesign** | `Step 2 of 4` on `CasamaAuthShell`, live initials, `≥48dp` actions |
| `household/household_setup_screen.dart` | **Full Redesign** | `Step 3 of 4`, `CasamaSegmentedTrack` (`Join` / `Create`), validation |
| `onboarding/device_permissions_screen.dart` | **Full Redesign** | `Step 4 of 4`, repo toggle persistence, `fromSettings` pop fix |
| `onboarding/casama_intro_screen.dart` | **Full Redesign** | `CasamaAuthShell` (`CasPose.waving`), Light/Dark benefit rows |
| `onboarding/interactive_tutorial_screen.dart` | **Full Redesign** | Scrollable slides + interactive 5-slot preview bar (`Home`/`Boards`/`CASnap`/`Chat`/`Profile`) |
| `onboarding/tutorial_screen.dart` | **Consolidate** | Thin alias forwarding to `InteractiveTutorialScreen` |
| `dashboard/main_navigation_shell.dart` | **Full Redesign** | 5-slot bottom bar, last-board memory, raised `CASnap`, `CasamaHouseholdDrawer` |
| `dashboard/dashboard_screen.dart` | **Full Redesign** | `CasamaWaveHeader`, `CasamaSplitHero`, `Who's Home`, `Live Attention Needed`, `Shared CASnaps`, `Casa Schedule` |
| `calendar/household_calendar_view.dart` | **Full Redesign** | `CasamaCard`, `CasamaPillFilterRail` (`All`, `Parcels`, `Tasks`, `Bills`, `Meetups`), bills integration |
| `dashboard/boards_screen.dart` | **Full Redesign** | Unified 4-tab swipeable Boards (`Parcels`, `Tasks`, `Bills`, `Items`), peeking summary strip, morphing FAB |
| `parcels/parcels_screen.dart` | **Reskin / Embed** | Works both embedded in `Boards` (`Parcels`) and standalone `/parcels`, slide-up Add Parcel sheet |
| `tasks/maintenance_screen.dart` | **Reskin / Embed** | Works both embedded (`Tasks`) and standalone `/maintenance`, launches embedded Task Roulette sheet |
| `chore_roulette/chore_roulette_screen.dart` | **Consolidate** | Converted into slide-up `TaskRouletteSheet` (w/ standalone `/roulette` wrapper compatibility) |
| `bills/bills_dashboard_screen.dart`, `add_bill_screen.dart`, `bill_detail_screen.dart` | **Reskin / Embed** | Unified `Bills` tab, `EditBillingsSheet` modal + themed detail sheet/view |
| `items/lost_found_screen.dart` | **Reskin / Embed** | Unified `Items` tab + standalone `/lost-found`, slide-up Report Item sheet |
| `quicksnap/quicksnap_camera_screen.dart` | **Full Redesign** | Full-bleed viewfinder, `450ms` shutter flash, `350ms` flip, recipient sheet |
| `quicksnap/quicksnap_home_widget.dart` | **Full Redesign** | `Shared CASnaps` 3×2 thumbnail grid on Home Dashboard |
| `quicksnap/quicksnap_feed_screen.dart`, `quicksnap_image_view.dart` | **Full Redesign** | Filterable gallery + `200ms` Hero lightbox viewer |
| `chat/chat_directory_screen.dart` | **Full Redesign** | `CasamaWaveHeader`, `CasamaSplitHero`, search bar, pinned `Casa 204` card, Custom Spaces, housemates |
| `chat/group_chat_screen.dart`, `chat_space_screen.dart`, `direct_chat_screen.dart` | **Reskin** | Forest Teal header, organic message bubbles, interactive RSVP chips, themed composer (nav bar hidden) |
| `chat/create_meetup_screen.dart`, `household/add_housemate_dialog.dart` | **Consolidate / Sheet** | Converted to consistent slide-up sheets w/ standalone route fallback |
| `profile/profile_screen.dart`, `edit_profile_dialog.dart` | **Full Redesign** | Stepped header, mascot tucked behind coral-ringed avatar, points card, clean info/menu list |
| `points/leaderboard_screen.dart`, `settings/app_settings_screen.dart` | **Reskin** | `CasamaWaveHeader`, `CasamaCard`, WCAG AA Light/Dark parity, `?fromSettings=true` permissions link |
| `legal/terms_consent_screen.dart`, `terms_privacy_screen.dart` | **Reskin** | `CasamaWaveHeader` / `CasamaAuthShell`, tabbed `Terms` / `Privacy` / `Harmony` (`readOnly` support) |

---

## Phased Rollout Checkpoints

- [x] **Phase 1 — Design System, Mascots, Motion & Shared Primitives**
  - Tokenized `CasamaPalette` (Light & Nocturnal Dark Mode), `CasamaTheme`, `CasamaSpacing`, `CasamaMotion`, transparent `CasMascotView`, stepped wave headers, filter pills, and sheet scaffolds.
  - Verified: `flutter analyze` (0 issues), `flutter test` (102/102 passing).

- [x] **Phase 2 — Splash, Onboarding & Auth**
  - Redesigned `SplashScreen`, `AuthScreen` (+ consolidated `LoginScreen`/`RegisterScreen`), `CasamaAuthShell`, `OptionalProfileScreen`, `HouseholdSetupScreen`, `DevicePermissionsScreen`, `CasamaIntroScreen`, and `InteractiveTutorialScreen` (+ consolidated `TutorialScreen`).
  - Verified: `flutter analyze` (0 issues), `flutter test` (106/106 passing).

- [x] **Phase 3 — 5-Slot Shell, Slide-Over Drawer, Home Dashboard & Schedule**
  - Upgrade `MainNavigationShell` (5 slots, last-board memory, raised center `CASnap` trigger, `CasamaPressable` motion), `app_router.dart` (`?tab=` board deep links), and `CasamaHouseholdDrawer` (`250ms` slide + `200ms` scrim, invite code copy, transparent PNG `CasMascotView`).
  - Redesign `DashboardScreen` (`CasamaAmbientCanvas`, `CasamaWaveHeader`, `CasamaSplitHero`, live `Who's Home` toggle & housemate badges, dynamic `Live Attention Needed` routing to Board tabs) and `HouseholdCalendarView` (`Casa Schedule` + `CasamaPillFilterRail` incl. `Bills`).

- [x] **Phase 4 — Unified Boards Hub, Embedded Task Roulette & Slide-Up Action Sheets**
  - Transform `BoardsScreen` into the 4-tab horizontal swipeable hub (`Parcels`, `Tasks`, `Bills`, `Items`) with peeking summary bar, `CasamaMorphingFab`, `AddParcelSheet`, `NewTaskSheet`, `EditBillingsSheet`, `ReportItemSheet`, and physics-based `TaskRouletteSheet` (w/ `SharedPreferences` 24h cooldown).

- [x] **Phase 5 — CASnap Camera, Gallery & Lightbox**
  - Redesign `QuickSnapCameraScreen` (flash & camera flip animations, recipient sheet), `QuickSnapHomeWidget` (3×2 `Shared CASnaps` grid), and `QuickSnapFeedScreen` (`200ms` Hero lightbox).

- [x] **Phase 6 — Chat Hub, Threads & Coordination Sheets**
  - Redesign `ChatDirectoryScreen` (`CasamaSplitHero`, search bar, pinned household card, spaces, housemates) and reskin `GroupChatScreen`, `ChatSpaceScreen`, `DirectChatScreen`, plus `CreateMeetupSheet`, `CreateChatSpaceSheet`, and `InviteHousemateSheet`.

- [x] **Phase 7 — Profile Hub & Secondary Screens**
  - Redesign `ProfileScreen` (tucked mascot behind avatar rim, points card, clean info/actions), and reskin `LeaderboardScreen`, `AppSettingsScreen`, `TermsPrivacyScreen`, `TermsConsentScreen`, `EditProfileDialog`.
  - Final full pass: Light/Dark parity, safe areas, reduced motion, `flutter analyze`, and complete test suite.
