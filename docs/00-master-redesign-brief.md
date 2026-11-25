# Casama — Master UI/UX Redesign Brief

**Document:** `docs/00-master-redesign-brief.md`  
**Synthesized From:**
- [01-design-system-review.md](01-design-system-review.md) — Core constants, theme, and shared widgets (`7/20` Audit · `16/36` Critique · `23` issues)
- [02-core-flow-review.md](02-core-flow-review.md) — Onboarding, Auth, Dashboard, and Household (`6/20` Audit · `17/40` Critique · `26` issues)
- [03-household-features-review.md](03-household-features-review.md) — Maintenance, Chore Roulette, Bills, Calendar, and Parcels (`7/20` Audit · `16/40` Critique · `26` issues)
- [04-social-and-account-review.md](04-social-and-account-review.md) — Chat, Lost & Found, Leaderboard, Profile, Settings, and Legal (`5/20` Audit · `16/40` Critique · `38` issues)

**Total Audited Footprint:** `44` UI/theme Dart files (`11` design-system/shared + `33` feature files, `~18,900` lines) · `113` unique findings (`22 P0`, `48 P1`, `29 P2`, `14 P3`).  
**Design Goal:** Preserve Casama's warm, privacy-first shared-living identity while unifying theming, WCAG 2.1 AA accessibility, navigation architecture, visual density, and functional truthfulness across every Android and iOS screen.

---

## 1. App-Wide Design & UX Patterns

Seven systemic failure patterns recur across all four reviews. Resolving these at the architectural level prevents screen-by-screen regressions during the redesign.

### 1.1 Split-Brain Theming & Systemic Dark Mode Collapse
- **Two conflicting dark surface definitions:** `CasamaTheme.darkTheme` sets `cardTheme.color` to `darkSurface` (`#18263D`), while `CasamaThemeContext` (`context.cardColor`) returns `darkCard` (`#1E2F4A`). Meanwhile, `profile/` and `settings/` (`2,098` lines) make **`0` calls to `context.*`**, inventing rogue dark borders (`#2C3E5A`) and tile fills (`#243650`).
- **Broken Material 3 Dark `TextTheme`:** `CasamaTheme.darkTheme` invokes `GoogleFonts.interTextTheme()` without `ThemeData.dark().textTheme`, leaving 7 of 15 Material 3 text roles stuck in **black ink** on dark dialogs, chips, and menus.
- **Pervasive light-token leakage:** Over `210` static Light Mode `CasamaColors.*` references and `140+` raw `Color(0x...)` hexes leak across feature screens and shared components (`CasamaTextField`, `CasamaButton`, `StatusChip`), causing **`1.00:1`–`1.30:1` invisible text/controls** in Dark Mode across Auth, Dashboard Presence, Add Housemate, Parcels, Maintenance, Chore Roulette, Chat, Lost & Found, Edit Profile, and Settings.

### 1.2 Zero Typography Governance
- Across the entire `lib/` directory, `Theme.of(context).textTheme` has **`0` usages** versus **`508+` inline `TextStyle(...)` declarations** spanning **17 ad-hoc font sizes** (`9pt` to `48pt`).
- Even `app_theme.dart` omits `fontFamily` on 10 `const TextStyle(...)` component declarations, silently falling back to Roboto/SF Pro instead of `Inter`.
- `google_fonts` fetches `Inter` at runtime with zero bundled offline `.ttf` assets, sub-floor `9pt–10pt` labels appear in 18+ places, and currency/dates/points lack tabular numerals (`FontFeature.tabularFigures()`).

### 1.3 Fragmented Navigation, Orphaned Screens & Broken FTUE
- **Non-shell tabs:** `MainNavigationShell` is instantiated separately on 4 routes instead of using GoRouter's `StatefulShellRoute.indexedStack`, desyncing URLs/back stacks, embedding an action (`+`) inside a section tab bar (violating M3 and iOS HIG), and providing zero tablet `NavigationRail`.
- **Disconnected onboarding:** New users are told `"Step 1 of 4"` through `"Step 4 of 4"`, hit **6 more uncounted screens** (`CasamaIntroScreen` + 5-step `InteractiveTutorialScreen`), **completely skip `HouseholdSetupScreen`** (unreachable!), and land in pre-seeded `Casa 204` as ghost members absent from `repo.members`.
- **Orphaned & looping routes:** Four feature files are orphaned or unreachable (`login_screen.dart`, `register_screen.dart`, `tutorial_screen.dart`, `leaderboard_screen.dart`), `SplashScreen` gates returning authenticated users on every launch, and `AppSettingsScreen` → `Application Permissions` hijacks existing users back into `/intro` onboarding.
- **Inconsistent creation CTAs across sibling boards:** `Bills` shows *both* an AppBar `+` and an Extended FAB; `Parcels` shows only an unlabeled AppBar `+`; `Maintenance` and `Lost & Found` pin floating full-width pills over a `Stack` without `SafeArea`; `ChatDirectory` duplicates **6** overlapping create/invite buttons on one screen.

### 1.4 Copy-Paste Component Drift
- **3-way chat duplication (~1,500+ lines):** `GroupChatScreen`, `DirectChatScreen`, and `ChatSpaceScreen` diverge on outgoing bubble color (`midnightNavy` vs `primaryCoral` `2.85:1` FAIL), send button widget/size (`44dp` GestureDetector vs `40dp` IconButton), attachment icon (3 different icons), timestamp format/position (`12h` outside vs `12h` inside vs `24h` inside), and back arrow style.
- **3 duplicate Household Invite modals:** `showInviteHousemateSheet`, `AddHousemateDialog` (Tab 2), and `ProfileScreen._showHouseholdModal` implement three inconsistent versions of the same invite-code flow.
- **Isolated feature dialects:** `bills/` bypasses `CasamaButton`, `CasamaTextField`, `StatusChip`, and Material vector icons (using emojis and `withAlpha`). Across the app, 4 button APIs compete (`CasamaButton`, `ElevatedButton`, `OutlinedButton`, `TextButton`), and raw `CircleAvatar` / `Image.asset` frequently bypass `CasamaAvatar` and `CasMascotView`.

### 1.5 Mockup Shortcuts & Deceptive No-Op Controls
Prototype placeholders shipped as live UI erode user trust across every module:
- **Broken state/math:** Non-Shopee parcels cannot be marked received (`if (isShopee)` gate); Chore Roulette's pointer mismatches the announced winner on **6/6 spins**; Bills `'Total Due'` excludes overdue bills (`₱3,350` shown vs `₱4,649` owed); `CreateMeetupScreen` never updates `repo.activeMeetUp`; seeded Lost & Found `'Message Jon Paul'` dead-ends on `"Unauthorized Conversation"`.
- **Fake / non-persistent actions:** Phone Call dialog, Chat Mute & Clear History, Settings Change Password, Reset Offline Cache, `_shareRoomStatus`, `DevicePermissionsScreen` switches, `HouseholdSetupScreen` submit, and Parcel `'Mark Unavailable'` show fabricated SnackBars or silently discard state.
- **Hardcoded demo artifacts:** `'Casa 204'`, `'November 2026'`, `'4:00 PM'`, `'Today • 7:00 PM'`, fake `'Bathroom'`/`'Kitchen'` task labels, stock Unsplash fallback photos on photo-less Lost & Found posts, pre-filled login credentials, and an exposed `"Backend Engine: High-Fidelity Mock Mode"` card in Settings.

### 1.6 Pervasive Accessibility, Touch-Target & Responsive Deficits
- **Zero assistive-tech instrumentation:** `0` occurrences of `Semantics`, `ExcludeSemantics`, `MergeSemantics`, `MediaQuery.disableAnimationsOf`, or `textScaler` across all 50 Dart files.
- **Sub-minimum touch targets:** Interactive controls shrink to `18–44dp` across every module (inline chat invite taps `18–22dp`, checkboxes/calendar `'Today'`/bill radios `24dp`, task-complete avatar/calendar arrows/parcel actions `32dp`, preset avatars `36dp`, send buttons/Close button `40dp`, `+` button `44dp`).
- **Phone-portrait-only layouts:** `0` responsive breakpoints (`≥600dp` tablet grids/rails or capped form/prose widths); `10+` non-scrollable bottom sheets/onboarding pages overflow in landscape or at `1.3×+` font scale; `DashboardScreen` Presence modal and `AddHousemateDialog` omit `viewInsets.bottom` IME padding; `8+` unwrapped `Row`s overflow horizontally.
- **Hidden modal feedback:** Validation and copy-confirmation `SnackBar`s fire on the root `ScaffoldMessenger` *behind* open bottom sheets across 6+ modals.

### 1.7 Platform Conformance & Runtime Performance Debt
- **Platform polish gaps:** `15+` hardcoded iOS `Icons.arrow_back_ios_new` chevrons on Android, `64+` decorative emojis inside formal headings/buttons/badges, `40+` raw `GestureDetector` taps with no ink ripple or pressed feedback, missing `SafeArea` on pinned CTAs and sheets, and zero haptic feedback.
- **Performance & memory leaks:** Synchronous `base64Decode()` inside `build()`/`ListView.builder` (`CasamaAvatar`, all 3 chat screens, `LostFoundScreen`), unvirtualized eager `ListView` in `GroupChatScreen`, full-screen `setState` at 60–120fps during Roulette spin, `35–42×` redundant event scans per build in `HouseholdCalendarView`, uncached `NetworkImage` without `errorBuilder`/`cacheWidth`, and `13+` undisposed modal `TextEditingController`s.

---

## 2. Global Design System Updates

Enforce these rules inside `lib/core/constants/`, `lib/core/theme/`, and `lib/shared/widgets/` **before** touching individual feature screens. Every color pairing below is mathematically verified against WCAG 2.1 AA (`≥4.5:1` normal text, `≥3.0:1` UI/icons/borders).

### 2.1 Color System & WCAG 2.1 AA Token Rules

1. **Single source of truth:** Migrate `CasamaThemeContext` into `class CasamaColorScheme extends ThemeExtension<CasamaColorScheme>` with `Color.lerp` support so `ThemeData` and `context.*` never diverge and Light↔Dark transitions animate cleanly.
2. **Ban raw hexes & light-only static calls in feature screens:** Zero `Color(0x...)` literals and zero unadapted `CasamaColors.ink` / `softNeutral` / `borderGray` / `textSecondary` in `lib/features/`. Delete rogue dark hexes (`#2C3E5A`, `#243650`) and rename misleading `ivory` (`#BDC4D4`) / deduplicate aliases (`homeGreen` vs `successGreen`).
3. **Honor OS theme by default:** Set `ThemeNotifier` initial state to `ThemeMode.system` and fix `toggleTheme(Brightness currentBrightness)` so toggling from `system` inverts the resolved brightness.

#### Canonical Accessible Palette Contract

| Token Role | Light Hex | Light Contrast (Verified) | Dark Hex | Dark Contrast (Verified) | Usage Rule |
| :--- | :---: | :--- | :---: | :--- | :--- |
| **Brand Primary (Interactive)** | `#C44938` | `4.82:1` white-on-fill · `4.66:1` on cream | `#F08B7B` | `7.22:1` `#0F1A2B`-on-fill · `5.56:1` on `darkCard` | Primary CTAs, active tabs, links (reserve `#E87968` for large decorative fills only) |
| **Brand Secondary (Teal)** | `#3F7772` | `5.13:1` white-on-teal · `4.90:1` on cream | `#5EB5AD` | `5.57:1` on `darkCard` · `6.28:1` on `darkSurface` | Secondary accents, calendar/chat/points highlights |
| **Scaffold Background** | `#FFF8F1` | — | `#0F1A2B` | — | Root page canvas (`scaffoldBackgroundColor`) |
| **Surface (Bars / Sheets)** | `#FFFFFF` | — | `#18263D` | — | AppBars, bottom nav, bottom sheets, dialogs |
| **Card Surface (Elevated)** | `#FFFFFF` | `1.06:1` + `1px` border on cream | `#1E2F4A` | Tonal lift above `#0F1A2B` & `#18263D` | All cards & nested panels inside `#18263D` sheets |
| **Soft Neutral Container** | `#F3F5F4` | — | `#243552` | Distinct from `#18263D` & `#1E2F4A` | Input pills, code boxes, search fields, badges |
| **Primary Text** | `#1C2E4A` | `12.96:1` on cream · `13.64:1` on white | `#F1F5F9` | `15.93:1` on bg · `12.28:1` on `darkCard` | Headings, titles, input text |
| **Secondary Text** | `#54646C` | `5.95:1` on cream · `6.26:1` on white | `#A0AEC0` | `5.97:1` on `darkCard` · `6.73:1` on `darkSurface` | Subtitles, metadata, timestamps |
| **Muted / Hint Text** | `#5E6E76` | `5.03:1` on cream · `4.83:1` on soft neutral | `#8E9EB3` | `4.93:1` on `darkCard` | Input placeholders, captions (replaces failing `#9EABB2` / `#64748B`) |
| **Decorative Border / Divider** | `#DCE3E0` | Subtle separation only | `#2C4164` | Subtle separation only | Card outlines & horizontal dividers only |
| **Interactive Input Border** | `#7F8E96` | `3.21:1` on cream · `3.38:1` on white (1.4.11 PASS) | `#6C85AC` | `3.58:1` on `darkCard` (1.4.11 PASS) | Unfocused text fields, checkboxes, outlined buttons |
| **Outgoing Chat Bubble** | `#1C2E4A` | `13.64:1` white-on-fill | `#265652` (or `#284166`) | `8.28:1` (`10.30:1`) white-on-fill | Unified across Group, Direct, and Space chats |
| **Chip: Success (`Home`/`Paid`)** | `#2E7D32` on `#E8F5E9` | `4.56:1` | `#81C784` on `#1B3626` | `6.51:1` | Always pair with semantic icon |
| **Chip: Neutral (`Out`)** | `#595959` on `#EEEEEE` | `6.04:1` | `#CBD5E1` on `#2A3548` | `8.31:1` | Replaces failing `#757575` |
| **Chip: Brand / COD** | `#BF4433` on `#FFECE8` | `4.50:1` | `#F59888` on `#3D2224` | `6.70:1` | Replaces failing `#E87968` on `#FFECE8` (`2.50:1`) |
| **Chip: Danger / Overdue / Error** | `#C62828` on `#FFEBEE` | `4.92:1` (`5.62:1` on white) | `#F28B82` on `#3D1F25` | `6.65:1` (`5.63:1` on `darkCard`) | Destructive buttons, errors, overdue/urgent tags |
| **Chip: Warning / Medium** | `#B54708` on `#FFF3E0` | `4.95:1` | `#FFB74D` on `#3B2B17` | `7.86:1` | Replaces failing `#E65100` / `#F57C00` |
| **Chip: Info (`To Buy`)** | `#1565C0` on `#E3F2FD` | `5.03:1` | `#90CAF9` on `#1B2E45` | `7.88:1` | Replaces failing `#1976D2` |
| **Chip: Amber (`Found`/`Unclaimed`)** | `#8D5500` on `#FFF8E1` | `5.76:1` | `#FFD54F` on `#3A3016` | `9.22:1` | Replaces failing `#F57F17` (`2.49:1`) & `#F4B544` |

### 2.2 Typography Rules
- **Fix dark baseline immediately:** Initialize `darkTheme` from `GoogleFonts.interTextTheme(ThemeData.dark().textTheme)` and configure **all 15 Material 3 roles** using `Inter`, explicit line heights (`1.2–1.5`), and theme text colors.
- **Bundle fonts & cache themes:** Bundle `Inter` (`Regular`, `Medium`, `SemiBold`, `Bold`) in `assets/fonts/` + `pubspec.yaml`, disable runtime font fetching in production, and store `lightTheme` / `darkTheme` as `static final ThemeData` (not rebuilding getters).
- **Enforce 7 core roles (ban raw `TextStyle` sizes):** Map all screens to `Theme.of(context).textTheme` (`headlineMedium 24`, `titleLarge 20`, `titleMedium 16`, `bodyLarge 15`, `bodyMedium 14`, `labelLarge 14`, `labelMedium 12`, `labelSmall 11`).
- **Hard `11sp` floor:** Zero `9pt` or `10pt` text anywhere (including badges, timestamps, and status chips).
- **Tabular numerals:** Expose a shared helper applying `fontFeatures: [FontFeature.tabularFigures()]` to all currency (`₱`), dates, timestamps, unread counts, and Good Kasama points.
- **Readable measure:** Constrain long-form text (`TermsPrivacyScreen`) and single-column forms/settings to `600–680dp` max width on tablets/landscape.

### 2.3 Spacing, Radii & Responsive Grid Rules
- **4pt base / 8pt rhythm (`CasamaSpacing`):** Enforce `xxs: 4`, `xs: 8`, `sm: 12`, `md: 16`, `lg: 20`, `xl: 24`, `xxl: 32`, `huge: 40` across all widgets and screens (eliminate ad-hoc `6px`, `10px`, `14px`, `18px` gaps).
- **Canonical radii:** `8dp` chips/small badges · `12dp` inputs & standard buttons · `16dp` cards · `24dp` modal bottom sheets & dialogs · `999dp` pill buttons/chips.
- **Responsive breakpoints (`CasamaBreakpoints`):**
  - `compact < 360dp`: stack dual button rows via `Wrap`, enable scrollable tabs, scale wheel/hero sizes via `LayoutBuilder`.
  - `standard 360–599dp`: single-column list, `16dp` horizontal page margin, M3 `NavigationBar`.
  - `medium 600–839dp` & `expanded ≥ 840dp`: switch shell to M3 `NavigationRail`, render 2-column `GridView` on `Boards`, `Bills`, `Parcels`, `Maintenance`, and `Lost & Found`, use 2-pane layout on `ChoreRoulette`, and center forms/details in `ConstrainedBox(maxWidth: 600)`.
- **Safe-area & IME contract:** Every screen with bottom CTAs must wrap in `SafeArea`; every modal bottom sheet must set `isScrollControlled: true`, wrap in `SafeArea` + `SingleChildScrollView`, pad by `MediaQuery.viewInsetsOf(context).bottom`, and cap height at `85%` viewport height (`maxWidth: 560` on tablets).

### 2.4 Cards, Modals, Navigation & Iconography Rules
- **Standard Card Anatomy:** Flat elevation (`0`), `16dp` border radius, `1px` `context.borderColor`, `16dp` internal padding, `12dp` vertical gap between list cards. Limit list cards to **3 scannable tiers max**: (1) Header (Title + Status Chip), (2) Context line (Owner/Assignee + Due/Time), (3) Explicit Action row (`≥48dp` CTA).
- **Modal Feedback Rule:** Never trigger root `ScaffoldMessenger.showSnackBar` while a modal bottom sheet is open. Use inline `FormField` `errorText` for validation and in-sheet state changes (e.g., button label `"Copied!"` with check icon) for confirmations.
- **Unified Board Creation Pattern:** Every operational board (`Parcels`, `Maintenance`, `Bills`, `Lost & Found`) uses **one** M3 `FloatingActionButton.extended` (inside `Scaffold.floatingActionButton` for automatic `SafeArea` clearance). Remove duplicate AppBar `+` buttons and `Stack`/`Positioned` floating pills.
- **Unified Shell Navigation:** Migrate `app_router.dart` to `StatefulShellRoute.indexedStack` with **4 top-level tabs** (`Home`, `Boards`, `Chat`, `Profile`) inside native M3 `NavigationBar` (`<600dp`) / `NavigationRail` (`≥600dp`), moving Quick Actions out of the tab bar into a labeled FAB (`≤4` choices).
- **Platform Native Chrome:** Delete all `15+` hardcoded `Icons.arrow_back_ios_new` overrides so Flutter's adaptive `BackButton()` renders native arrows per OS. Replace all `64+` decorative UI emojis in headings/badges/buttons with Material rounded vector icons. Enable M3 `showDragHandle: true` on bottom sheets and configure full `dialogTheme`, `bottomSheetTheme`, `snackBarTheme`, `chipTheme`, `dividerTheme`, and `tabBarTheme` in `CasamaTheme`.

### 2.5 Buttons, Inputs & Shared Widget Contracts
- **`CasamaButton`:** Refactor onto styled Material 3 `FilledButton` / `OutlinedButton` / `TextButton` (retaining semantic variants: `primary`, `secondary`, `tonal`, `ghost`, `destructive`). Replace fixed `height` with `constraints: BoxConstraints(minHeight: 48)` + vertical padding; wrap labels in `Flexible(maxLines: 2)`; fix dropped `side` border on `isPill: true`; dim disabled `ghost` foreground; announce loading state via `Semantics(label: '$label, loading')`; honor `MediaQuery.disableAnimationsOf(context)`.
- **`CasamaTextField`:** Consume `context.textColor`, `context.textSecondaryColor`, `context.cardColor`, and interactive `inputBorder` (`≥3.0:1`); define `focusedErrorBorder` and `disabledBorder`; semantically bind label to field; add built-in password visibility toggle (`IconButton` with tooltip), `textInputAction`, `focusNode`, `onFieldSubmitted`, `autofillHints`, `inputFormatters`, `helperText`, `errorMaxLines: 2`, and `enabled`.
- **`StatusChip`:** Generalize to 6 theme-aware semantic roles (`success`, `neutral`, `brand`, `danger`, `warning`, `info`) with default leading icons, `≥11sp` label, `Flexible`/`TextOverflow.ellipsis`, and domain mappers living inside feature modules.
- **`CasamaAvatar` & `AvatarChip`:** Cache decoded base64 `Uint8List` outside `build()`, set `cacheWidth`/`cacheHeight` and `loadingBuilder` on network images, clamp fallback initial scaling, wrap tappable avatars in `InkResponse` + `Semantics(button: true)` padded to `≥48×48dp`, and make `AvatarChip` label/border colors configurable (defaulting to theme tokens, not hardcoded white).
- **Shared Chat Primitives (New):** Create `CasamaChatBubble`, `CasamaChatComposer`, and `CasamaSpaceInviteCard` in `lib/shared/widgets/` (with cached `Uint8List` photo rendering, unified `12h` timestamps, `48×48dp` send/attach/invite actions, and `CasamaAvatar`) consumed by all 3 chat screens.
- **Universal Touch Target & Interaction Floor:** Every tappable element must be **`≥48×48dp`** (zero `minimumSize: Size.zero`, zero `32dp` button constraints, zero `24dp` standalone checkboxes—use `CheckboxListTile`/`RadioListTile`/`FilterChip`/`SegmentedButton`/`InkWell` with `Semantics` and subtle `HapticFeedback.selectionClick()`).

---

## 3. Mascot Placement Map (`CasMascotView`)

*(Placement rules only—uses existing ready-made `CasMascotView` / `CasPose` assets. Ensure `CasMascotView` defaults to `excludeFromSemantics: true` for decorative slots, uses theme-aware fallback surfaces, and serves as the sole wrapper instead of raw `Image.asset` calls.)*

### (a) Where Mascot Assets Are Currently Placed

#### Active `CasMascotView` Placements (10 call sites across 7 files)

| File & Line | `CasPose` Slot | Current Context / State | Redesign Action |
| :--- | :--- | :--- | :--- |
| `lib/features/household/household_setup_screen.dart:81` | `CasPose.waving` (`130×130`) | Join Household tab header | **Keep** (once screen is wired into active FTUE) |
| `lib/features/household/household_setup_screen.dart:143` | `CasPose.hero` (`130×130`) | Create Household tab header | **Keep** |
| `lib/features/parcels/parcels_screen.dart:105` | `CasPose.deliveries` (`140×140`) | Empty state (*No expected deliveries*) | **Keep** (pair with inline `"Add Parcel"` CTA) |
| `lib/features/parcels/parcels_screen.dart:581` | `CasPose.jumping` (`120×120`) | Parcel received points celebration dialog | **Keep** |
| `lib/features/tasks/maintenance_screen.dart:123` | `CasPose.tasks` (`140×140`) | Empty state (*All tasks are clear!*) | **Keep** (pair with inline `"Add Task"` CTA) |
| `lib/features/tasks/maintenance_screen.dart:493` | `CasPose.tasks` (`120×120`) | Task completed points celebration dialog | **Keep** (consider `CasPose.jumping` for celebration consistency) |
| `lib/features/chore_roulette/chore_roulette_screen.dart:140` | `CasPose.roulette` (`130×130`) | Spin result winner modal dialog | **Keep** |
| `lib/features/items/lost_found_screen.dart:120` | `CasPose.together` (`140×140`) | Empty state (*No items reported yet*) | **Keep** (pair with inline `"Post Item"` CTA) |
| `lib/features/points/leaderboard_screen.dart:76` | `CasPose.jumping` (`85×85`) | Monthly leaderboard hero banner | **Keep** (ensure clean contrast/surface framing on dark/navy hero) |
| `lib/features/profile/profile_screen.dart:658` | `CasPose.hero` (`100×100`) | `'About Casama'` modal sheet | **Move** into Settings `'About Casama'` (remove duplicate modal from Profile) |

#### Raw `Image.asset('assets/images/cas/...')` Bypasses (5 additional files)

| File & Lines | Raw Asset Used | Current Context / State | Redesign Action |
| :--- | :--- | :--- | :--- |
| `lib/features/auth/splash_screen.dart:84` | `cas_hero.png` | Welcome hero (below `casama_logo.png`) | **Migrate** to `CasMascotView(pose: CasPose.hero)` |
| `lib/features/onboarding/casama_intro_screen.dart:51` | `cas_waving.png` | Intro welcome header | **Migrate** to `CasMascotView(pose: CasPose.waving)` |
| `lib/features/onboarding/interactive_tutorial_screen.dart:28,38,47,56,66` | `cas_hero`, `cas_deliveries`, `cas_roulette`, `cas_together`, `cas_jumping` | 5 onboarding tour slides | **Migrate** all slides to `CasMascotView` |
| `lib/features/onboarding/tutorial_screen.dart:21,27,33` | `cas_waving`, `cas_deliveries`, `cas_tasks` | Legacy onboarding slides | **Retire** (delete orphaned file) |
| `lib/features/chat/create_meetup_screen.dart:69` | `cas_together.png` | Top of Create Meet-up form | **Remove** (utility creation form—keep forms clean and compact) |

*(Unused enum slots currently: `CasPose.standing`, `CasPose.chatting`.)*

---

### (b) Screens & States That SHOULD Display `CasMascotView`

Reserve `CasMascotView` strictly for **emotional bookends**—welcome moments, zero-data empty states, and reward celebrations—so it adds warmth without crowding daily workflows.

| Category | Screen / State | Suggested `CasPose` Slot | Recommended Size |
| :--- | :--- | :--- | :--- |
| **Onboarding & First-Run** | `SplashScreen` (new/logged-out users only) | `CasPose.hero` | `140–160dp` |
| **Onboarding & First-Run** | `CasamaIntroScreen` / Unified Welcome Tour slides | `CasPose.waving`, `deliveries`, `roulette`, `together`, `jumping` | `120–140dp` (scrollable container) |
| **Onboarding & First-Run** | `HouseholdSetupScreen` (Join & Create tabs) | `CasPose.waving` (Join) · `CasPose.hero` (Create) | `110–130dp` |
| **Empty States** | `ParcelsScreen` — 0 expected / received deliveries | `CasPose.deliveries` | `120–140dp` |
| **Empty States** | `MaintenanceScreen` — 0 tasks in active tab | `CasPose.tasks` | `120–140dp` |
| **Empty States** | `LostFoundScreen` — 0 reported items in tab | `CasPose.together` | `120–140dp` |
| **Empty States** | `BillsDashboardScreen` — 0 bills in household *(new slot)* | `CasPose.standing` (or `CasPose.hero`) | `120–140dp` |
| **Empty States** | `ChatDirectoryScreen` — 0 housemates / 0 spaces *(new slot)* | `CasPose.chatting` | `110–130dp` |
| **Empty States** | `DirectChatScreen` / `ChatSpaceScreen` — brand-new empty thread *(new slot)* | `CasPose.chatting` | `110–120dp` |
| **Empty States** | `HouseholdCalendarView` — 0 activities for selected day *(optional compact)* | `CasPose.standing` | `72–88dp` |
| **Celebrations & Rewards** | `ParcelsScreen` — Parcel received (`+5 pts`) dialog | `CasPose.jumping` | `110–120dp` |
| **Celebrations & Rewards** | `MaintenanceScreen` — Task completed (`+10 pts`) dialog | `CasPose.jumping` (or `CasPose.tasks`) | `110–120dp` |
| **Celebrations & Rewards** | `BillDetailScreen` — Bill marked paid (`+5 pts`) confirmation *(new slot)* | `CasPose.jumping` | `100–120dp` |
| **Celebrations & Rewards** | `ChoreRouletteScreen` — Winner reveal dialog | `CasPose.roulette` | `120–130dp` |
| **Celebrations & Rewards** | `LeaderboardScreen` — Monthly Points hero banner | `CasPose.jumping` | `76–88dp` |
| **Brand Info** | `AppSettingsScreen` → `'About Casama'` dialog | `CasPose.hero` | `88–100dp` |

---

### (c) Screens & States That SHOULD NOT Include `CasMascotView`

Keep all high-frequency operational views, dense data lists, creation forms, messaging threads, and legal/account tools completely mascot-free so content starts immediately above the fold:

- **All Creation & Editing Forms:**
  - `CreateMeetupScreen` (**remove** existing `L69` mascot image), `AddBillScreen` (**also remove** its 190dp decorative receipt graphic), `AuthScreen` (Login/Register), `OptionalProfileScreen`, `EditProfileDialog`, `AddHousemateDialog`, `showInviteHousemateSheet`, Change Password modal, and Add Parcel / Add Task / Post Item / Create Space / Join Space bottom sheets.
- **Populated Daily Dashboards & Lists:**
  - `DashboardScreen` (Presence hero + Calendar + Today's Attention), `BoardsScreen` (5 module cards), `BillsDashboardScreen` (when bills exist), `BillDetailScreen` (financial ledger), `ParcelsScreen` / `MaintenanceScreen` / `LostFoundScreen` (when items exist), `ChoreRouletteScreen` (main wheel view—keep mascot strictly inside the post-spin result dialog), and `Notifications` bottom sheet.
- **Active Messaging & Coordination Threads:**
  - `ChatDirectoryScreen` (populated directory), `GroupChatScreen`, `DirectChatScreen` (active thread & unauthorized state), `ChatSpaceScreen` (active thread & Space Info sheet).
- **Account, Preferences & Legal Compliance:**
  - `ProfileScreen` (main scroll & Points Audit Ledger), `AppSettingsScreen` (main list), `DevicePermissionsScreen`, `TermsConsentScreen`, `TermsPrivacyScreen`.

---

## 4. Screen-by-Screen Priority Fixes

Concise visual and UX redesign checklists across all **33 feature files** (grouped by flow). Apply Section 2 global tokens and components throughout.

### A. Auth & Onboarding (`lib/features/auth/`, `lib/features/onboarding/`)

- **`auth/splash_screen.dart`**
  - Auto-redirect authenticated returning users straight to `/dashboard` via GoRouter `redirect` (stop gating cold starts).
  - Remove duplicate `"Casama"` heading below `casama_logo.png` (or use icon-only mark + single wordmark); keep decorative bottom wave clear of CTA hit targets.
  - Replace raw `Image.asset` with `CasMascotView` and apply AA-compliant primary/ghost button styles.
- **`auth/auth_screen.dart`**
  - Fix Dark Mode headings (`1.28:1` → `context.textColor`) and theme the Forgot Password dialog properly.
  - Clear pre-filled demo email/password from inputs (rely on the dedicated Demo Login button); tighten email validation and replace raw `e.toString()` errors with plain-language copy.
  - Fix Forgot Password so invalid/failed resets never show fake green success; raise `"Forgot password?"` to `≥48dp`; cap form width at `600dp` on tablets; remove hardcoded iOS back arrow and heading emojis.
- **`auth/login_screen.dart` & `auth/register_screen.dart` *(RETIRE)***
  - Delete both orphaned legacy files (redirect `/login` → `/auth?tab=login` and `/register` → `/auth?tab=register` in `app_router.dart`) to eliminate double-entry signup loops.
- **`auth/optional_profile_screen.dart`**
  - Wire `onTap` on `CasamaAvatar` (fixes dead camera edit badge) and refresh fallback initials live as Full Name changes.
  - Keep a single Skip action (AppBar top-right); wrap `"Take Photo"`/`"Gallery"` in `Wrap` to prevent horizontal overflow; raise preset avatars to `≥48dp` hit targets; validate `Age` (`1–120`).
- **`onboarding/device_permissions_screen.dart`**
  - Add `isOnboarding` route mode: when opened from Settings, hide `"Step 4 of 4"` and pop back to `/settings` instead of hijacking to `/intro`.
  - Replace non-persistent fake switches with real persisted notification prefs and just-in-time OS permission requests (or align honestly with `TermsPrivacyScreen`).
  - Remove duplicate Skip button, hardcoded `"CASA204"` copy, `10pt` badge, Dark Mode `1.93:1` icon contrast, and hardcoded iOS back arrow.
- **`onboarding/casama_intro_screen.dart`**
  - Align onboarding step counter with reality (collapse FTUE to 4 honest steps ending in `HouseholdSetupScreen` instead of 10 screens).
  - Remove duplicate Skip button, migrate raw mascot image to `CasMascotView`, and fix Dark Mode pastel icon circles (`1.71:1` gold icon).
- **`onboarding/interactive_tutorial_screen.dart`**
  - Wrap slide content in `SingleChildScrollView` + `SafeArea` (fixes landscape/font-scale overflow) and migrate raw assets to `CasMascotView`.
  - Fix inaccurate copy (5 boards, not 3; align `+` description with actual Quick Actions; remove `"Casa 204"` and `"Next Navigation Element"` jargon) and make the mock nav bar actually interactive (tap tabs to jump slides).
  - Fix Dark Mode `tileParcels` pill contrast (`2.50:1`), `10pt` labels, and iOS back arrow.
- **`onboarding/tutorial_screen.dart` *(RETIRE)***
  - Delete orphaned legacy file after wiring `HouseholdSetupScreen` directly into the active onboarding chain.

### B. Dashboard & Household (`lib/features/dashboard/`, `lib/features/household/`)

- **`dashboard/main_navigation_shell.dart`**
  - Refactor `app_router.dart` to `StatefulShellRoute.indexedStack` with 4 destinations (`Home`, `Boards`, `Chat`, `Profile`) rendered via M3 `NavigationBar` (`<600dp`) and `NavigationRail` (`≥600dp`).
  - Move `+` Quick Actions out of the tab bar into a standard `56dp` M3 FAB with `tooltip` & `Semantics`; trim Quick Actions sheet to `≤4` items, use dark-aware tile circles, and interpolate `repo.currentHousehold.name` instead of `"Casa 204"`.
  - Fix tab label/icon contrast (`2.35:1`/`2.85:1` → `≥4.5:1`) and raise `9pt` tags/badges to `≥11sp`.
- **`dashboard/dashboard_screen.dart`**
  - Default `HouseholdCalendarView` to compact Week View and surface a **"Needs Attention Today"** summary strip (expected COD parcels, urgent tasks, overdue bills) above the fold.
  - Make Presence modal `isScrollControlled: true` + `SingleChildScrollView` + `viewInsets.bottom` (fixes keyboard occlusion) and fix Dark Mode `"I'm Home"` / `"I'm Out"` selected button contrast (`1.12:1` / `1.16:1`).
  - Make Presence `AvatarChip` row horizontally scrollable (fixes 5+ member overflow), wrap greeting in `Expanded`, back Notifications sheet with real repository events + `SafeArea` + `SingleChildScrollView`, and stop clearing unread dots before the user reads them.
- **`dashboard/boards_screen.dart`**
  - Watch `repositoryProvider` and show live status/urgency badges on each of the 5 board cards (e.g., `"1 overdue"`, `"1 urgent"`, `"2 expected"`).
  - Fix icon contrast in Light (`2.47:1` Bills) and Dark (`2.66:1` Lost & Found) modes using theme tokens, and switch to a 2-column `GridView` at `≥600dp`.
- **`household/household_setup_screen.dart`**
  - Wire directly into active onboarding (Step 3 of 4) and ensure `MockRepository.register()` + `joinHousehold()` / `createHousehold()` add the new user to `repo.members` (no ghost users).
  - Add real `Form` validation, restore back navigation when pushed, display generated invite code after creation, and fix Dark Mode `CasamaTextField` + `CasamaButton.navy` (`1.01:1`).
- **`household/add_housemate_dialog.dart` *(merge with `invite_housemate_sheet.dart`)***
  - Consolidate into **one** canonical household-invite/manage bottom sheet (retiring duplicate sheets in `shared/widgets/` and `ProfileScreen`).
  - Replace all 29 static light tokens breaking Dark Mode (`1.11:1`), respect `viewInsets.bottom`, replace hidden root SnackBars with in-sheet confirmation banners, reuse `CasamaAvatar`, raise `'Invite'` button to `≥48dp`, and change outbound pending invites from Accept/Decline to **Cancel / Resend**.

### C. Household Operations (`lib/features/tasks/`, `chore_roulette/`, `bills/`, `calendar/`, `parcels/`)

- **`tasks/maintenance_screen.dart`**
  - Replace hidden `32×32dp` avatar-tap completion with an explicit `48×48dp` status checkbox/button (`Open` → `In Progress` → `Done`), add a Task Detail sheet (edit/reassign/delete) + completion `Undo`, and populate assignees dynamically from `repo.members`.
  - Replace fake hardcoded `'Bathroom'`/`'Kitchen'` labels with real category, assignee name, and due date; fix Dark Mode category icons (`1.18–1.66:1`), modal `'Add Task'` button (`1.11:1`), and white celebration dialog.
  - Replace pinned `Positioned` CTA (no `SafeArea`) with M3 `FloatingActionButton.extended`; make 4-tab `TabBar` scrollable with live counts; use inline modal validation (no hidden SnackBar); add `"Add Task"` CTA to empty state; reuse `CasamaAvatar` and dispose modal controller.
- **`chore_roulette/chore_roulette_screen.dart`**
  - Fix wheel landing angle trigonometry so the 12 o'clock pointer matches the announced winner on **100% of spins** (add unit test across all 6 slices).
  - Add readable chore labels or a compact chip legend (replacing icon-only slices where 5/6 fail `3.0:1` contrast), fix Dark Mode pointer & active toggle (`1.01:1`), rename `"Random Dormmate"` → `"Random Housemate"`, and add a `"Home only"` filter + chore customization.
  - Wrap body in `SingleChildScrollView` + responsive `LayoutBuilder` wheel sizing (2-pane on landscape/tablet), isolate rotation in `AnimatedBuilder` (no full-screen `setState`), honor `MediaQuery.disableAnimationsOf(context)`, replace custom toggle with `SegmentedButton` (`≥48dp`), and remove hardcoded iOS back arrow.
- **`bills/bills_dashboard_screen.dart`**
  - Include `BillStatus.overdue` inside `'Unpaid'` count and `'Total Due'` (`b.effectiveStatus != BillStatus.paid`) so overdue bills are never omitted from household totals.
  - Condense ~340dp of header chrome into a compact tappable summary strip + primary status chips (`All`, `Overdue`, `Unpaid`, `Paid`) + populated category filter; remove duplicate AppBar `+` (keep Extended FAB only).
  - Fix failing AA contrast on all stat numbers, status badges, and dark reminder text (`2.47–4.36:1`), migrate to `StatusChip` + Material rounded category icons + tabular numerals, fix `_BillCard` bottom-row overflow, add `"Add Bill"` / `"Clear Filter"` empty-state CTAs, and add a 2-column tablet grid.
- **`bills/add_bill_screen.dart`**
  - Remove the ~190dp decorative receipt hero so fields start immediately above the fold; remove (or confirm-guard) the destructive AppBar Home button.
  - Wire `_formKey.currentState!.validate()` with real validators; replace cramped 5-column category `Row` with `Wrap`/3-col grid; replace `24dp` custom `GestureDetector` radios with `RadioListTile`; migrate to `CasamaTextField`/`CasamaButton` + Material icons; cap form width at `600dp`.
- **`bills/bill_detail_screen.dart`**
  - Add `'Edit Bill'` action reusing `AddBillScreen(initialBill: bill)`.
  - Fix AA contrast on Amount (`2.85:1`), `'Mark as Paid'` (`4.12:1`), `'Reopen Bill'` (`2.57:1`), and Dark Mode badges/dialogs; replace raw `Colors.red` with `colorScheme.error`; apply tabular numerals; cap width at `600dp`.
- **`calendar/household_calendar_view.dart`**
  - Include `repo.bills` deadlines in calendar events & filters; render up to 3 color-coded category dots per date; format real parcel arrival times (`DateFormat.jm()`, eliminating hardcoded `'4:00 PM'` and mixed 12h/24h clocks).
  - Pre-index monthly events once per build (`O(1)` lookup instead of `35–42×` scans); wrap `_buildWeekStrip` cells in `Expanded`; raise `'Today'` (`24dp`), pills (`26dp`), arrows (`32dp`), and day cells to `≥44–48dp`; use `InkWell` deep-linking directly to tapped items; add `"Schedule Activity"` empty-state CTA; fix out-of-month (`1.37:1`) and dark meetup icon (`2.91:1`) contrast.
- **`parcels/parcels_screen.dart`**
  - Remove `if (isShopee)` branching: give **every** expected parcel both a real `'I Got It'` receive button and a real persisted `'Can't Receive'` availability toggle (`≥48dp`), plus a conflict warning chip when nobody is available.
  - Display `parcel.buyerName` prominently on `_ParcelCard` and label the `[Y][A][R]` availability circles (`"Can receive:"`); unify peso decimal formatting (`toStringAsFixed(2)` + tabular numerals).
  - Fix Dark Mode invisibility (`1.01–1.16:1` Lazada/Other titles, `'Mark Unavailable'`, ChoiceChips, white dialog); switch Add Parcel modal to a `StatefulWidget` disposing controllers, starting COD empty with `Form` validation and `SegmentedButton`; standardize creation CTA to M3 Extended FAB + inline empty-state CTA.

### D. Social & Communication (`lib/features/chat/`, `lib/features/items/`)

- **`chat/chat_directory_screen.dart`**
  - Collapse **6 competing create/invite triggers** into a clean single creation flow (e.g., 1 AppBar `+` menu or clean single trailing action per section) to eliminate Section 2 horizontal header overflow.
  - Fix Dark Mode empty-state contrast (`CasamaColors.ink` on `darkCard` = `1.01:1`), Join Code modal (`#FFECE8` + non-scrollable), dark meetup icon (`2.91:1`), `10pt` pills, `<48dp` `'View'`/`Join Code`/`+ Space` targets, hidden validation SnackBar, and undisposed modal controllers.
  - Pass member UUIDs for DM routing so newly added housemates authorize reliably.
- **`chat/group_chat_screen.dart`, `chat/direct_chat_screen.dart`, `chat/chat_space_screen.dart` *(UNIFY)***
  - Refactor all 3 screens onto shared `CasamaChatBubble`, `CasamaChatComposer`, and `CasamaSpaceInviteCard` primitives (eliminating ~1,500 lines of drift): unified outgoing bubble contrast (`≥4.5:1`, replacing `2.85:1` coral DM & `1.11:1` navy-on-dark send buttons), unified attachment icon, `≥48×48dp` send & inline invite actions, `12h` (`h:mm a`) timestamps, adaptive `BackButton()`, and `CasamaAvatar` (fixing `1.30:1` white-on-`borderGray` initials).
  - Cache `base64Decode` bytes outside `build()` with `cacheWidth` + `errorBuilder`, and virtualize `GroupChatScreen` with `ListView.builder`.
  - **Group Chat:** Fix Dark Mode Meet-up card (`1.01:1` title, hardcoded `'Today • 7:00 PM'`), Dark Mode selected RSVP buttons (`1.06:1`/`1.12:1`), and non-scrollable RSVP / Members sheets.
  - **Direct Chat:** Wire Mute/Clear History to real repository state or remove unimplemented stubs alongside the fake Phone Call dialog.
  - **Chat Space:** Wrap Space Info sheet in `SafeArea` + `SingleChildScrollView`, fix `darkSurface`-on-`darkSurface` (`1.00:1`) code box, `1.11:1` dark Add button, and hidden copy/add SnackBars.
- **`chat/create_meetup_screen.dart`**
  - Wire `'Send Invitation'` to a real `repo.createMeetUp(...)` method updating `activeMeetUp` (not just a raw text chat line).
  - Clear pre-filled demo strings (use hints), add `Form` validation, replace free-text Time with native `showDatePicker`/`showTimePicker`, make Invitees selectable in a scrollable `Wrap`/`Row`, **remove** raw `cas_together.png` mascot from this form, and use adaptive `BackButton()`.
- **`items/lost_found_screen.dart`**
  - Fix **`"Message <Name>"` dead-end** by passing `item.reportedBy` UUID, and hide `'Message'` (offer `'Edit / Delete'`) on the current user's own posts.
  - Remove stock Unsplash fallback photos when posting without an image (render a clean category icon placeholder instead); replace hardcoded `'Casa 204 Housemate'` with `repo.currentHousehold.name`; format relative ages cleanly (`Just now`, `3h ago`, `2d ago`).
  - Fix Dark Mode ChoiceChips (`1.11:1` / `2.49:1`), wrap `Camera`/`Gallery` buttons in `Wrap`, make Item Details sheet scrollable + `SafeArea`, move creation CTA to M3 Extended FAB, cache `base64Decode` bytes, dispose modal controllers, and remove `findAncestorStateOfType` coupling.

### E. Account, Points & Legal (`lib/features/points/`, `profile/`, `settings/`, `legal/`)

- **`points/leaderboard_screen.dart`**
  - Wire navigation entry points from `ProfileScreen`'s Good Kasama Points card (and/or Dashboard) so `/leaderboard` is no longer orphaned.
  - Replace hardcoded 4-person static array and `'November 2026'` with live sorted `repo.members` data, dynamic month header, Monthly/All-time `SegmentedButton`, tabular numerals, and `CasamaAvatar` (replacing unguarded `NetworkImage`).
  - Sync `'How to Earn Points'` with `+5 pts` bill payment, fix `2.85:1` coral points and `1.28:1` dark hero card border, and use adaptive `BackButton()`.
- **`profile/profile_screen.dart`**
  - Migrate off manual `isDark`/`Theme.of(context).cardColor`/`#2C3E5A` onto `CasamaThemeContext`, fixing 10+ `2.95:1` dark labels, `1.97:1` gold star, `2.50:1` `'Gold Tier'` (`10pt`), and `2.96:1` teal link.
  - Cut clutter: keep **1** Edit Profile button, **1** Settings gear icon, delegate Household Invite to the single consolidated sheet (deleting `_showHouseholdModal`), remove duplicate `'About Casama'` modal, and link to `/leaderboard`.
  - Add destructive confirmation dialog to `'Log Out'` (matching Settings) using `colorScheme.error`, fix double top safe-area padding (`top: 50` + `SafeArea`), wrap `_InfoRow` values safely, and fix `'Privacy & Permissions'` route.
- **`profile/edit_profile_dialog.dart`**
  - Migrate to `CasamaThemeContext` + fixed Dark Mode `CasamaTextField`, add `SafeArea` + `SingleChildScrollView`, wire `onTap` on `CasamaAvatar` (fixing dead camera badge), wrap `'Take Photo'`/`'Gallery'` buttons, raise preset avatar chips to `≥48dp`, and replace raw `'Could not access image: $e'` with friendly copy.
- **`settings/app_settings_screen.dart`**
  - Migrate off manual `isDark`/`#2C3E5A`/`#243650` onto `CasamaThemeContext`, fixing 16+ `2.95:1` dark subtitles, `3.05:1` dark `errorRed`, `2.85:1` selected `_ThemeChoiceTile` (replace `GestureDetector` with `InkWell` + `Semantics(selected: ...)`), and unstyled `_confirmLogout` dialog.
  - Fix `'Application Permissions'` onboarding hijack (`fromSettings: true`), pass `?tab=privacy&readOnly=true` on `'Privacy Policy'` and `?tab=terms&readOnly=true` on `'Terms of Service'`.
  - Remove or `kDebugMode`-gate the `"High-Fidelity Mock Mode"` & fake `"Reset Offline Cache"` developer card; wire `_shareRoomStatus` to `repositoryProvider`; remove/disable unbacked 2FA & fake Change Password stubs (or add real validation, scrolling, controller disposal, and password peek toggles); convert non-interactive faux rows (`Manage Account`) into actionable links or plain metadata; cap tablet width at `680dp` and use adaptive `BackButton()`.
- **`legal/terms_consent_screen.dart`**
  - Replace `24×24dp` standalone checkboxes with full-row tappable `CheckboxListTile` / `InkWell` (`≥48dp` tall); upgrade `'Read Full Document'` links to `≥48dp` AA `TextButton`s deep-linking to `/terms?tab=terms` and `/terms?tab=privacy` and honoring the `bool` pop result.
  - Fix Dark Mode `2.65:1` footer caption, add bottom `SafeArea`, remove heading emoji (`📋`), and use adaptive `BackButton()`.
- **`legal/terms_privacy_screen.dart`**
  - Support `?tab=terms|privacy|permissions&readOnly=true` so Settings/Profile views open the exact requested tab and **hide** the mandatory `'I Understand & Agree'` footer in read-only mode.
  - Reconcile Permissions tab with `DevicePermissionsScreen` (mark `'Camera & Photo Library'` as optional/on-demand, not `Required`, and move `'Local Storage'` into Privacy).
  - Replace `Row` + `Spacer()` in `_buildPermissionItem` with `Flexible`/`Wrap` (fixes compact/scaled-font overflow), cap tablet prose measure to `680dp`, and use adaptive `BackButton()`.
