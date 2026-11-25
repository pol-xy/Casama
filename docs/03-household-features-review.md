Method: design review only (detector not applicable, native platform)

# Casama Household Feature Modules Audit & UX Critique

> **Scope**: All **7 UI screen/component files** (4,549 lines of Dart) across `lib/features/tasks/` (`maintenance_screen.dart`), `lib/features/chore_roulette/` (`chore_roulette_screen.dart`), `lib/features/bills/` (`bills_dashboard_screen.dart`, `add_bill_screen.dart`, `bill_detail_screen.dart`), `lib/features/calendar/` (`household_calendar_view.dart`), and `lib/features/parcels/` (`parcels_screen.dart`) — audited alongside `lib/data/models.dart` and `lib/data/mock_repository.dart`.
>
> **Focus Areas**: Card density, scannability, touch targets, and interactive clarity.
>
> **Platform & Mode**: Flutter cross-platform mobile application (Android-first Material 3 + iOS adaptive) · **Operate** surface mode (with playful micro-interaction on Chore Roulette) · Evaluated against **WCAG 2.1 AA**, **Material Design 3**, and **Apple Human Interface Guidelines (HIG)**.
>
> **Run Notes**: The `impeccable` CLI engine is unavailable in this environment (no network/cache write access; not retried per skill rules), so project context was read directly from `README.md`, `Casama_Project_Documentation.md`, `pubspec.yaml`, and source files; automated `.impeccable/` snapshot persistence was skipped. No emulator/simulator screenshots were captured; all WCAG 2.1 contrast ratios and Chore Roulette wheel-landing angles were computed mathematically from source.

---

## Executive Summary

Casama's five household coordination modules cover genuinely useful shared-living workflows, and `BillsDashboardScreen` + `BillDetailScreen` show noticeably richer CRUD craft than older mockup-driven screens. However, severe **interactive-clarity bugs, misreported financial totals, undiscoverable actions, undersized touch targets, high card density, and broken Dark Mode contrast** severely undermine real-world usability across all five modules:

- **Native Technical Audit Score**: **7 / 20** (**Poor** — major overhaul needed)
- **UX Design Critique Score**: **16 / 40** (**40.0% · Poor** — all 10 Nielsen heuristics scored)
- **Total Issues Found**: **26** (**5 P0 Blocking**, **11 P1 Major**, **7 P2 Minor**, **3 P3 Polish**)

### Top 5 Critical Issues
1. **[P0] Non-Shopee Parcels Cannot Be Marked Received (`parcels_screen.dart:497-546`)**: `_ParcelCard` decides whether to render `'I Got It'` (real state mutation) vs. `'Mark Unavailable'` (fake SnackBar-only button) based on `if (isShopee)`—leaving Lazada, TikTok Shop, FedEx, and Other deliveries completely unclaimable, and Shopee deliveries unable to be marked unavailable.
2. **[P0] Hidden Task Completion on a `32×32dp` Avatar (`maintenance_screen.dart:434-464`)**: Tasks have no checkbox, no Complete button, and no status switcher (`In Progress` is permanently unreachable). The *only* way to complete a task is tapping a `32×32dp` assignee avatar circle with zero visual affordance (clue buried inside a long-press `Tooltip`), firing immediately with no confirmation or undo.
3. **[P0] Chore Roulette Wheel Lands on the Wrong Slice Every Single Spin (`chore_roulette_screen.dart:87-110, 511-566`)**: Because `Transform.rotate` rotates clockwise by `+targetAngle` added onto `_currentAngle`, mathematical verification confirms **6 out of 6 spins point to a different chore under the 12 o'clock pointer** than the winning chore announced in the result dialog (e.g., Spin 1 announces `"Take Out Trash"` while the pointer lands squarely on `"Clean Bathroom"`).
4. **[P0] `BillsDashboardScreen` Omits Overdue Bills From `'Unpaid'` Count & `'Total Due'` (`bills_dashboard_screen.dart:31-48`)**: Filtering `effectiveStatus == BillStatus.unpaid` excludes `BillStatus.overdue`, causing the summary cards to misreport **₱3,350.00 (2 bills)** when the household actually owes **₱4,649.00 (3 bills including overdue PLDT Wi-Fi)**.
5. **[P0] Dark Mode Invisible Controls (`1.01:1–1.66:1`) & Pervasive Sub-`48dp` Touch Targets**: Lazada/Other parcel titles and `'Mark Unavailable'` (`1.01:1–1.16:1`), Roulette pointer & active toggle (`1.01:1`), Maintenance dark category icons (`1.18:1–1.66:1`), and modal ChoiceChips (`1.11:1`) vanish in Dark Mode; meanwhile **0 `Semantics`** hooks exist across 4,549 lines and touch targets drop to `24dp–36dp` across every single module.

---

## Part 1: Native Technical Audit (`audit.native.md`)

### Audit Health Score

| # | Dimension | Score | Key Finding |
|---|-----------|-------|-------------|
| 1 | Accessibility | **1 / 4** | 0 `Semantics` / `disableAnimations` calls across 4,549 lines; 4s spinning wheel ignores Reduce Motion; touch targets down to `24–36dp` in all 5 modules; severe Light/Dark contrast failures (`1.01:1`–`2.85:1`) |
| 2 | Performance | **2 / 4** | `ChoreRouletteScreen` calls full-screen `setState` every animation frame; `HouseholdCalendarView` queries events 35–42× per build; 3 undisposed modal `TextEditingController`s; uncached `Image.network` |
| 3 | Appearance & Theming | **1 / 4** | 32 raw `Color(0x...)` + 32 static light `CasamaColors.*` tokens + 0 `.textTheme` uses; Dark Mode invisible text/icons (`1.01:1–1.66:1`) in Parcels, Maintenance, Roulette & Bills; white celebration dialogs |
| 4 | Platform Conformance | **2 / 4** | Hand-rolled `GestureDetector` radios, filter chips, segmented toggles & avatar-as-checkbox; pinned Maintenance CTA omits `SafeArea`; hidden modal validation SnackBar; duplicate Add Bill triggers; iOS back arrow in Roulette |
| 5 | Adaptivity | **1 / 4** | Non-scrollable `ChoreRouletteScreen` overflows in landscape; `_BillCard` bottom row & `AddBillScreen` 5-tile row overflow on compact/scaled viewports; Calendar week strip collapses; 0 tablet multi-column layouts |
| **Total** | | **7 / 20** | **Poor (major overhaul)** |

*Rating bands: 18–20 Excellent · 14–17 Good · 10–13 Acceptable · 6–9 Poor · 0–5 Critical.*

### Platform Conformance Verdict

**FAIL — Mixes native Material 3 form widgets with ad-hoc custom controls, missing safe areas, and inconsistent creation patterns across sibling modules.**

Specific platform violations across the 7 audited files:
1. **Reinvented interactive primitives**: Custom `GestureDetector` radio rows (`add_bill_screen.dart:486`, `~24dp` tall instead of `RadioListTile`), custom `GestureDetector` filter pills (`bills_dashboard_screen.dart:366`, `household_calendar_view.dart:275` instead of `FilterChip`), custom `GestureDetector` segmented control (`chore_roulette_screen.dart:275` instead of `SegmentedButton`), and a `32dp` `GestureDetector` avatar replacing a `Checkbox` (`maintenance_screen.dart:434`).
2. **Inconsistent primary-action pattern across sibling boards**: `MaintenanceScreen` pins a full-width navy pill button over a `Stack` (`Positioned(bottom: 24)` **without `SafeArea`**, colliding with Android gesture nav / iOS home indicator); `ParcelsScreen` hides Add behind an unlabeled AppBar `+` icon; `BillsDashboardScreen` puts **both** an AppBar `+` icon AND a `FloatingActionButton.extended('Add Bill')` on the same screen.
3. **Destructive navigation surprise (`add_bill_screen.dart:90-93`)**: Places an `Icons.home_outlined` button in the form `AppBar` that calls `context.go('/dashboard')`, silently discarding unsaved bill data without confirmation.
4. **Off-platform details**: `chore_roulette_screen.dart:254` hardcodes iOS `Icons.arrow_back_ios_new` on Android; `maintenance_screen.dart:282` fires a root `ScaffoldMessenger` validation SnackBar *behind* the open Add Task bottom sheet; `bill_detail_screen.dart:85-87` uses raw `Colors.red` instead of `colorScheme.error`.

---

## Part 2: UX Design Critique (`critique.md` & `critique-rubric.md`)

### Design Health Score (Nielsen's 10 Usability Heuristics)

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | **2 / 4** | Bills `'Total Due'` & `'Unpaid'` exclude overdue bills (₱3,350 vs real ₱4,649); Roulette pointer disagrees with result on 6/6 spins; `'In Progress'` tab permanently empty; Calendar collapses all event categories/counts into 1 dot |
| 2 | Match System / Real World | **1 / 4** | Parcels action gated on `isShopee` brand; Maintenance labels every Landlord task `'Bathroom'` & every DIY task `'Kitchen'` (even `"Clean Bathroom"` → `'Kitchen'`!); Calendar skips Bills & hardcodes `'4:00 PM'`; Roulette says `"Dormmate"` |
| 3 | User Control and Freedom | **2 / 4** | Maintenance completes tasks on a single accidental `32dp` avatar tap (no confirm/undo); `BillDetailScreen` lacks Edit; `AddBillScreen` Home icon discards form silently; Parcels lacks Edit/Cancel; Roulette lacks chore/member editing |
| 4 | Consistency and Standards | **1 / 4** | `bills/` bypasses `CasamaButton`, `CasamaTextField`, `StatusChip` & Material icons (using emojis + `withAlpha`), while `tasks/` & `parcels/` diverge; 3 incompatible Add-item patterns across 3 boards; 32 raw hexes; 0 `.textTheme` uses |
| 5 | Error Prevention | **1 / 4** | `AddBillScreen` never calls `_formKey.currentState!.validate()` (0 validators); `ParcelsScreen` pre-fills COD `'350'` and silently coerces invalid text to `₱0.00`; `MaintenanceScreen` hardcodes 4 assignees (omits new members) |
| 6 | Recognition Rather Than Recall | **1 / 4** | Maintenance hides completion on an unbadged avatar (`Tooltip` only) & omits assignee/due date text; Roulette slices are icon-only with no legend; Parcels omits `buyerName` & shows unlabeled `[Y][A][R]` dots; Bills stats aren't tappable |
| 7 | Flexibility and Efficiency | **2 / 4** | Category filters & modal quick-open params help, but `BillsDashboardScreen` puts ~340dp of non-interactive stats/chips above the first bill; Calendar taps jump to root lists rather than specific items; 10 flat horizontal bill filter chips |
| 8 | Aesthetic and Minimalist Design | **2 / 4** | Warm card rhythm & Roulette concept work in Light Mode, but `AddBillScreen` wastes ~190dp on a decorative receipt graphic, 5/6 wheel icons fail contrast (`1.41–2.44:1`), and Dark Mode breaks across every single module |
| 9 | Error Recovery | **2 / 4** | `BillDetailScreen` handles missing IDs & confirms Delete/Mark Paid; however Maintenance empty-title SnackBar hides behind modal, invalid numeric inputs silently coerce to `0`/`null`, and Calendar empty state offers no creation CTA |
| 10 | Help and Documentation | **2 / 4** | Good inline placeholder hints on forms, but zero legend for Chore Roulette slices, zero explanation of `[Y][A][R]` parcel availability circles, and critical completion interaction hidden inside a long-press Tooltip |
| **Total** | | **16 / 40** | **Poor (40.0%)** |

*Score bands (out of 40): 36–40 Excellent · 28–35 Good · 20–27 Acceptable · 12–19 Poor · 0–11 Critical.*

### Design Specificity Verdict

- **LLM Assessment**: These five modules capture genuine, localized Filipino shared-living workflows—Philippine Peso (`₱`) formatting, Shopee/Lazada/TikTok Shop couriers with COD accountability, Meralco/MWSS/PLDT utility presets, and playful Chore Roulette for housemate fairness. That domain specificity is a real asset. Yet **implementation shortcuts undermine product authenticity**: `ParcelsScreen` hardcodes Shopee vs. non-Shopee behavior straight out of a static UI mockup, `MaintenanceScreen` hardcodes `'Bathroom'`/`'Kitchen'` room labels regardless of the task entered, `ChoreRouletteScreen` ships disconnected spin math with unreadable pastel icon-only slices, and `bills/` was visibly built in an isolated visual dialect (emoji icons, `withAlpha`, raw `ElevatedButton`/`TextFormField`, custom badges) that drifts from `tasks/` and `parcels/`.
- **Deterministic Scan**: `not applicable (native platform)`

### Overall Impression

This layer has **functional illusions hiding behind clean Light-Mode cards**: a parcel card that only lets you receive Shopee packages, a task card whose sole completion button looks like a decorative avatar, a spinning wheel whose pointer disagrees with the announced winner, and a bills summary that undercounts what the household owes by ignoring overdue bills. Fixing those 4 core logic/affordance breaks—while tightening Bills card density, raising touch targets to `≥48dp`, adding scannable metadata (buyer names, assignees, due dates, wheel labels), and repairing Dark Mode—will transform these screens from demo facades into dependable daily tools.

### What's Working (Positive Findings)
1. **Rich, Well-Virtualised Bills Architecture (`bills_dashboard_screen.dart`, `bill_detail_screen.dart`)**: `BillsDashboardScreen` uses `CustomScrollView` + `SliverList`, auto-detects overdue bills on read, and pairs `BillDetailScreen` with clear `"Mark as Paid?"` and `"Delete Bill?"` confirmation dialogs plus creator-gated `Reopen` / `Delete` actions.
2. **Input Formatting & Progressive Disclosure on `AddBillScreen` (`add_bill_screen.dart:170-185, 236-238, 423-530`)**: Currency regex formatting (`^\d*\.?\d{0,2}`), expandable `"More"` bill categories, conditional `"Custom Category"` field for `"Other"`, and collapsible reminder settings when `"Set Reminder"` is toggled off show thoughtful form design.
3. **Strong Empty-State & Celebration Moments (`maintenance_screen.dart:118-142`, `parcels_screen.dart:100-127`)**: Mascot-led empty states and Good Kasama Points celebrations give household chores and parcel receiving warm emotional closure.

---

## Part 3: Deep-Dive Focus Area Evaluations

### Module Readiness Matrix (All 7 Audited Files)

| # | File | Card Density | Scannability | Touch Targets | Interactive Clarity | Dark Mode | Responsive / Scaling | Accessibility |
|---|---|---|---|---|---|---|---|---|
| 1 | `tasks/maintenance_screen.dart` | Good (clean rows) | **FAIL** (fake `'Bathroom'`/`'Kitchen'`, no assignee/due text) | **FAIL** (`32dp` avatar CTA, `44dp` dialog btn) | **BROKEN (P0)** (hidden avatar tap, no `In Progress`, no undo) | **FAIL** (`1.18–1.66:1` icons, `1.11:1` modal btn, white dialog) | **FAIL** (no `SafeArea` on pinned CTA, 4 tabs wrap) | **FAIL** (0 semantics) |
| 2 | `chore_roulette/chore_roulette_screen.dart` | Low (wheel-focused) | **FAIL** (icon-only slices, no legend, `1.41–2.44:1`) | **FAIL** (`~36dp` mode toggle, `44dp` dialog btn) | **BROKEN (P0)** (6/6 spin pointer mismatch, no chore/member edit) | **BROKEN** (`1.01:1` pointer & active toggle, `1.0:1` box, peach banner) | **BROKEN** (non-scrollable `Column` + `310px` wheel overflows) | **FAIL** (0 semantics, ignores Reduce Motion) |
| 3 | `bills/bills_dashboard_screen.dart` | **FAIL** (~340dp chrome before card 1) | **FAIL** (excludes overdue from Total Due; `2.47–2.85:1` stats) | **FAIL** (`~32dp` filter chips; 10 chips) | **FAIL** (non-tappable stats/overdue banner; duplicate Add Bill) | **FAIL** (light status badges & banner, `2.62:1` reminder) | **FAIL** (`_BillCard` bottom row overflows; no tablet grid) | **FAIL** (0 semantics, `2.47:1` badges) |
| 4 | `bills/add_bill_screen.dart` | **FAIL** (~190dp decorative hero above form) | Partial (clear labels, cramped 5-col tiles) | **FAIL** (`~24dp` custom radio rows) | **FAIL** (0 validation; AppBar Home discards form silently) | Partial (white receipt card, `2.85:1` CTA) | **FAIL** (5-tile `Row` wraps/clips `'Electricity'`) | **FAIL** (0 semantics, `GestureDetector` radios/date) |
| 5 | `bills/bill_detail_screen.dart` | Good (clean grouped cards) | Partial (`2.85:1` amount, no tabular figures) | Good (`48–52dp` CTAs) | Partial (no Edit action; raw `Colors.red` menu) | **FAIL** (light status/`ON` badges, unstyled dark dialogs) | Good (scrollable, lacks tablet max-width) | **FAIL** (0 semantics, `2.57:1` Reopen) |
| 6 | `calendar/household_calendar_view.dart` | **FAIL** (6-row grid + controls + filter + list in 1 card) | **FAIL** (single dot hides types/counts; misses Bills; `'4:00 PM'` fake; 12h/24h mix) | **BROKEN** (`24dp` Today, `26dp` pills, `32dp` arrows, `41×35dp` cells) | **FAIL** (taps open root lists, not specific items; silent month-jump on faded dates) | **FAIL** (`2.91:1` meetup icon, `1.52:1` out-of-month dates) | **BROKEN** (collapsed week strip cells; `10pt` badge) | **FAIL** (0 semantics) |
| 7 | `parcels/parcels_screen.dart` | Good (structured 2-zone card) | **FAIL** (missing `buyerName`, unlabeled `[Y][A][R]` dots, no conflict alert) | **FAIL** (`~32dp` `I Got It`/`Mark Unavailable`, `44dp` dialog btn) | **BROKEN (P0)** (Shopee-only Receive; fake Mark Unavailable; no Cancel/Edit) | **BROKEN** (`1.01–1.16:1` titles/button/ChoiceChips; white dialog) | Partial (`ChoiceChip` wraps tight on `<360dp`) | **FAIL** (0 semantics, unlabeled AppBar `+`) |

### Focus 1: Card Density
- **`BillsDashboardScreen` (`bills_dashboard_screen.dart:67-203`)**: Stacks a 2×2 grid of tall `_StatCard`s (each containing an icon box, `20pt` number, `12pt` label, AND `11pt` sub-label = `~105dp` tall × 2 rows) plus an overdue alert banner plus a horizontal row of **10** filter chips = **~340dp** of header chrome before the user sees a single bill! Condensing summary stats into a single horizontal 2-metric hero bar (e.g., **Total Unpaid (incl. overdue)** + **Paid / Overdue** tap-to-filter pills) reclaims ~140dp so 2+ bill cards sit immediately above the fold.
- **`AddBillScreen` (`add_bill_screen.dart:104-133`)**: Opens a dense 8-field Operate-mode form with a **~190dp** decorative `_BillIllustration` + heading + 2-line marketing subtitle—forcing users to scroll before even reaching Amount or Deadline.
- **`HouseholdCalendarView` (`household_calendar_view.dart:71-331`)**: Packs 5 distinct chrome bands (month header + 4 controls, weekday row, 35–42 day grid, schedule header + activity count pill, 4 filter chips) plus an event list all inside a single bordered card—competing for space on phones while burying actual daily activities.
- **`_TaskCard` (`maintenance_screen.dart:380-467`) vs. `_ParcelCard` (`parcels_screen.dart:373-556`)**: `_TaskCard` is actually *under-informative* (single cramped horizontal row omitting assignee name, due date, category label, and visible action button), whereas `_ParcelCard` has healthy visual breathing room (`16dp` padding + divider) yet leaves out the most important scannable metadata (`buyerName`).

### Focus 2: Scannability
- **Missing or False Metadata Across Cards**:
  - **`ParcelsScreen`**: Never prints `parcel.buyerName` on `_ParcelCard`—in a shared house, knowing *whose* Shopee package is arriving is essential! Also renders `[Y] [A] [R]` circles with no `"Available to receive:"` label.
  - **`MaintenanceScreen`**: Maps `TaskCategory.landlord` → `'Bathroom'` and `TaskCategory.diy` → `'Kitchen'` verbatim (`lines 338, 350`), mislabeling tasks like `"Clean Bathroom"` (assigned as DIY from Chore Roulette) as **`'Kitchen'`**, and hides `task.assigneeName` and `task.dueDate`!
  - **`ChoreRouletteScreen`**: Renders 6 **icon-only** slices with no text labels, no chore legend, two nearly identical teal slices (`#80CBC4` & `#4DB6AC`), and **5 of 6 slices failing 3.0:1 icon contrast** (`1.41:1` yellow to `2.44:1` teal).
  - **`BillsDashboardScreen`**: Understates financial urgency by excluding overdue bills from `'Unpaid'` and `'Total Due'` (`lines 31-48`), fails contrast on all 4 stat figures (`2.70:1–4.12:1`) and all 3 status badges (`2.47:1–4.36:1`), and omits tabular numerals (`FontFeature.tabularFigures()`) on currency values.
  - **`HouseholdCalendarView`**: Uses one single `5×5` coral dot regardless of whether a date has 1 parcel or 4 urgent tasks, completely excludes household bill deadlines, hardcodes `'4:00 PM'` on every parcel (`line 655`), and mixes 12-hour (`4:00 PM`) with 24-hour (`14:05`) time labels in the same feed.

### Focus 3: Touch Targets
Every single module violates Android `48×48dp` and/or iOS `44×44pt` touch-target minimums:

| Screen | Control | Line(s) | Measured Size | Status |
|---|---|---|---|---|
| `household_calendar_view.dart` | `'Today'` button (`minimumSize: Size.zero`) | L116-134 | `~48 × 24dp` | **FAIL** |
| `add_bill_screen.dart` | Custom radio rows (`20×20` circle + `Text` in `GestureDetector`) | L482-529 | `full × ~24dp` | **FAIL** |
| `household_calendar_view.dart` | Category filter pills (`vertical: 5`) | L275-308 | `~56 × 26dp` | **FAIL** |
| `maintenance_screen.dart` | Task-complete assignee avatar (`width: 32, height: 32`) | L434-464 | `32 × 32dp` | **FAIL** |
| `household_calendar_view.dart` | Month `<`, `>`, Week/Month toggle `IconButton`s | L137-180 | `32 × 32dp` | **FAIL** |
| `parcels_screen.dart` | `'I Got It'` & `'Mark Unavailable'` (`minimumSize: Size.zero`) | L507, L531 | `~90 × 32dp` | **FAIL** |
| `bills_dashboard_screen.dart` | Category `_FilterChip` (`vertical: 7`) | L366-387 | `~60 × 32dp` | **FAIL** |
| `household_calendar_view.dart` | Month day cells (`360dp` phone, 7 cols, `aspectRatio: 1.15`) | L362-365 | `41 × 35.6dp` | **FAIL** |
| `chore_roulette_screen.dart` | Mode selector pills (`vertical: 9`) | L275-359 | `~150 × 36dp` | **FAIL** |
| `household_calendar_view.dart` | Week strip cells (missing `Expanded`) | L401-406 | `~22 × 32dp` | **FAIL** |
| `maintenance_screen.dart` / `parcels_screen.dart` / `chore_roulette_screen.dart` | Dialog `CasamaButton(height: 44)` | L517 / L609 / L228 | `full × 44dp` | **FAIL** (Android 48dp) |

### Focus 4: Interactive Clarity
1. **Broken or Misleading Action Semantics**:
   - `ParcelsScreen`: Action button depends on `isShopee` (`L497`); `'Mark Unavailable'` is a non-functional dummy SnackBar (`L534`).
   - `MaintenanceScreen`: Completion is invisible on a `32dp` avatar (`L434`); `'In Progress'` status has **zero** UI trigger anywhere in the app.
   - `ChoreRouletteScreen`: Top pointer visually disagrees with the winning dialog on **6/6 spins** (`L87-110`); `Random Dormmate` mode still picks `'Out'` roommates without letting users toggle participants or chores.
   - `BillsDashboardScreen`: The 4 stat cards and red overdue alert banner look like interactive filters yet ignore taps completely; meanwhile two separate `"Add Bill"` buttons compete on the same viewport.
   - `AddBillScreen`: `_formKey` is never validated (`L597`), and the AppBar Home icon exits without warning on unsaved edits (`L90-93`).
   - `HouseholdCalendarView`: Tapping a specific parcel, task, or meet-up dumps the user at the top-level module list instead of opening or filtering to that item; faded out-of-month numbers (`1.37:1`) secretly change the active month when tapped.

---

## Part 4: Detailed Findings by Severity

### P0 — Blocking (Fix Immediately)

#### [P0-1] `ParcelsScreen` Gates Receive vs. Unavailable Action on Courier Brand (`isShopee`) and Fakes `'Mark Unavailable'`
- **Location**: `lib/features/parcels/parcels_screen.dart:496-546`
- **Category**: Interactive Clarity / Implementation Integrity
- **Impact**: `if (isShopee)` renders `'I Got It'` (calling `receiveParcel`), whereas `else` (Lazada, TikTok Shop, FedEx, Other) renders `'Mark Unavailable'` (which only triggers a dummy SnackBar and never updates `repo.parcels`). Users literally **cannot mark any non-Shopee parcel as received**, and **cannot mark themselves unavailable for any Shopee parcel**.
- **Guideline**: Nielsen H2 (Match System/Real World) & H3 (User Control); `Casama_Project_Documentation.md` §3.
- **Recommendation**: Remove the `if (isShopee)` branch entirely. Every expected parcel card should offer consistent state-driven controls: a primary `'I Got It'` (claim/receive) action AND a secondary `'Available'` / `'Can't Receive'` toggle backed by a real `toggleParcelAvailability(parcelId)` repository method, plus a conflict warning chip when `parcel.isAllUnavailable` or `availableMemberNames.isEmpty`.
- **Suggested command**: `/impeccable harden`

#### [P0-2] `MaintenanceScreen` Hides Its Only Task Completion Action on a `32×32dp` Avatar With No Affordance, Confirmation, Undo, or `In Progress` Transition
- **Location**: `lib/features/tasks/maintenance_screen.dart:49-51, 91, 433-464`
- **Category**: Interactive Clarity / Accessibility / Touch Targets
- **Impact**: There is no checkbox, Complete button, or task detail sheet. Users must guess to tap a `32×32dp` assignee avatar (failing 44pt/48dp minimums and hiding the `"Tap to complete"` instruction inside a long-press `Tooltip`), which immediately completes the task with no undo—while the `'In Progress'` tab can never contain any task because no UI control transitions a task to `TaskStatus.inProgress`.
- **Guideline**: Android 48dp / iOS 44pt Touch Targets; Nielsen H3, H5, H6.
- **Recommendation**: Add a clear `48×48dp` leading checkbox or trailing status/action button (`Start` → `Complete`) on `_TaskCard`, make the full card tappable (`InkWell`) to open a Task Detail / Status sheet (supporting Open / In Progress / Done + reassign + delete), and add an `Undo` action on completion SnackBars.
- **Suggested command**: `/impeccable harden`

#### [P0-3] `ChoreRouletteScreen` Wheel Pointer Visually Disagrees With the Announced Winning Chore on Every Spin
- **Location**: `lib/features/chore_roulette/chore_roulette_screen.dart:81-114, 401-407, 511-568`
- **Category**: Interactive Clarity / Implementation Integrity
- **Impact**: `_RouletteWheelPainter` draws slice `i` clockwise from `0 rad` (3 o'clock), while the pointer sits at `-pi / 2` (`270°`, 12 o'clock). Rotating clockwise by `targetAngle = extraSpins*2*pi + targetSegment*segmentAngle + segmentAngle/2` added to `_currentAngle` produces a **0% match rate across all 6 slices** (e.g., Spin 1 declares `"Take Out Trash"` while the top pointer lands squarely on `"Clean Bathroom"`), immediately shattering user trust in Chore Roulette's fairness.
- **Guideline**: Nielsen H1 (System Status) & H2 (Real-World Match).
- **Recommendation**: Compute the exact absolute landing angle for slice `targetSegment`'s center to align under `-pi / 2`: `final desired = (1.5 * pi - (targetSegment + 0.5) * segmentAngle) % (2 * pi); final delta = (desired - _currentAngle) % (2 * pi); final endAngle = _currentAngle + (extraSpins * 2 * pi) + delta;` and verify with a unit test for all 6 indices across consecutive spins.
- **Suggested command**: `/impeccable harden`

#### [P0-4] `BillsDashboardScreen` Excludes Overdue Bills From `'Unpaid'` Count and `'Total Due'` Financial Summary
- **Location**: `lib/features/bills/bills_dashboard_screen.dart:31-48, 80-98`
- **Category**: Visibility of System Status / Scannability / Data Integrity
- **Impact**: `unpaidBills` matches only `BillStatus.unpaid` and omits `BillStatus.overdue`, so `totalUnpaidAmount` excludes overdue bills (e.g., overdue `PLDT Wi-Fi` ₱1,299.00). Housemates see **₱3,350.00 (2 bills)** instead of the true **₱4,649.00 (3 unpaid/overdue bills)**—a high-stakes financial miscalculation.
- **Guideline**: Nielsen H1 (Visibility of System Status) & H5 (Error Prevention).
- **Recommendation**: Include both `BillStatus.unpaid` and `BillStatus.overdue` (`b.effectiveStatus != BillStatus.paid`) in `outstandingBills` and `totalDueAmount`, while keeping `overdueBills` highlighted separately as an urgent interactive filter.
- **Suggested command**: `/impeccable harden`

#### [P0-5] Invisible Dark Mode Controls (`1.01:1–1.66:1`) & Complete Absence of Accessibility Semantics Across All 7 Files
- **Location**: `parcels_screen.dart:255, 272, 366, 525, 577`, `maintenance_screen.dart:279, 336-350, 394-397, 489`, `chore_roulette_screen.dart:165, 286, 416, 469`, plus all 7 files (`0` `Semantics` / `disableAnimations` calls)
- **Category**: Accessibility / Theming
- **Impact**: In Dark Mode, Lazada (`#0F156D` = **1.16:1**) and Other (`#1C2E4A` = **1.01:1**) parcel titles, `'Mark Unavailable'` button text (**1.01:1**), Add Parcel ChoiceChips (**1.11:1**), Maintenance dark category icons (**1.18:1–1.66:1**) and modal `'Add Task'` navy button (**1.11:1**), and Chore Roulette's top pointer & `'Random Dormmate'` active toggle (**1.01:1**) disappear against dark cards/surfaces. Meanwhile, screen-reader users get zero semantic roles/labels on custom toggles, chips, calendar day cells, wheel spin button, and task completion controls.
- **Guideline**: WCAG 2.1 SC 1.4.3 (4.5:1), 1.4.11 (3.0:1), 4.1.2; Material 3 Dark Theme; TalkBack / VoiceOver HIG.
- **Recommendation**: Replace all static dark-failing colors with theme-aware AA tokens (verified ≥4.5:1 text / ≥3.0:1 icons in both Light and Dark Mode), theme the celebration dialogs (`context.surfaceColor` / `context.textColor`), and wire native M3 widgets + `Semantics` labels throughout.
- **Suggested command**: `/impeccable colorize`

---

### P1 — Major (Fix Before Release)

#### [P1-1] Pervasive Sub-Minimum Touch Targets (`24dp–44dp`) Across All 5 Feature Modules
- **Location**: `household_calendar_view.dart:116-180, 275-308, 362-365, 401-406`, `add_bill_screen.dart:482-529`, `maintenance_screen.dart:434-464, 517`, `parcels_screen.dart:507, 531, 609`, `bills_dashboard_screen.dart:366-387`, `chore_roulette_screen.dart:275-359, 228`
- **Category**: Accessibility / Touch Targets
- **Impact**: Ten distinct interactive controls—including primary actions (`I Got It`, task completion, bill radio options, calendar day cells & arrows, filter chips, Roulette mode switcher)—measure `24dp–36dp`, causing frequent mis-taps during one-handed mobile use.
- **Guideline**: Android 48×48dp (`android.md`); iOS 44×44pt (`ios.md`); WCAG 2.1 SC 2.5.8.
- **Recommendation**: Remove `minimumSize: Size.zero` and `BoxConstraints(minWidth: 32, minHeight: 32)` overrides; replace custom `GestureDetector` chips/radios/toggles with M3 `FilterChip` (`materialTapTargetSize: padded`), `RadioListTile`, and `SegmentedButton`; ensure calendar day cells have `minHeight: 44–48dp` (`childAspectRatio: 0.9` or `48dp` row height) and `Expanded` cells in `_buildWeekStrip`.
- **Suggested command**: `/impeccable adapt`

#### [P1-2] `MaintenanceScreen` Hardcodes Fake `'Bathroom'`/`'Kitchen'` Subtitles and Omits Assignee Name & Due Date
- **Location**: `lib/features/tasks/maintenance_screen.dart:333-352, 401-427, 264`
- **Category**: Scannability / Match System & Real World
- **Impact**: Every Landlord task displays `'Bathroom'` and every DIY task displays `'Kitchen'`—so creating `"Fix front door knob"` (Landlord) shows `'Bathroom'` and spinning `"Clean Bathroom"` in Chore Roulette (saved as `TaskCategory.diy`) displays `'Kitchen'`! Cards also omit assignee name text and `dueDate`, and the Add Task assignee dropdown hardcodes 4 names instead of `repo.members`.
- **Guideline**: Nielsen H2 & H6 (Recognition Rather Than Recall).
- **Recommendation**: Display the real category label (`DIY / Roommate`, `Landlord / Admin`, `Restock`), `task.assigneeName ?? 'Unassigned'`, and formatted `dueDate` (`Due Tomorrow`) on `_TaskCard`, and populate the assignee dropdown dynamically from `repo.members`.
- **Suggested command**: `/impeccable clarify`

#### [P1-3] `ParcelsScreen` Omits Buyer Name, Conflict Alerts, and Availability Explanation on `_ParcelCard`
- **Location**: `lib/features/parcels/parcels_screen.dart:383-494`
- **Category**: Scannability / Interactive Clarity
- **Impact**: In a shared household, `_ParcelCard` displays courier + arrival time + COD chip + notes, but **never displays `parcel.buyerName`**—leaving housemates unable to tell whose package is arriving! The bottom row displays unlabeled `26×26` initial circles (`[Y][A][R]`) with no heading (`"Available:"`), and ignores `parcel.isAllUnavailable` conflict warnings.
- **Guideline**: Nielsen H6 (Recognition Rather Than Recall); `Casama_Project_Documentation.md` §3.
- **Recommendation**: Show `"For ${parcel.buyerName}"` prominently beside or below the courier title, label the avatar stack (`"Can receive:"` with tooltips/names), and render a high-contrast conflict alert chip when no housemate is available to receive the delivery.
- **Suggested command**: `/impeccable clarify`

#### [P1-4] `ChoreRouletteScreen` Uses Icon-Only Wheel Slices (`1.41:1–2.44:1`), Ignores Reduce Motion, and Overflows in Landscape
- **Location**: `lib/features/chore_roulette/chore_roulette_screen.dart:32-59, 64-114, 259-486, 540-566`
- **Category**: Scannability / Accessibility / Adaptivity
- **Impact**: Users cannot identify any of the 6 chores before spinning (only white `24px` icons on pale slices, with 5/6 failing 3.0:1 UI contrast—Yellow `#FFD54F` is **1.41:1**!). The 4-second 5–8 revolution spin ignores `MediaQuery.disableAnimationsOf(context)` (vestibular hazard). The fixed `310×310` wheel inside a non-scrollable `Column` with `Spacer()` overflows in landscape or on compact phones (`<640dp` height).
- **Guideline**: WCAG 2.1 SC 1.4.11 & 2.3.3 (Reduce Motion); Apple HIG & Android Reduce Motion; Responsive Layouts.
- **Recommendation**: Wrap body in `SingleChildScrollView` + `LayoutBuilder` (scaling wheel diameter responsively to `min(maxWidth - 48, 290)`), draw radial chore labels or a compact scannable chip legend below the wheel, darken slice fills or use dark `#1C2E4A` icons on pastel slices (all ≥4.5:1!), and when `MediaQuery.disableAnimationsOf(context)` is `true`, replace the 4s spin with a brief `250ms` crossfade reveal.
- **Suggested command**: `/impeccable adapt`

#### [P1-5] `BillsDashboardScreen` Heavy Card Density (~340dp Above Fold), Failing Stat/Badge Contrast, Non-Tappable Alerts & Horizontal Card Overflow
- **Location**: `lib/features/bills/bills_dashboard_screen.dart:77-203, 281-349, 402-420, 506-579`
- **Category**: Card Density / Scannability / Accessibility / Adaptivity
- **Impact**: Stacking 4 tall stat cards + overdue banner + 10 horizontal category chips pushes the first bill card far down the viewport. All 4 stat numbers fail 4.5:1 (`Total Due` **2.70:1**, `Unpaid` **2.85:1**), all 3 status badges fail 4.5:1 (`Unpaid` **2.47:1**, `Paid` **3.66:1**, `Overdue` **4.36:1**) and flash light pastel boxes in Dark Mode, reminder text (`deepTeal` on `darkCard`) drops to **2.62:1**, stat cards and the overdue banner aren't tappable filters, and `_BillCard`'s unwrapped bottom `Row` (amount + date + `Spacer()` + member name) overflows horizontally on compact phones or scaled text.
- **Guideline**: WCAG 2.1 SC 1.4.3; Operate Mode Scanability & Density.
- **Recommendation**: Consolidate the 2×2 stat grid into a compact 2-column summary strip (making Overdue/Unpaid/Paid tappable status filters), replace raw badges with AA Light/Dark `StatusChip`, use `Wrap` or `Flexible` on `_BillCard`'s metadata row, apply `FontFeature.tabularFigures()` to currency values, and switch bill cards to a 2-column grid on tablets (`≥600dp`).
- **Suggested command**: `/impeccable layout`

#### [P1-6] `AddBillScreen` Has Zero Form Validation, Cramped 5-Tile Category Row, Giant Decorative Hero, and Destructive AppBar Home Button
- **Location**: `lib/features/bills/add_bill_screen.dart:90-94, 104-169, 187-257, 597-623`
- **Category**: Error Prevention / Card Density / Adaptivity
- **Impact**: `_formKey` is never validated in `_saveBill()`, allowing invalid `"."` amounts or empty `"Other"` custom categories. Five `_CategoryTile`s squeezed into a single `Row` (`~60dp` each) wrap/clip `"Electricity"` and `"Appliance"` on standard phones. A ~190dp decorative illustration pushes form inputs below the fold, and tapping the AppBar Home icon wipes unsaved edits silently.
- **Guideline**: Nielsen H3 & H5; Operate Mode Forms (`operate.md`).
- **Recommendation**: Wire `_formKey.currentState!.validate()` with real validators on Custom Category (required when `"Other"`), Amount (positive finite number when non-empty), and Deadline; replace the 5-column `Row` with a responsive `Wrap` or 3-column grid; remove the ~190dp decorative receipt hero (or reduce to a compact `48dp` header icon); remove the AppBar Home icon or guard unsaved changes with a discard dialog.
- **Suggested command**: `/impeccable harden`

#### [P1-7] `HouseholdCalendarView` Single Homogeneous Dot, Missing Bills, Fake `'4:00 PM'` Parcel Times, Mixed 12h/24h Clock & Root-List Navigation
- **Location**: `lib/features/calendar/household_calendar_view.dart:458-467, 481-509, 511-591, 639-693`
- **Category**: Scannability / Interactive Clarity / Consistency
- **Impact**: Every active date shows one identical `5×5` coral dot regardless of event category or count; household bill deadlines (`repo.bills`) are missing completely; all parcels hardcode `'4:00 PM'` ignoring `expectedArrival`; meet-ups print 24-hour time (`14:05`) beside 12-hour parcels (`4:00 PM`); event rows use raw `GestureDetector` (no ripple) and navigate to root module pages instead of the tapped record; out-of-month dates drop to **1.37:1 / 1.52:1** while silently changing months on tap.
- **Guideline**: Nielsen H1, H2, H4, H6; WCAG 2.1 SC 1.4.3.
- **Recommendation**: Render up to 3 color-coded category dots (Parcel coral, Task blue, Bill amber, Meetup teal) per day cell; include `repo.bills` deadlines in `_getEventsForDate` and filter chips; format all event times consistently with `DateFormat.jm()`; replace `GestureDetector` with `InkWell` navigating directly to detail routes (e.g., `/bill-detail?id=...`) where available; add a `"Schedule activity"` button to `_buildEmptyState()`.
- **Suggested command**: `/impeccable clarify`

#### [P1-8] `MaintenanceScreen` Pinned Bottom Button Omits `SafeArea`, Non-Scrollable 4-Tab Bar Wraps, and Modal Validation SnackBar Hides Behind Sheet
- **Location**: `lib/features/tasks/maintenance_screen.dart:64-80, 97-111, 281-288`
- **Category**: Platform Conformance / Adaptivity / Error Recovery
- **Impact**: `Positioned(bottom: 24)` places the primary `'Add a Task'` pill directly over the iOS home indicator / Android gesture bar on edge-to-edge devices. The 4-tab `TabBar` (`All`, `To Do`, `In Progress`, `Done`) wraps `'In Progress'` onto two lines on `<390dp` phones. Submitting an empty title inside `_showAddTaskModal` triggers a root `ScaffoldMessenger` SnackBar hidden *behind* the bottom sheet.
- **Guideline**: iOS Safe Area (`ios.md`); Android Edge-to-Edge Insets (`android.md`); Nielsen H9.
- **Recommendation**: Wrap the pinned CTA in `SafeArea` (or use `Scaffold.floatingActionButton` consistently across boards), set `isScrollable: true, tabAlignment: TabAlignment.start` on `TabBar` with live task counts (`To Do (3)`), and use a `Form` + `TextFormField` inline `validator` inside `_showAddTaskModal` instead of a hidden SnackBar.
- **Suggested command**: `/impeccable adapt`

#### [P1-9] Inconsistent Module Architecture & Creation Patterns Across Sibling Boards (`bills/` vs. `tasks/` vs. `parcels/`)
- **Location**: `bills_dashboard_screen.dart:54-62, 266-275`, `add_bill_screen.dart:540`, `bill_detail_screen.dart:340, 363`, `maintenance_screen.dart:97-111`, `parcels_screen.dart:58-65`
- **Category**: Consistency and Standards / Implementation Integrity
- **Impact**: `BillsDashboardScreen` shows **two duplicate "Add Bill" triggers** (AppBar `+` AND Extended FAB), `ParcelsScreen` shows only an unlabeled AppBar `+` icon, and `MaintenanceScreen` pins a full-width navy bottom pill. Meanwhile `bills/` bypasses `CasamaButton`, `CasamaTextField`, and `StatusChip` completely, uses emoji category icons where `tasks/` uses Material icons, and uses `withAlpha` instead of `withValues(alpha:)`.
- **Guideline**: Operate Mode Consistency (`operate.md`); Material 3 One Primary FAB (`android.md`).
- **Recommendation**: Standardize one primary creation pattern across all board screens (one M3 `FloatingActionButton.extended` with `SafeArea`, removing duplicate AppBar `+` buttons), and migrate `bills/` onto shared `CasamaButton`, `CasamaTextField`, `StatusChip`, and Material vector icons.
- **Suggested command**: `/impeccable distill`

#### [P1-10] `BillDetailScreen` Lacks Edit Action, Uses Unstyled Dark Dialogs & Fails Contrast on Amount / Mark Paid / Reopen
- **Location**: `lib/features/bills/bill_detail_screen.dart:64-93, 185, 274, 343, 372, 414, 461`
- **Category**: User Control / Accessibility / Theming
- **Impact**: Creators can Delete or Reopen a bill, but cannot edit a typo in the amount, deadline, or notes without deleting and recreating it. `Amount` (`#E87968` on white = **2.85:1**), `'Mark as Paid'` (white on `#388E3C` = **4.12:1**), `'Reopen Bill'` (`#F57C00` on `#FFF8F1` = **2.57:1**), and Reminder `'ON'` badge (**3.66:1**, light pastel in Dark Mode) all fail WCAG AA. Confirm dialogs use default unstyled `AlertDialog`s inheriting dark-mode black `TextTheme` defects.
- **Guideline**: WCAG 2.1 SC 1.4.3; Nielsen H3 (User Control).
- **Recommendation**: Add an `'Edit Bill'` option in the overflow menu (reusing `AddBillScreen(initialBill: bill)`), fix button/badge colors to AA Light/Dark tokens (`homeGreen #2E7D32` for Mark Paid = **5.13:1** with white; `#B54708` for Reopen = **4.95:1**), and theme dialog backgrounds/text explicitly via `CasamaTheme.dialogTheme`.
- **Suggested command**: `/impeccable colorize`

#### [P1-11] `ParcelsScreen` Add Modal Lacks Validation, Pre-Fills COD `'350'`, Leaks Controllers, and Breaks ChoiceChips in Dark Mode
- **Location**: `lib/features/parcels/parcels_screen.dart:145-146, 242-292, 315-317`
- **Category**: Error Prevention / Theming / Performance
- **Impact**: Pre-filling `codController = TextEditingController(text: '350')` risks accidental wrong COD amounts if a user forgets to overwrite it; typing invalid text silently saves `0.0` with no validation error; `codController` and `notesController` are never disposed; unselected `ChoiceChip`s hardcode `CasamaColors.ink` (`1.11:1` in Dark Mode) and wrap tightly inside `Expanded` on `<360dp` phones; AppBar `+` lacks a `tooltip`.
- **Guideline**: Nielsen H5 & H9; WCAG 2.1 SC 1.4.3.
- **Recommendation**: Move `_showAddParcelModal` into a `StatefulWidget` sheet that disposes controllers, start `codController` empty with `hintText: 'e.g., 350'` + `FilteringTextInputFormatter` + `Form` validator (`> 0` required for COD), replace `ChoiceChip` row with `SegmentedButton<ParcelPaymentType>`, wrap sheet in `SafeArea`, and add `tooltip: 'Add Parcel'` to AppBar `+`.
- **Suggested command**: `/impeccable harden`

---

### P2 — Minor (Fix in Next Pass)

#### [P2-1] `ChoreRouletteScreen` Performance & Listener Hygiene (`setState` Every Frame)
- **Location**: `lib/features/chore_roulette/chore_roulette_screen.dart:76-114, 247, 401-407`
- **Category**: Performance
- **Impact**: Calling `setState(() {})` inside `_animation.addListener` rebuilds the entire `Scaffold`, `AppBar`, mode selector, and bottom banner at 60–120 fps for 4 seconds on every spin, instead of isolating rotation inside `AnimatedBuilder`.
- **Recommendation**: Drive `Transform.rotate` with an `AnimatedBuilder(animation: _animation, child: CustomPaint(...))` so only the wheel layer repaints each frame, and keep the status listener registered once in `initState`.
- **Suggested command**: `/impeccable optimize`

#### [P2-2] `HouseholdCalendarView` Recomputes Full Event Lists 35–42× Per Build
- **Location**: `lib/features/calendar/household_calendar_view.dart:386, 412, 635-693`
- **Category**: Performance
- **Impact**: Every day cell in `_buildMonthGrid` calls `_hasEventsOnDate(repo, day)` which calls `_getEventsForDate` iterating over all parcels, tasks, and meet-ups and allocating a new list 35–42 times on every tap/setState.
- **Recommendation**: Build a single `Map<DateTime, List<_CalendarEventItem>>` index once per `build()` (or memoized on repository revision) and look up day cells in `O(1)`.
- **Suggested command**: `/impeccable optimize`

#### [P2-3] Undisposed Modal `TextEditingController`s & Uncached Network Avatars in `MaintenanceScreen` and `ParcelsScreen`
- **Location**: `maintenance_screen.dart:163, 454`, `parcels_screen.dart:145-146`
- **Category**: Performance / Consistency
- **Impact**: Three `TextEditingController`s allocated inside bottom-sheet helper functions are never disposed; `MaintenanceScreen` renders raw `Image.network` without `cacheWidth` instead of reusing `CasamaAvatar`.
- **Recommendation**: Extract `_AddTaskSheet` and `_AddParcelSheet` into `StatefulWidget`s disposing controllers in `dispose()`, and replace raw avatar containers with `CasamaAvatar`.
- **Suggested command**: `/impeccable optimize`

#### [P2-4] `ChoreRouletteScreen` Lacks Chore Customization & Excludes No Absent (`Out`) Roommates
- **Location**: `lib/features/chore_roulette/chore_roulette_screen.dart:32-59, 126-129, 303`
- **Category**: Flexibility / Match System & Real World
- **Impact**: The 6 chores are hardcoded and uneditable, `'Random Dormmate'` wording alienates apartment/family users, and random assignment picks from all `repo.members` including housemates currently marked `'Out'`.
- **Recommendation**: Rename `'Random Dormmate'` → `'Random Housemate'`, add a toggle `"Only housemates currently Home"`, and allow quick add/toggle of wheel chores (or pulling open household tasks directly onto the wheel).
- **Suggested command**: `/impeccable clarify`

#### [P2-5] Zero Tablet / Expanded-Width Adaptations Across All 5 Feature Modules
- **Location**: All 7 files (`maintenance_screen.dart`, `chore_roulette_screen.dart`, `bills_dashboard_screen.dart`, `add_bill_screen.dart`, `bill_detail_screen.dart`, `household_calendar_view.dart`, `parcels_screen.dart`)
- **Category**: Adaptivity
- **Impact**: On tablets (`≥600dp` / `≥840dp`), task lists, parcel cards, bill lists, and forms stretch edge-to-edge (`>700dp` wide inputs and cards), while `ChoreRouletteScreen` leaves wide empty margins instead of placing the chore legend/controls side-by-side with the wheel.
- **Recommendation**: Cap form/detail widths (`ConstrainedBox(maxWidth: 600)`) on `AddBillScreen` and `BillDetailScreen`, use 2-column grids on `BillsDashboardScreen`, `ParcelsScreen`, and `MaintenanceScreen` at `≥600dp`, and use a 2-pane layout on `ChoreRouletteScreen` in landscape/tablet.
- **Suggested command**: `/impeccable adapt`

#### [P2-6] Non-Tappable Empty States on `MaintenanceScreen`, `ParcelsScreen`, `BillsDashboardScreen`, and `HouseholdCalendarView`
- **Location**: `maintenance_screen.dart:118-142`, `parcels_screen.dart:100-127`, `bills_dashboard_screen.dart:207-244`, `household_calendar_view.dart:594-629`
- **Category**: Usability / Onboarding & Activation
- **Impact**: Empty states tell users `"Add a delivery..."` or `"Tap + to add your first household bill."` without embedding a direct action button (and `BillsDashboardScreen`'s filtered empty state like `'No Gas bills'` lacks a `"Clear Filter"` button).
- **Recommendation**: Add a clear inline CTA on every empty state (`Add Parcel`, `Add Bill` / `Clear Filter`, `Add Task`, `Add Activity for This Date`).
- **Suggested command**: `/impeccable onboard`

#### [P2-7] `BillsDashboardScreen` 10 Flat Horizontal Category Filter Chips Lack Counts & Cause Horizontal Scroll Fatigue
- **Location**: `lib/features/bills/bills_dashboard_screen.dart:177-199`
- **Category**: Cognitive Load / Scannability
- **Impact**: Displaying 10 filter chips (`All` + 9 categories) when the household only has 4 bills creates 6 dead-end filters that lead to empty screens, increasing scanning effort.
- **Recommendation**: Show status filters (`All`, `Overdue`, `Unpaid`, `Paid`) as primary quick chips with live counts, and dynamically show only populated categories (or group categories behind a compact filter dropdown).
- **Suggested command**: `/impeccable distill`

---

### P3 — Polish (Fix If Time Permits)

#### [P3-1] Decorative Emojis in Dialog Headings, Wheel Prompts & Mixed Emoji vs. Vector Category Icons
- **Location**: `maintenance_screen.dart:496`, `parcels_screen.dart:588`, `chore_roulette_screen.dart:148-149, 366-367, 474-475`, `bills_dashboard_screen.dart:449`, `add_bill_screen.dart:794, 894`, `bill_detail_screen.dart:120, 434`
- **Category**: Visual Polish / Consistency
- **Impact**: `bills/` uses platform-dependent emojis (`⚡`, `💧`, `🌐`) as primary category icons while `tasks/` and `parcels/` use Material vector icons, and celebration/prompt copy embeds 9 emojis.
- **Recommendation**: Map `BillCategory` to crisp Material rounded icons (`Icons.bolt_rounded`, `Icons.water_drop_rounded`, `Icons.wifi_rounded`, `Icons.home_rounded`) for visual consistency with the rest of the app and remove decorative heading emojis.
- **Suggested command**: `/impeccable polish`

#### [P3-2] Hardcoded iOS Back Arrow in `ChoreRouletteScreen` & Missing `tooltip` on `ParcelsScreen` AppBar `+`
- **Location**: `chore_roulette_screen.dart:254`, `parcels_screen.dart:58-65`
- **Category**: Platform Conformance / Accessibility
- **Impact**: `ChoreRouletteScreen` renders an iOS back chevron on Android; `ParcelsScreen`'s AppBar `+` `IconButton` has no tooltip or semantic label.
- **Recommendation**: Remove the manual `leading` override in `ChoreRouletteScreen` (inheriting Flutter's adaptive `BackButton`) and add `tooltip: 'Add Expected Parcel'` on `ParcelsScreen`.
- **Suggested command**: `/impeccable polish`

#### [P3-3] Missing Tabular Numerals (`FontFeature.tabularFigures()`) Across Currency & Date Lists
- **Location**: `bills_dashboard_screen.dart:93, 516`, `bill_detail_screen.dart:181`, `parcels_screen.dart:370`, `household_calendar_view.dart:443, 653`
- **Category**: Typography / Scannability
- **Impact**: Proportional digits cause peso amounts (`₱2,500.00`, `₱15,000.00`, `₱850.00`) and calendar grid dates to shift horizontally, contradicting `Casama_Project_Documentation.md` §4.2.
- **Recommendation**: Apply `fontFeatures: [FontFeature.tabularFigures()]` to all currency, date, and stat readouts via a shared `CasamaTheme` helper.
- **Suggested command**: `/impeccable typeset`

---

## Part 5: Cognitive Load, Emotional Journey & Persona Red Flags

### Cognitive Load Assessment (`critique-rubric.md`)
Evaluated across all 5 daily household feature modules (**5 / 8 failures — High cognitive load; critical fix needed**):
- [ ] **Single focus (FAIL)**: `BillsDashboardScreen` competes across 4 stat cards, an overdue banner, 10 category chips, AppBar `+`, and an Extended FAB; `AddBillScreen` opens with a 190dp decorative receipt graphic.
- [ ] **Chunking (FAIL)**: `BillsDashboardScreen` presents 10 flat horizontal category chips; `AddBillScreen` squeezes 5 tiles into one `Row`.
- [x] **Grouping**: Card containers in `ParcelsScreen`, `BillDetailScreen`, and `MaintenanceScreen` group individual records cleanly.
- [ ] **Visual hierarchy (FAIL)**: `MaintenanceScreen` hides completion behind an unbadged avatar; `ChoreRouletteScreen` hides chore identities behind low-contrast icon-only slices; `ParcelsScreen` omits buyer names; Dark Mode drops key controls to `1.01:1`.
- [x] **One thing at a time**: Modal creation sheets and `BillDetailScreen` isolate single record operations well.
- [ ] **Minimal choices (FAIL)**: `BillsDashboardScreen` offers 10 filter chips + 2 duplicate Add Bill triggers simultaneously.
- [ ] **Working memory (FAIL)**: Users must remember whose parcel is whose (missing `buyerName`), what each wheel icon means (no labels), which category maps to fake `'Bathroom'`/`'Kitchen'` labels, and add overdue bills mentally onto `'Total Due'`.
- [x] **Progressive disclosure**: `AddBillScreen`'s expandable `"More"` categories and collapsible `"Set Reminder"` card demonstrate solid progressive disclosure.

### Emotional Journey (Peak-End & Valleys)
- **Peak (Playful Warmth & Rewards)**: Good Kasama Points celebration dialogs (`+5 Points!`) and the playful concept of Chore Roulette make otherwise tedious household chores feel lighthearted and fair.
- **Valley 1 (Financial & Functional Trust Breaks)**: Seeing `'Total Due'` exclude an overdue `₱1,299` Wi-Fi bill, spinning Chore Roulette only for the popup to announce a *different* chore than the pointer landed on, and discovering Lazada parcels have **no `'I Got It'` button** turn delight into immediate distrust.
- **Valley 2 (Friction & Blind Taps)**: Trying to figure out how to mark a repair task done (only to discover the secret `32dp` avatar tap) or mis-tapping `24dp` radio buttons and `32dp` calendar arrows creates steady daily frustration.

### Persona Red Flags

#### 1. Distracted Mobile User: "Casey" *(Predefined — One-handed phone use, quick daily checks)*
- **Marking a Lazada delivery received (`ParcelsScreen`)**: Receives Alex's Lazada delivery from the guard, opens Parcels, and finds **no `'I Got It'` button**—only `'Mark Unavailable'` (which does nothing!).
- **Tapping tiny controls (`HouseholdCalendarView`, `MaintenanceScreen`, `AddBillScreen`)**: Repeatedly mis-taps `24dp` `'Today'`, `26dp` filter pills, `32dp` month arrows, `24dp` notification recipient radios, and `32dp` task avatars with one thumb.
- **Checking monthly bills (`BillsDashboardScreen`)**: Scrolls past ~340dp of stat cards and 10 chips just to inspect the actual bills, and taps the red `'1 overdue bill'` banner expecting it to filter—nothing happens.

#### 2. Accessibility-Dependent User: "Sam" *(Predefined — TalkBack/VoiceOver, low vision, Reduce Motion, 200% text scale)*
- **Reduce Motion hazard (`ChoreRouletteScreen`)**: With system Reduce Motion enabled, tapping Spin still launches a 4-second 5–8 revolution spinning wheel; 5 of 6 wheel icons fail 3.0:1 contrast (`1.41:1` yellow), and no chore names are readable or announced.
- **Invisible Dark Mode controls (`ParcelsScreen`, `MaintenanceScreen`, `ChoreRouletteScreen`)**: Cannot read Lazada/Other parcel titles (`1.01–1.16:1`), `'Mark Unavailable'` (`1.01:1`), Maintenance dark icons (`1.18–1.66:1`), or Roulette's pointer/toggle (`1.01:1`).
- **200% font scale overflows (`BillsDashboardScreen`, `AddBillScreen`, `MaintenanceScreen`)**: `_BillCard`'s bottom row overflows horizontally, `AddBillScreen`'s 5-column category row clips `'Electricity'`/`'Appliance'`, and `MaintenanceScreen`'s 4-tab bar wraps `'In Progress'`.

#### 3. Deliberate Stress Tester: "Riley" *(Predefined — Edge cases, unexpected inputs, fairness verification)*
- **Verifying Roulette fairness (`ChoreRouletteScreen`)**: Records 6 consecutive spins and immediately proves the pointer under 12 o'clock mismatches the winning chore dialog on **6 out of 6 spins**!
- **Testing invalid inputs (`AddBillScreen`, `ParcelsScreen`)**: Submits `AddBillScreen` with `"Other"` selected and blank Custom Category + `"."` amount — succeeds with zero validation! Enters `"abc"` in COD Amount on `ParcelsScreen` — silently creates a `COD • ₱0` parcel!
- **Testing status workflows (`MaintenanceScreen`, `BillDetailScreen`)**: Looks for how to put a task `'In Progress'` (impossible), accidentally completes a task by tapping its avatar (no undo!), and tries to edit a bill's wrong amount on `BillDetailScreen` (no Edit button!).

#### 4. Budget-Conscious Roommate Treasurer: "Carlo" *(Project-Specific — from `Casama_Project_Documentation.md` §1.5: young professional managing shared rent, Meralco, MWSS, and PLDT bills)*
- **Monthly bill reconciliation (`BillsDashboardScreen`, `HouseholdCalendarView`)**: Trusts `'Total Due: ₱3,350.00'` on the Bills dashboard and almost misses the overdue `₱1,299.00` PLDT Wi-Fi bill that was excluded from the sum; checks the Household Calendar for upcoming due dates and discovers **Bills don't appear on the calendar at all**; taps the Home icon on `AddBillScreen` after entering a utility bill note and loses his draft without warning.

#### 5. Dorm Delivery Coordinator: "Ria" *(Project-Specific — from `Casama_Project_Documentation.md` §1.5: dormmate who receives Shopee/Lazada packages and settles chores)*
- **Receiving roommates' deliveries (`ParcelsScreen`)**: Two Shopee boxes arrive at the dorm lobby; opens Parcels and can't tell **which roommate owns each box** because `buyerName` isn't shown on `_ParcelCard`, and can't tell what the `[Y] [A] [R]` circles mean.
- **Spinning chores & checking tasks (`ChoreRouletteScreen`, `MaintenanceScreen`)**: Spins Chore Roulette, adds `"Clean Bathroom"` to Maintenance, opens Maintenance, and sees `"Clean Bathroom"` labeled **`'Kitchen'`**—with no obvious button to mark it done!

---

## Part 6: Patterns & Systemic Issues

1. **Mockup-Fidelity Shortcuts Shipped as Logic**: `if (isShopee)` in `ParcelsScreen`, hardcoded `'Bathroom'`/`'Kitchen'` & 4 hardcoded assignees in `MaintenanceScreen`, hardcoded `'4:00 PM'` in `HouseholdCalendarView`, and non-persistent `'Mark Unavailable'` reveal static demo assumptions wired straight into production UI.
2. **Every Module Reinvented Its Own Visual & Interaction Dialect**: `bills/` doesn't use `CasamaButton`, `CasamaTextField`, `StatusChip`, or Material category icons; all 3 list boards use different primary-add placements; 13 raw `GestureDetector` widgets bypass native M3 touch targets, ripples, and semantics.
3. **Dark Mode Regressions Repeated in Every Feature**: 32 raw hexes and 32 static light tokens create `1.01:1–1.66:1` invisibility pockets and glaring white dialogs across all 5 modules.
4. **Touch Targets Sacrificed for Compact Cards**: `minimumSize: Size.zero`, `32×32` constraints, `24dp` custom radios, and `32dp` avatars compress vertical height at the direct expense of mobile tap accuracy and WCAG SC 2.5.8 compliance.
5. **Zero Accessibility & Reduce-Motion Engineering**: Across 4,549 lines, zero `Semantics` labels/roles and zero `disableAnimations` checks leave screen-reader and motion-sensitive users unsupported.

---

## Minor Observations & Questions to Consider

### Minor Observations
- `ParcelsScreen` (`parcels_screen.dart:370`) truncates COD decimals (`toStringAsFixed(0)`) while `HouseholdCalendarView` (`line 653`) and `Bills` show 2 decimals (`toStringAsFixed(2)`) — inconsistent peso precision.
- `BillsDashboardScreen` (`bills_dashboard_screen.dart:42`) computes `dueSoon` with `b.deadline.difference(DateTime.now()).inDays <= 7` without checking `>= 0` (relies implicitly on `overdue` status filtering).
- `BillDetailScreen` (`bill_detail_screen.dart:544-555`) right-aligns `_DetailRow` values cleanly, which works well for short fields—adding `maxLines` / `TextOverflow` guards will protect long notes/names.
- `MaintenanceScreen` (`maintenance_screen.dart:299-307`) and `ParcelsScreen` (`parcels_screen.dart:328-336`) show SnackBars after `Navigator.pop`, which works correctly (unlike line 282's empty-title validation SnackBar that fires *before* pop and hides behind the sheet!).

### Questions to Consider
1. **Unifying the 3 board list layouts**: Should `ParcelsScreen`, `MaintenanceScreen`, and `BillsDashboardScreen` share one standard board template (consistent AppBar, scrollable filter tabs with counts, single M3 Extended FAB, and AA `StatusChip`s)?
2. **Should Chore Roulette pull live open tasks from `MaintenanceScreen`?** Instead of spinning 6 hardcoded uneditable chores, letting housemates toggle between `"Open Household Tasks"` and `"Quick Preset Chores"` (with visible labels on the wheel) would connect Roulette directly to real household work.
3. **Should `HouseholdCalendarView` become the true unified household timeline (adding Bills)?** Adding bill deadlines alongside parcels, tasks, and meet-ups—and linking each tapped item directly to its detail view—makes the Calendar far more valuable than 4 separate checks.
4. **How much detail belongs directly on `_TaskCard` and `_ParcelCard`?** Would you prefer keeping cards scannable (2-row metadata: title + owner/assignee + due/arrival + status chip + one explicit 48dp CTA) and moving notes/history/edit into a dedicated tap-to-open detail sheet matching `BillDetailScreen`?

---

## Recommended Actions (Priority Order)

1. **[P0] `/impeccable harden`**: Fix the 4 critical functional/clarity defects immediately: remove `if (isShopee)` branching & wire real availability toggling on `ParcelsScreen`; replace `MaintenanceScreen`'s `32dp` avatar-tap completion with explicit `48dp` status controls (`Open`/`In Progress`/`Done` + undo); fix `ChoreRouletteScreen`'s wheel landing trigonometry (with unit tests for all 6 slices); include overdue bills in `BillsDashboardScreen`'s `'Unpaid'` & `'Total Due'` totals; wire real form validation on `AddBillScreen` & `ParcelsScreen`; and add full `Semantics` across all 7 files.
2. **[P0] `/impeccable colorize`**: Eliminate all 32 raw hexes and 32 static light tokens breaking Dark Mode (`1.01:1–1.66:1`) across `ParcelsScreen`, `MaintenanceScreen`, `ChoreRouletteScreen`, `Bills`, and `HouseholdCalendarView`; fix AA contrast on Bills stat cards, status badges, Reopen button, and Chore Roulette wheel slices; theme celebration & confirmation dialogs.
3. **[P1] `/impeccable adapt`**: Raise every sub-minimum touch target (`24–44dp`) to `≥48dp` across all 5 modules (calendar controls/cells, radio rows, filter chips, parcel/task actions, roulette toggles); make `ChoreRouletteScreen` scrollable and honor `MediaQuery.disableAnimationsOf`; fix `_BillCard` bottom-row overflow, `AddBillScreen` 5-tile wrapping, `MaintenanceScreen` `SafeArea` & scrollable `TabBar`, Calendar week strip `Expanded` cells, and add `≥600dp` tablet layouts.
4. **[P1] `/impeccable clarify`**: Add `buyerName`, availability labels, and conflict warnings to `_ParcelCard`; replace hardcoded `'Bathroom'`/`'Kitchen'` subtitles on `_TaskCard` with real category, assignee, and due date; add visible chore labels/legend to `ChoreRouletteScreen` (and `"Random Housemate"` + Home-only filter); integrate Bills & real formatted arrival times into `HouseholdCalendarView` with deep-link item navigation.
5. **[P1] `/impeccable layout`**: Reduce `BillsDashboardScreen` above-the-fold density (compact tappable summary strip + status filters), remove the ~190dp decorative hero from `AddBillScreen`, and add Edit capability to `BillDetailScreen`.
6. **[P1] `/impeccable distill`**: Standardize one primary creation FAB across `Maintenance`, `Parcels`, and `Bills` (removing duplicate AppBar `+` on Bills); migrate `bills/` onto shared `CasamaButton`, `CasamaTextField`, and `StatusChip`; trim Bills' 10 flat category chips; remove `AddBillScreen`'s destructive AppBar Home icon.
7. **[P2] `/impeccable optimize`**: Isolate `ChoreRouletteScreen` rotation in `AnimatedBuilder`, pre-index `HouseholdCalendarView` events per month in `O(1)`, dispose modal `TextEditingController`s properly, and reuse `CasamaAvatar` in `MaintenanceScreen`.
8. **[P2] `/impeccable onboard`**: Add inline creation / `"Clear Filter"` CTAs to all empty states across Maintenance, Parcels, Bills, and Calendar.
9. **[P2–P3] `/impeccable typeset` & `/impeccable polish`**: Apply tabular numerals to currency/dates, migrate `BillCategory` icons from emojis to Material rounded vectors, remove decorative heading emojis, replace hardcoded iOS back arrow in Roulette, and add missing AppBar tooltips.

> You can ask me to run these one at a time, all at once, or in any order you prefer.
>
> Re-run `/impeccable audit` and `/impeccable critique` after fixes to see your scores improve.
