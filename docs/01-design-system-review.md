Method: design review only (detector not applicable, native platform)

# Casama Design System Audit & UX Critique

> **Scope**: `lib/core/constants/` (`colors.dart`, `dimensions.dart`), `lib/core/theme/` (`app_theme.dart`, `theme_provider.dart`), and `lib/shared/widgets/` (`avatar_chip.dart`, `casama_avatar.dart`, `casama_button.dart`, `casama_text_field.dart`, `cas_mascot_view.dart`, `invite_housemate_sheet.dart`, `status_chip.dart`) — plus cross-codebase adoption telemetry across all 50 Dart files in `lib/` and visual/binary inspection of mascot assets in `assets/images/cas/`.
>
> **Platform & Mode**: Flutter cross-platform mobile application (Android-first Material 3 + iOS adaptive) · **Operate** surface mode · Evaluated against **WCAG 2.1 AA**, **Material Design 3**, and **Apple Human Interface Guidelines (HIG)**.
>
> **Run Notes**: The `impeccable` CLI engine was unavailable in this environment (no network/cache write access), so project context was loaded directly from `README.md`, `Casama_Project_Documentation.md`, `pubspec.yaml`, and source files; automated `.impeccable/` snapshot persistence (`audit-storage`/`critique-storage`) was skipped. No live emulator/simulator screenshots were captured; all WCAG 2.1 contrast ratios were computed mathematically from source sRGB hex values, and mascot PNGs were inspected directly.

---

## Executive Summary

Casama's design system has an appealing, warm **Light Mode** visual identity—anchored by Warm Cream (`#FFF8F1`), Midnight Navy (`#1C2E4A`), Deep Teal (`#3F7772`), Primary Coral (`#E87968`), crisp 1px-bordered flat cards, and Cas the Owl. However, the underlying token architecture, Dark Mode implementation, accessibility engineering, and component governance have severe structural defects that fail production quality bars:

- **Native Technical Audit Score**: **7 / 20** (**Poor** — major overhaul needed)
- **UX Design Critique Score**: **16 / 36** (**44% · Poor** — 9 of 10 Nielsen heuristics scored; H10 `n/a`)
- **Total Issues Found**: **23** (**3 P0 Blocking**, **11 P1 Major**, **6 P2 Minor**, **3 P3 Polish**)

### Top 5 Critical Issues
1. **[P0] Dark Mode Text Inputs Are Invisible (`1.11:1` contrast)**: `CasamaTextField` hardcodes `CasamaColors.ink` (`#1C2E4A`) for labels and typed input text against `darkSurface` (`#18263D`) and `darkCard` (`#1E2F4A`, `1.01:1`).
2. **[P0] 7 of 15 Dark Mode Material 3 Text Styles Render Black Ink**: `CasamaTheme.darkTheme` calls `GoogleFonts.interTextTheme()` without `ThemeData.dark().textTheme`, leaving 7 text roles stuck in light-mode black text.
3. **[P0] Zero Accessibility Semantics Anywhere in the System**: `Semantics`, `ExcludeSemantics`, `MergeSemantics`, `MediaQuery.disableAnimationsOf`, and `textScaler` appear **0 times** across all 11 target files and all 50 files in `lib/`.
4. **[P1] Primary Brand Accent (`primaryCoral #E87968`) Fails WCAG AA Everywhere in Light Mode**: White on coral is **2.85:1** (fails both 4.5:1 normal and 3.0:1 large/UI); coral on cream is **2.71:1**; disabled primary buttons drop to **1.71:1**.
5. **[P1] Systemic Token Drift & Component Breakage**: `Theme.of(context).textTheme` has **0 uses** across `lib/` (vs **508** raw `TextStyle(` declarations across **17** font sizes); `StatusChip` hardcodes 18 raw hexes with 6/11 failing AA contrast and zero Dark Mode; `CasamaButton` breaks in Dark Mode and silently drops borders on **100%** of `secondary` pill buttons; all 9 mascot PNGs are opaque cream RGB squares (`colorType=2`) with visible mockup crop artifacts.

---

## Part 1: Native Technical Audit (`audit.native.md`)

### Audit Health Score

| # | Dimension | Score | Key Finding |
|---|-----------|-------|-------------|
| 1 | Accessibility | **1 / 4** | 0 `Semantics` hooks across `lib/`; `primaryCoral` (2.85:1), `textMuted` (2.24:1), 6/11 `StatusChip`s, and Dark `CasamaTextField` (1.11:1) fail WCAG AA; `40dp` Close button violates touch target floors |
| 2 | Performance | **2 / 4** | Synchronous `base64Decode` inside `CasamaAvatar.build()`; missing `cacheWidth`/`cacheHeight` on images; uncached `ThemeData` getters calling `GoogleFonts.interTextTheme()` with no bundled offline fonts |
| 3 | Appearance & Theming | **1 / 4** | Dark Mode broken in `CasamaTextField`, `CasamaTheme.darkTheme` (7 black text styles), `CasamaButton`, `StatusChip`, `CasMascotView`, and `invite_housemate_sheet`; conflicting `ThemeData` vs `CasamaThemeContext` tokens; 0 `.textTheme` uses |
| 4 | Platform Conformance | **2 / 4** | Custom `CasamaButton` bypasses M3 buttons & drops pill borders; 10+ missing M3 component themes; `invite_housemate_sheet` snackbar renders behind modal; Share icon triggers clipboard copy; `10pt` chip breaks iOS 11pt floor |
| 5 | Adaptivity | **1 / 4** | Zero breakpoint/max-width tokens despite §4.6 spec; non-scrollable `invite_housemate_sheet` overflows in landscape/font scale; fixed-height `CasamaButton` and unconstrained `Row`s clip scaled text |
| **Total** | | **7 / 20** | **Poor (major overhaul)** |

*Rating bands: 18–20 Excellent · 14–17 Good · 10–13 Acceptable · 6–9 Poor · 0–5 Critical.*

### Platform Conformance Verdict

**FAIL — Partially native Flutter shell undermined by off-spec custom primitives and unfinished Dark Mode.**

Casama correctly enables `useMaterial3: true`, uses native `TextFormField` and `showModalBottomSheet`, and applies `SafeArea` in `invite_housemate_sheet.dart`. However, a fluent Android or iOS user immediately encounters platform friction:
- **Reinvented button primitive**: `CasamaButton` wraps raw `Material` + `InkWell` instead of styling M3 `FilledButton` / `OutlinedButton` / `TextButton`, losing focus rings, platform disabled-foreground dimming, button semantics, and—due to a conditional bug—dropping borders entirely on every `secondary` pill button (`auth_screen.dart:512`, `login_screen.dart:282`). Meanwhile, the codebase mixes 4 separate button APIs (`CasamaButton` 65×, `OutlinedButton` 40×, `TextButton` 32×, `ElevatedButton` 26×).
- **Incomplete Material 3 theme surface**: `CasamaTheme` omits `textButtonTheme`, `filledButtonTheme`, `snackBarTheme`, `bottomSheetTheme`, `dialogTheme`, `chipTheme`, `navigationBarTheme`, `switchTheme`, `dividerTheme`, and `listTileTheme`, forcing feature screens into 140 raw `Color(0x...)` literals across 24 files.
- **Off-platform modal & feedback patterns**: `invite_housemate_sheet.dart` hand-rolls a `40×4` drag handle instead of M3 `showDragHandle: true`, pairs `Icons.share_rounded` with clipboard copy rather than the native OS share sheet, places an emoji (`🏡`) inside a modal title, and fires a root `ScaffoldMessenger` snackbar that appears *behind* the open modal sheet.
- **iOS/Android floor violations**: `AvatarChip` passes `fontSize: 10` to `StatusChip` (below iOS HIG's `11pt` floor and Material's `11sp` `labelSmall`), `invite_housemate_sheet.dart` sets `height: 40` on its Close button (below iOS `44pt` and Android `48dp`), and `app_settings_screen.dart` uses `Icons.arrow_back_ios_new` on Android while `appBarTheme` hardcodes `centerTitle: true` everywhere.

---

## Part 2: UX Design Critique (`critique.md` & `critique-rubric.md`)

### Design Health Score (Nielsen's 10 Usability Heuristics)

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | **2 / 4** | Button spinner & status chips exist, but disabled `ghost` buttons look enabled, `CasamaAvatar` has no network loading state, copy SnackBar renders behind modal sheet, and screen readers receive zero status announcements |
| 2 | Match System / Real World | **2 / 4** | Warm household vocabulary ("Home"/"Out", "COD") fits well, but Share icon executes clipboard copy, `ivory` token is blue-gray (`#BDC4D4`), and cropped mockup text ("Action") appears in `cas_chatting.png` |
| 3 | User Control and Freedom | **2 / 4** | Sheet offers dismiss + Close, but `ThemeNotifier` overrides OS dark mode with forced `ThemeMode.light`, `toggleTheme()` silently no-ops from `system`, and `CasamaTextField` lacks built-in password peek/clear controls |
| 4 | Consistency and Standards | **1 / 4** | 0 `.textTheme` uses vs 508 raw `TextStyle`s (17 sizes); dual conflicting Dark Mode token sources; 4 competing button APIs; 18 raw hexes inside `StatusChip`; 31 raw spacing/radius literals inside `lib/shared/widgets/` |
| 5 | Error Prevention | **2 / 4** | `validator` and button double-tap lock exist, but `CasamaTextField` lacks `inputFormatters`, `maxLength`, `enabled`, and `autovalidateMode`; `CasamaButton` lacks a `destructive` variant; `AvatarChip` blanks on leading spaces |
| 6 | Recognition Rather Than Recall | **2 / 4** | Persistent top labels above inputs aid scanability in Light Mode, but vanish in Dark Mode (`1.01–1.28:1`), lack semantic association with inputs, lack `helperText`, and `StatusChip` omits default icons |
| 7 | Flexibility and Efficiency | **1 / 4** | `CasamaTextField` omits `textInputAction`, `focusNode`, `onFieldSubmitted`, and `autofillHints` (breaking keyboard Next/Done and OS autofill); `CasamaButton` lacks size tokens, forcing ad-hoc `height: 40/44/46/52` overrides |
| 8 | Aesthetic and Minimalist Design | **2 / 4** | Warm cream/navy/teal/coral Light Mode foundation is cohesive, but undercut by opaque beige mascot rectangles with clipped icons, low-contrast coral, stark white buttons & pastel pills in Dark Mode, and heading emojis |
| 9 | Error Recovery | **2 / 4** | Avatar/mascot `errorBuilder` fallbacks and `errorBorder` exist, but missing `focusedErrorBorder` masks invalid inputs on focus, validation errors have no `errorMaxLines`, and `ThemeNotifier` swallows storage failures silently |
| 10 | Help and Documentation | **n/a** | Token & shared primitive layer; in-app help centers live at screen/feature level (inline `helperText`/tooltips scored under H6 & H9) |
| **Total** | | **16 / 36** | **Poor (44%)** |

*Renormalized rating bands (9 applicable heuristics, max 36): ≥90% (33–36) Excellent · 70–89% (26–32) Good · 50–69% (18–25) Acceptable · 30–49% (11–17) Poor · <30% (0–10) Critical.*

### Design Specificity Verdict

- **LLM Assessment**: Casama's *intended* brand language is genuinely authored for shared-living warmth—not generic SaaS boilerplate. Pairing Filipino-inspired "Casa + Kasama" hospitality with Warm Cream (`#FFF8F1`), Midnight Navy (`#1C2E4A`), Deep Teal (`#3F7772`), Warm Coral (`#E87968`), and an expressive owl companion (`CasMascotView`) establishes an immediately recognizable domestic tone. However, **implementation discipline erodes that character**: the dark palette collapses into generic Tailwind Slate (`#0F1A2B`, `#94A3B8`, `#64748B`) stripped of Casama's warm teal identity (`deepTeal` disappears from `ColorScheme.dark`), `CasamaTheme` fails to carry the brand font (`Inter`) into component themes or screen typography, `StatusChip` relies on unadapted Material 2014 palette defaults (`#E8F5E9`, `#FFEBEE`, `#E3F2FD`), and opaque, poorly cropped mascot PNGs make the brand's strongest differentiator look pasted-on in Dark Mode.
- **Deterministic Scan**: `not applicable (native platform)`

### Overall Impression

Casama's design system looks like a promising Light-Mode prototype whose Dark Mode, accessibility layer, and token governance were retrofitted halfway and never unified. The single biggest opportunity is **turning `lib/core/` into a true single source of truth**: elevate `CasamaColors` into an AA-compliant `ThemeExtension` (with dark variants for every semantic and chip role), repair `CasamaTheme`'s `TextTheme` and M3 component themes, and refactor the 7 shared widgets to consume `Theme.of(context)` with proper semantics and responsive constraints. Fixing those 11 files immediately uplifts all 30+ feature screens.

### What's Working (Positive Findings)
1. **Warm, approachable Light Mode brand direction**: Warm Cream (`#FFF8F1`) + Midnight Navy (`#1C2E4A`, **12.96:1**) + Deep Teal (`#3F7772`, **5.13:1** with white) creates a distinct, calm household aesthetic far warmer than generic sterile-white roommate/finance apps.
2. **Defensive rendering & ergonomics in key primitives**: `CasamaAvatar` and `CasMascotView` both include safe `errorBuilder` fallbacks (initials circle and owl fallback) so broken URLs or missing assets never crash layout; `CasamaButton` guards double-submissions via `onTap: isLoading ? null : onPressed`; `CasamaTextField` renders persistent labels above inputs rather than vanishing placeholder-only labels.
3. **Pragmatic DX & persistence foundations**: `CasamaSpacing` pre-allocates `const BorderRadius` tokens (`roundedSm`–`roundedPill`) avoiding repeated allocations; `ThemeNotifier` cleanly persists `light`/`dark`/`system` choices via `SharedPreferences` with synchronous override injection in `main.dart`.

---

## Part 3: Deep-Dive Pillar Evaluations

### Pillar 1: Color Palette & Theming
*Files: `lib/core/constants/colors.dart`, `lib/core/theme/app_theme.dart`, `lib/core/theme/theme_provider.dart`*

#### 1.1 WCAG 2.1 Contrast Audit Matrix (Verified sRGB Calculations)

| Context / Pairing | Foreground | Background | Ratio | WCAG AA Normal (4.5:1) | WCAG AA Large / UI (3.0:1) |
|---|---|---|---|---|---|
| Primary button (`CasamaButton.primary`, `ElevatedButton`) | `#FFFFFF` | `#E87968` (`primaryCoral`) | **2.85:1** | **FAIL** | **FAIL** |
| Disabled primary button (Light, 50% alpha on `warmCream`) | `#FFFFFF` | `#F4B8AC` (blended) | **1.71:1** | **FAIL** | **FAIL** |
| Disabled primary button (Light, 50% alpha on `white`) | `#FFFFFF` | `#F4BCB4` (blended) | **1.65:1** | **FAIL** | **FAIL** |
| Ghost button / coral icon on `warmCream` | `#E87968` | `#FFF8F1` | **2.71:1** | **FAIL** | **FAIL** |
| Ghost button / coral icon on `white` | `#E87968` | `#FFFFFF` | **2.85:1** | **FAIL** | **FAIL** |
| Ghost button / coral icon on `darkSurface` | `#E87968` | `#18263D` | **5.32:1** | PASS | PASS |
| Primary text (`ink` on `warmCream`) | `#1C2E4A` | `#FFF8F1` | **12.96:1** | PASS (AAA) | PASS |
| Primary text (`ink` on `white`) | `#1C2E4A` | `#FFFFFF` | **13.64:1** | PASS (AAA) | PASS |
| Secondary text (`textSecondary` on `warmCream`) | `#607078` | `#FFF8F1` | **4.88:1** | PASS | PASS |
| Secondary text (`textSecondary` on `white`) | `#607078` | `#FFFFFF` | **5.14:1** | PASS | PASS |
| Muted text (`textMuted` on `warmCream`) | `#9EABB2` | `#FFF8F1` | **2.24:1** | **FAIL** | **FAIL** |
| Input `hintStyle` (`textMuted` on `white`) | `#9EABB2` | `#FFFFFF` | **2.35:1** | **FAIL** | **FAIL** |
| Invite sheet label (`textMuted` on `softNeutral`) | `#9EABB2` | `#F3F5F4` | **2.15:1** | **FAIL** | **FAIL** |
| Light input/card border (`borderGray` on `white`) | `#DCE3E0` | `#FFFFFF` | **1.30:1** | — | **FAIL** (1.4.11) |
| Dark primary text (`darkText` on `darkBackground` / `darkCard`) | `#F1F5F9` | `#0F1A2B` / `#1E2F4A` | **15.93:1 / 12.28:1** | PASS (AAA) | PASS |
| Dark secondary text (`darkTextSecondary` on `darkCard`) | `#94A3B8` | `#1E2F4A` | **5.25:1** | PASS | PASS |
| Dark muted text (`darkTextMuted` on `darkBackground` / `darkSurface` / `darkCard`) | `#64748B` | `#0F1A2B` / `#18263D` / `#1E2F4A` | **3.67 / 3.19 / 2.83:1** | **FAIL** | PASS / PASS / **FAIL** |
| Dark input/card border (`darkBorder` on `darkSurface`) | `#2C4164` | `#18263D` | **1.48:1** | — | **FAIL** (1.4.11) |
| **Broken Dark `CasamaTextField` input text** (`ink` on `darkSurface`) | `#1C2E4A` | `#18263D` | **1.11:1** | **FAIL (P0)** | **FAIL (P0)** |
| **Broken Dark `CasamaTextField` label** (`ink` on `darkBackground` / `darkCard`) | `#1C2E4A` | `#0F1A2B` / `#1E2F4A` | **1.28:1 / 1.01:1** | **FAIL (P0)** | **FAIL (P0)** |
| **Broken Dark `CasamaTextField` prefixIcon** (`textSecondary` on `darkSurface`) | `#607078` | `#18263D` | **2.95:1** | **FAIL** | **FAIL** |
| **Broken Dark `CasamaButton.navy` silhouette** (`midnightNavy` on `darkCard` / `darkSurface`) | `#1C2E4A` | `#1E2F4A` / `#18263D` | **1.01:1 / 1.11:1** | — | **FAIL** |
| `StatusChip`: `home` / `paid` / `low` / `returned` | `#2E7D32` | `#E8F5E9` | **4.56:1** | PASS | PASS |
| `StatusChip`: `out` | `#757575` | `#EEEEEE` | **3.97:1** | **FAIL** | PASS |
| `StatusChip`: `cod` | `#E87968` | `#FFECE8` | **2.50:1** | **FAIL** | **FAIL** |
| `StatusChip`: `urgent` / `open` | `#D32F2F` | `#FFEBEE` | **4.36:1** | **FAIL** | PASS |
| `StatusChip`: `medium` | `#E65100` | `#FFF3E0` | **3.46:1** | **FAIL** | PASS |
| `StatusChip`: `toBuy` | `#1976D2` | `#E3F2FD` | **4.03:1** | **FAIL** | PASS |
| `StatusChip`: `unclaimed` | `#F57F17` | `#FFF8E1` | **2.49:1** | **FAIL** | **FAIL** |
| Semantic `successGreen` on `successBg` (`colors.dart`) | `#388E3C` | `#E8F5E9` | **3.66:1** | **FAIL** | PASS |
| Semantic `warningOrange` on `warningBg` / `white` | `#F57C00` | `#FFF3E0` / `#FFFFFF` | **2.47:1 / 2.70:1** | **FAIL** | **FAIL** |
| Accent `warmGold` on `warmCream` / `white` | `#F4B544` | `#FFF8F1` / `#FFFFFF` | **1.73:1 / 1.82:1** | **FAIL** | **FAIL** |
| Secondary brand (`white` on `deepTeal`) | `#FFFFFF` | `#3F7772` | **5.13:1** | PASS | PASS |
| `AvatarChip` label if placed on light surface (`white` on `warmCream`) | `#FFFFFF` | `#FFF8F1` | **1.05:1** | **FAIL** | **FAIL** |

#### 1.2 Architectural & Token Governance Findings
- **Split-brain Dark Mode definitions**: `CasamaTheme.darkTheme` (`app_theme.dart:158-256`) uses `Colors.white` (`#FFFFFF`), `CasamaColors.ivory` (`#BDC4D4`), `CasamaColors.darkSurface` (`#18263D`) for `cardTheme.color`, and raw `Color(0xFFE57373)` for errors—whereas `CasamaThemeContext` (`colors.dart:69-95`) exposes `darkText` (`#F1F5F9`), `darkTextSecondary` (`#94A3B8`), `darkTextMuted` (`#64748B`), and `darkCard` (`#1E2F4A`) for `context.cardColor`. Screens calling `Theme.of(context).cardColor` (`app_settings_screen.dart:30`) render a different surface shade than screens calling `context.cardColor` (24 files).
- **Incomplete `CasamaThemeContext` coverage**: Only 4 of 6 quick-action tiles have extension getters (`tileParcelsColor`, `tileMaintenanceColor`, `tileLostFoundColor`, `tileChatColor`); `tileBills`/`darkTileBills` and `tileChoreRoulette`/`darkTileChoreRoulette` (lines 61–65) are omitted. None of the semantic tokens (`success`, `warning`, `error`, `home`, `out`) have dark variants or context getters.
- **Misleading naming & duplicate aliases**:
  - `ivory` (`#BDC4D4`, line 10) is cool slate-blue, not ivory (`#FFFFF0`).
  - Redundant duplicates: `ink == midnightNavy` (`#1C2E4A` — diverging from `Casama_Project_Documentation.md` §4.3's `#263238`), `cardSurface == white` (`#FFFFFF`), `homeBg == successBg` (`#E8F5E9`), `tileBills == warningBg` (`#FFF3E0`), `tileBillsIcon == warningOrange` (`#F57C00`). Meanwhile `homeGreen` (`#2E7D32`, passes AA) and `successGreen` (`#388E3C`, fails AA on `successBg`) drift needlessly.
- **No `ThemeExtension` & no Material You Dynamic Color**: `CasamaThemeContext` switches statically via `isDark ? a : b`, so `AnimatedTheme` cannot interpolate custom tokens smoothly during theme transitions. On Android 12+, Material 3 tonal surface container roles (`surfaceContainerLowest`–`Highest`, `outline`, `outlineVariant`) are absent.
- **`ThemeNotifier` state defects** (`theme_provider.dart:9, 44-47`): Defaults to `ThemeMode.light` instead of `ThemeMode.system` (ignoring user OS preference on first launch); `toggleTheme()` evaluates `state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light`, so calling it when `state == ThemeMode.system` on a light device sets `ThemeMode.light` (a silent no-op).

#### 1.3 Verified Accessible Token Remediation Proposals

| Role | Current Token | Recommended Light | Verified Light Ratio | Recommended Dark | Verified Dark Ratio |
|---|---|---|---|---|---|
| Brand Primary (text/filled button) | `#E87968` | `#C44938` (or `#BF4433` for COD chip) | `4.82:1` white-on-fill · `4.58:1` on cream (`#BF4433`: `4.50:1` on `#FFECE8`) | `#E87968` with `#0F1A2B` `onPrimary` (or `#1C2E4A`) | `6.12:1` (`#0F1A2B` on coral) · `5.32:1` coral on `darkSurface` |
| Brand Secondary | `#3F7772` / `#52677D` (dark) | `#3F7772` (`deepTeal`) | `5.13:1` white-on-teal | `#66ACA5` (dark-adapted teal) | `5.79:1` on `darkSurface` |
| Muted Text / Input Hints | `#9EABB2` / `#64748B` | `#5E6E76` | `5.03:1` on cream · `4.83:1` on `softNeutral` | `#8E9EB3` | `4.93:1` on `darkCard` |
| Interactive Input Border (WCAG 1.4.11) | `#DCE3E0` / `#2C4164` | `#7F8E96` (keep `#DCE3E0` for decorative card dividers only) | `3.21:1` on cream · `3.38:1` on white | `#6C85AC` (keep `#2C4164` for decorative dividers only) | `3.58:1` on `darkCard` |
| Chip: Success (`home`/`paid`/`low`/`returned`) | `#2E7D32` on `#E8F5E9` | `#2E7D32` on `#E8F5E9` (keep; unify `successGreen`) | `4.56:1` | `#81C784` on `#1B3626` | `6.51:1` |
| Chip: Neutral (`out`) | `#757575` on `#EEEEEE` | `#595959` on `#EEEEEE` | `6.04:1` | `#CBD5E1` on `#2A3548` | `8.31:1` |
| Chip: Brand/COD (`cod`) | `#E87968` on `#FFECE8` | `#BF4433` on `#FFECE8` | `4.50:1` | `#F59888` on `#3D2224` | `6.70:1` |
| Chip: Danger (`urgent`/`open`) | `#D32F2F` on `#FFEBEE` | `#C62828` on `#FFEBEE` | `4.92:1` | `#EF9A9A` on `#3D1F25` | `6.87:1` |
| Chip: Warning (`medium`) | `#E65100` on `#FFF3E0` | `#B54708` on `#FFF3E0` | `4.95:1` | `#FFB74D` on `#3B2B17` | `7.86:1` |
| Chip: Info (`toBuy`) | `#1976D2` on `#E3F2FD` | `#1565C0` on `#E3F2FD` | `5.03:1` | `#90CAF9` on `#1B2E45` | `7.88:1` |
| Chip: Amber (`unclaimed`) | `#F57F17` on `#FFF8E1` | `#8D5500` on `#FFF8E1` | `5.76:1` | `#FFD54F` on `#3A3016` | `9.22:1` |

---

### Pillar 2: Typography
*Files: `lib/core/theme/app_theme.dart`, `pubspec.yaml`, cross-lib adoption*

- **Critical Dark Mode `TextTheme` Defect** (`app_theme.dart:149, 167-205`): `GoogleFonts.interTextTheme()` defaults to `Typography.blackMountainView` (black text) when no `TextTheme` argument is supplied. Because `darkTheme` overrides only 8 of the 15 Material 3 roles, `displayMedium`, `displaySmall`, `headlineLarge`, `headlineSmall`, `titleSmall`, `labelMedium`, and `labelSmall` remain **black ink on dark surfaces** (`#0F1A2B`/`#18263D`). Passing `GoogleFonts.interTextTheme(ThemeData.dark().textTheme)` fixes the baseline immediately.
- **Zero `TextTheme` Adoption Across the Entire Codebase**: Static analysis across all 50 files in `lib/` shows **0** calls to `.textTheme` versus **508** raw `TextStyle(` declarations (including **22** inside `app_theme.dart` and `lib/shared/widgets/`). This has created **17 ad-hoc font sizes** (`9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 20, 22, 24, 26, 28, 32, 48`), including sub-floor sizes `9pt` (2 uses) and `10pt` (16 uses, including `AvatarChip`'s `StatusChip`).
- **Broken Font Family Inheritance Inside `app_theme.dart` Itself**: `appBarTheme.titleTextStyle`, `inputDecorationTheme.hintStyle`/`labelStyle`, `elevatedButtonTheme.textStyle`, and `outlinedButtonTheme.textStyle` (10 total `const TextStyle(...)` declarations in `app_theme.dart`) omit `fontFamily`, rendering platform Roboto/SF Pro instead of `Inter`.
- **Uncached Runtime Font Fetching**: `pubspec.yaml` declares `google_fonts: ^6.2.1` with **zero bundled font files**. On offline first launch or slow connections, `Inter` fails to fetch and silently swaps or falls back, and calling `CasamaTheme.lightTheme` / `darkTheme` as computed getters re-invokes `GoogleFonts.interTextTheme()` on every rebuild.
- **Missing Typographic Craft**: None of the `textTheme` roles specify explicit `height` (line-height) or `letterSpacing`, nor `fontFeatures: [FontFeature.tabularFigures()]` for currency (COD amounts, bills), dates, or Good Kasama points as explicitly required by `Casama_Project_Documentation.md` §4.2.

---

### Pillar 3: Spacing, Radii & Layout Tokens
*File: `lib/core/constants/dimensions.dart`*

- **Documentation vs Grid Mismatch**: Line 3 documents `(8-point grid)`, while `sm = 12.0` and `lg = 20.0` follow a 4pt step scale (valid for mobile UI—just update the doc comment to `4pt base / 8pt rhythm`).
- **Dead / Unused Tokens**: **8 of 19** constants in `CasamaSpacing` have **0 external usages** across all 50 Dart files: `xxs` (`4.0`), `huge` (`40.0`), `radiusSm`–`radiusPill` (5 raw doubles), and—most critically—**`minTouchTarget = 48.0`**!
- **Bypassed by the Design System's Own Widgets**: Inside `lib/shared/widgets/`, raw spacing/radius literals outnumber `CasamaSpacing` tokens more than 5-to-1:
  - `invite_housemate_sheet.dart`: 12 raw `SizedBox`, 4 raw `EdgeInsets`, 2 raw `BorderRadius` (`Radius.circular(24)` instead of `radiusXl`) vs only 2 `CasamaSpacing` uses.
  - `avatar_chip.dart`: 2 raw `SizedBox` (`6`, `4`), 1 raw `EdgeInsets` vs 0 `CasamaSpacing` uses (`6px` isn't even on the 4pt grid!).
  - `casama_button.dart`: 2 raw `SizedBox`, 1 raw `EdgeInsets` (`horizontal: 20` instead of `CasamaSpacing.lg`) vs 2 `CasamaSpacing` uses.
  - `status_chip.dart`: 1 raw `SizedBox(width: 4)` (when `CasamaSpacing.xxs` exists!), 1 raw `EdgeInsets` vs 1 `CasamaSpacing` use.
- **Missing Structural Token Families**: `dimensions.dart` defines only spacing + radii + an unused touch target constant. It lacks:
  - **Responsive Breakpoints** (explicitly mandated in `Casama_Project_Documentation.md` §4.6: `compact < 360`, `standard 360–599`, `medium 600–839`, `expanded ≥ 840`, plus `maxContentWidth = 600` for forms/sheets).
  - **Motion Tokens** (`durationFast = 150ms`, `durationStandard = 220ms`, standard Material easing curves).
  - **Icon & Avatar Size Scales** (`iconSm = 16`, `iconMd = 20`, `iconLg = 24`; `avatarSm = 16`, `avatarMd = 24`, `avatarLg = 36`, `avatarXl = 46`).
  - **Border Width & Elevation/Tonal Tokens** (`borderHairline = 1.0`, `borderFocused = 2.0`).

---

### Pillar 4: Reusable Components (`lib/shared/widgets/`)

#### Component Readiness Matrix

| Component | File | Light Mode | Dark Mode | WCAG AA Contrast | Screen Reader Semantics | Dynamic Type / Scaling | Touch Targets | Responsive / Overflow |
|---|---|---|---|---|---|---|---|---|
| `CasamaTextField` | `casama_text_field.dart` | Pass* | **BROKEN (P0)** | **FAIL** (1.11:1 dark; 1.30:1 border) | **FAIL** (detached label) | Partial | Pass (field) | Pass |
| `CasamaButton` | `casama_button.dart` | **FAIL** (coral; pill border) | **BROKEN** (`secondary`/`navy`) | **FAIL** (2.85:1; 1.71:1 disabled) | **FAIL** (no button/loading role) | **FAIL** (fixed `height`) | Partial (`40dp` overrides) | **FAIL** (unwrapped `Row`) |
| `StatusChip` | `status_chip.dart` | **FAIL** (6/11 variants) | **BROKEN** (all 11 variants) | **FAIL** (2.49–4.36:1) | **FAIL** (no semantics) | **FAIL** (unwrapped `Row`, 10pt) | N/A (non-interactive) | **FAIL** (no ellipsis) |
| `AvatarChip` | `avatar_chip.dart` | **BROKEN** (white text) | Pass (only on navy) | **FAIL** on light (`1.05:1`) | **FAIL** (raw `GestureDetector`) | **FAIL** (`fontSize: 10`) | Pass (avatar 52dp) | **FAIL** (unconstrained width) |
| `CasamaAvatar` | `casama_avatar.dart` | Pass | Pass | Pass (`5.84:1` / `13.46:1`) | **FAIL** (no `Semantics` / badge label) | **FAIL** (clips in `ClipOval`) | **FAIL** when `radius < 24` | Pass |
| `CasMascotView` | `cas_mascot_view.dart` | **FAIL** (cropped PNGs) | **BROKEN** (opaque cream box) | N/A (illustration) | **FAIL** (no `semanticLabel`/`exclude`) | Pass | N/A | Pass |
| `showInviteHousemateSheet` | `invite_housemate_sheet.dart` | Partial | **FAIL** (surface collision) | **FAIL** (`2.15:1` / `3.19:1`) | Partial (only copy tooltip) | **FAIL** (overflows) | **FAIL** (`40dp` Close btn) | **FAIL** (non-scrollable) |

*\*`CasamaTextField` Light Mode passes layout, but still fails hint (`2.35:1`) and border (`1.30:1`) contrast from `InputDecorationTheme`.*

#### Component-by-Component Notes
1. **`CasamaTextField`** (`casama_text_field.dart`, 27 uses across 8 files): Hardcodes `CasamaColors.ink` on label (L46) and input text (L59), and `CasamaColors.textSecondary` on `prefixIcon` (L63)—breaking Dark Mode across Auth, Register, Household Setup, Edit Profile, and Change Password. Detached `Text(label)` is not linked to `TextFormField` semantically. Missing built-in password visibility toggle (`app_settings_screen.dart:729-755` password fields have no eye icon at all, while `auth_screen.dart`/`login_screen.dart`/`register_screen.dart` duplicate identical toggle boilerplate 4 times). Missing `textInputAction`, `autofillHints`, `focusNode`, `onFieldSubmitted`, `enabled`, `inputFormatters`, `helperText`, and `autovalidateMode`.
2. **`CasamaButton`** (`casama_button.dart`, 65 uses across 26 files): Hardcodes light-only colors for `secondary` (L48–50) and dark-blending `#1C2E4A` for `navy` (L43—forcing `maintenance_screen.dart:101` into an ad-hoc `context.isDark ? primary : navy` workaround while `household_setup_screen.dart:169` and `maintenance_screen.dart:277` remain invisible in Dark Mode). Drops `side: border` whenever `isPill == true` (L93–98), affecting **100%** of `secondary` buttons in the app. Fixed `Container(height: height)` clips scaled fonts; unwrapped `Row` overflows on narrow screens; disabled `ghost` buttons remain visually identical to enabled ones; `isLoading` removes `label` from the accessibility tree; no `Semantics(button: true)` or `destructive` variant.
3. **`StatusChip`** (`status_chip.dart`, 7 uses across 5 files): Contains 18 raw `Color(0x...)` literals instead of `CasamaColors` tokens, duplicates `homeBg`/`homeGreen` 4× and `errorBg`/`errorRed` 2×, lacks any Dark Mode palette, fails WCAG AA on 6 of 11 built-in variants, leaks feature-specific enums (`toBuy`, `cod`, `unclaimed`) into a shared primitive, defaults to `11pt` (and accepts `10pt`), and omits `Flexible`/`overflow` protection on `Text(label)`.
4. **`AvatarChip`** (`avatar_chip.dart`, 1 external use in `dashboard_screen.dart:166`): Hardcodes `color: Colors.white` on label (L62) and status-dot border (L50), assuming it only ever lives on `dashboard_screen.dart`'s navy hero card—making it non-reusable on light surfaces. Uses `GestureDetector` with no ripple/focus/semantics, passes `fontSize: 10` to `StatusChip`, applies `TextOverflow.ellipsis` without a bounding width constraint, and `name.split(' ').first` yields `""` on leading whitespace.
5. **`CasamaAvatar`** (`casama_avatar.dart`, 12 uses across 8 files): Executes `base64Decode(base64Str)` synchronously inside `build()` (L48), omits `cacheWidth`/`cacheHeight` on all `Image.*` constructors, omits `loadingBuilder` on `Image.network`, uses `GestureDetector` without ripple/semantics, allows undersized tap targets when `radius < 24` (`optional_profile_screen.dart:276` uses `18`, `chat_directory_screen.dart:812` & `create_meetup_screen.dart:166` use `16`), and scales fallback text via uncapped `radius * 0.85` inside `ClipOval`.
6. **`CasMascotView`** (`cas_mascot_view.dart`, 12 uses across 8 files): All 9 pose PNGs in `assets/images/cas/` are `colorType=2` (opaque RGB without alpha channel, background `#FCF5ED`–`#FEF6EE`), low resolution (`145×160` to `220×180`—blurry when upscaled on 3× DPR phones), and visibly cropped from a composite mockup sheet (`cas_chatting.png` shows clipped blue text `"Action"` in the top-left corner; `cas_tasks.png` shows a clipped coral sliver on the left and half a teal icon on the right; `cas_deliveries.png` slices off the orange truck bubble and feet). Fallback container hardcodes `Color(0xFFFFF8F1)` (L65). Missing `semanticLabel` and `excludeFromSemantics`. Two poses (`standing`, `chatting`) are unused.
7. **`showInviteHousemateSheet`** (`invite_housemate_sheet.dart`, 1 external use in `main_navigation_shell.dart:193`): Feature-specific modal misplaced in `lib/shared/widgets/` (while `add_housemate_dialog.dart` lives in `lib/features/household/`). Non-scrollable `Column` overflows in landscape or at large font scale; invite code `Row` overflows horizontally; Close button is `40dp` tall; Dark Mode renders `darkSurface` invite box inside a `darkSurface` sheet (`1.0:1`); `'HOUSEHOLD CODE'` fails contrast in both themes (`2.15:1` / `3.19:1`); misuses `context.tileParcelsColor` for an invite badge; `Icons.share_rounded` triggers clipboard copy rather than OS Share; copy-code `SnackBar` renders *behind* the open modal sheet.

---

## Part 4: Detailed Findings by Severity

### P0 — Blocking (Fix Immediately)

#### [P0-1] Invisible Labels and Typed Input Text in Dark Mode (`CasamaTextField`)
- **Location**: `lib/shared/widgets/casama_text_field.dart:41-66`
- **Category**: Theming / Accessibility
- **Impact**: In Dark Mode, users filling out Login, Register, Household Setup, Edit Profile, or Change Password see `#1C2E4A` text rendered over `#18263D` input fill (**1.11:1**) and `#1C2E4A` labels over `#0F1A2B`/`#1E2F4A` (**1.28:1 / 1.01:1**). Users literally cannot read field labels or verify what they are typing, blocking authentication and account editing.
- **Guideline**: WCAG 2.1 SC 1.4.3 (Contrast Minimum 4.5:1); Material 3 Dark Theme; Apple HIG Dark Mode.
- **Recommendation**: Replace `CasamaColors.ink` on lines 46 & 59 with `Theme.of(context).colorScheme.onSurface` (or `context.textColor`), and `CasamaColors.textSecondary` on line 63 with `context.textSecondaryColor` (or `colorScheme.onSurfaceVariant`), inheriting font styles from `Theme.of(context).textTheme.labelMedium` / `bodyLarge`.
- **Suggested command**: `/impeccable colorize`

#### [P0-2] Unstyled Material 3 Text Roles Default to Black Ink in Dark Mode (`CasamaTheme.darkTheme`)
- **Location**: `lib/core/theme/app_theme.dart:149, 167-205`
- **Category**: Theming / Accessibility
- **Impact**: `GoogleFonts.interTextTheme()` defaults to `Typography.blackMountainView` (black text). Because `darkTheme` overrides only 8 of 15 `TextTheme` slots, any Material widget (`AlertDialog`, `ListTile`, `Chip`, `TabBar`, `BottomNavigationBar`, `DatePicker`) or screen reading `displayMedium`, `displaySmall`, `headlineLarge`, `headlineSmall`, `titleSmall`, `labelMedium`, or `labelSmall` renders black text on `#0F1A2B`/`#18263D` surfaces.
- **Guideline**: Material 3 Color Roles & Dark Theme; WCAG 2.1 SC 1.4.3.
- **Recommendation**: Change line 149 to `final baseText = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);` and explicitly configure all 15 Material 3 text roles using `CasamaColors.darkText` (`#F1F5F9`) and `CasamaColors.darkTextSecondary` (`#94A3B8`).
- **Suggested command**: `/impeccable typeset`

#### [P0-3] Complete Absence of Accessibility Semantics Across Shared Components
- **Location**: `lib/shared/widgets/casama_button.dart:91-109`, `casama_text_field.dart:38-69`, `avatar_chip.dart:25-76`, `casama_avatar.dart:108-149`, `cas_mascot_view.dart:54-72`, `status_chip.dart:97-121`
- **Category**: Accessibility
- **Impact**: TalkBack (Android) and VoiceOver (iOS) users encounter unlabeled inputs (detached `Text(label)` above `TextFormField`), non-semantic `GestureDetector` taps without button traits (`AvatarChip`, `CasamaAvatar`), silent loading states (`CasamaButton` drops `label` when `isLoading: true`), unlabeled camera edit badges, and unannounced or noisy mascot images. Screen-reader completion of core flows is effectively blocked.
- **Guideline**: WCAG 2.1 SC 1.1.1, 1.3.1, 4.1.2; Android TalkBack Accessibility; iOS VoiceOver HIG.
- **Recommendation**: Refactor `CasamaButton` onto M3 `FilledButton`/`OutlinedButton`/`TextButton` (or wrap with `Semantics(button: true, enabled: onPressed != null && !isLoading, label: isLoading ? '$label, loading' : label)`); associate `CasamaTextField` labels via `Semantics` / `InputDecoration.labelText` (`FloatingLabelBehavior.never` or explicit `Semantics(label: label)`); wrap `AvatarChip` and tappable `CasamaAvatar` in `Semantics(button: true, label: ...)` with `InkResponse`/`InkWell`; add optional `semanticLabel` / `excludeFromSemantics` (default `true` for decorative use) to `CasMascotView`.
- **Suggested command**: `/impeccable harden`

---

### P1 — Major (Fix Before Release)

#### [P1-1] Primary Brand Color (`primaryCoral #E87968`) Fails WCAG AA Contrast Across Light Mode
- **Location**: `lib/core/constants/colors.dart:6`, `lib/core/theme/app_theme.dart:16, 128`, `lib/shared/widgets/casama_button.dart:38, 54`, `invite_housemate_sheet.dart:49, 119, 216`
- **Category**: Accessibility / Theming
- **Impact**: Every primary CTA (`#FFFFFF` on `#E87968` = **2.85:1**), ghost CTA (`#E87968` on `#FFF8F1` = **2.71:1**), and disabled primary button (**1.71:1**) fails both WCAG AA normal text (4.5:1) and large text / UI component (3.0:1) thresholds. Low-vision users and users outdoors in daylight struggle to read every primary action in the app.
- **Guideline**: WCAG 2.1 SC 1.4.3 (4.5:1) & SC 1.4.11 (3.0:1).
- **Recommendation**: Introduce an AA-compliant interactive coral token for Light Mode (`primaryCoralAccessible = #C44938` -> **4.82:1** white-on-coral, **4.58:1** on `warmCream`; reserve `#E87968` for large decorative fills or Dark Mode where `#E87968` on `#18263D` is **5.32:1** and `#0F1A2B` ink on `#E87968` fill is **6.12:1**).
- **Suggested command**: `/impeccable colorize`

#### [P1-2] Muted Text and Form Input Borders Fail WCAG AA Text (4.5:1) and Non-Text (3.0:1) Contrast
- **Location**: `lib/core/constants/colors.dart:17, 22, 49, 52`, `lib/core/theme/app_theme.dart:95-120, 237-255`, `lib/shared/widgets/invite_housemate_sheet.dart:99`
- **Category**: Accessibility
- **Impact**: Input placeholders (`textMuted #9EABB2` on `#FFFFFF` = **2.35:1**), metadata labels (`2.15–2.24:1` light; `darkTextMuted #64748B` = **2.83–3.67:1** dark), and input borders (`borderGray #DCE3E0` on `#FFFFFF` = **1.30:1**; `darkBorder #2C4164` on `#18263D` = **1.48:1**) fade into the background, making form boundaries and hints difficult to perceive.
- **Guideline**: WCAG 2.1 SC 1.4.3 (4.5:1) & SC 1.4.11 (Non-text Contrast 3.0:1).
- **Recommendation**: Darken light `textMuted` to `#5E6E76` (**4.83–5.29:1**), lighten `darkTextMuted` to `#8E9EB3` (**4.93:1** on `darkCard`), and separate decorative dividers (`borderSubtle`) from interactive input borders (`inputBorderLight = #7F8E96` **3.21–3.38:1**; `inputBorderDark = #6C85AC` **3.58:1**).
- **Suggested command**: `/impeccable colorize`

#### [P1-3] `CasamaButton` Breaks in Dark Mode (`secondary` & `navy`) and Silently Drops Borders on Pill Secondary Buttons
- **Location**: `lib/shared/widgets/casama_button.dart:42-51, 93-98` (call sites: `auth_screen.dart:512`, `login_screen.dart:282`, `household_setup_screen.dart:169`, `maintenance_screen.dart:101, 277`)
- **Category**: Theming / Conformance
- **Impact**: `CasamaButtonStyle.secondary` renders a glaring `#FFFFFF` box in Dark Mode; `CasamaButtonStyle.navy` renders `#1C2E4A` on `#1E2F4A` `darkCard` (**1.01:1** — button shape vanishes completely, forcing ad-hoc workarounds like `maintenance_screen.dart:101`). Worse, line 93 checks `border != null && !isPill`, which silently strips the border from `StadiumBorder()` on **100%** of `secondary` buttons in the app because both call sites pass `isPill: true`.
- **Guideline**: Material 3 Outlined/Filled Buttons & Dark Theme.
- **Recommendation**: Make `secondary` theme-aware (`context.surfaceColor`, `context.textColor`, `context.borderColor`); adapt `navy` in Dark Mode to an elevated tonal/light-ink surface or `colorScheme.secondaryContainer`; always pass `side: border ?? BorderSide.none` into `StadiumBorder(side: ...)` when `isPill` is `true`.
- **Suggested command**: `/impeccable colorize`

#### [P1-4] `StatusChip` Fails WCAG AA on 6 of 11 Variants, Lacks Dark Mode, and Hardcodes 18 Raw Hex Colors
- **Location**: `lib/shared/widgets/status_chip.dart:46-95`
- **Category**: Accessibility / Theming
- **Impact**: Six built-in variants fail 4.5:1 in Light Mode (`unclaimed` 2.49:1, `cod` 2.50:1, `medium` 3.46:1, `out` 3.97:1, `toBuy` 4.03:1, `urgent`/`open` 4.36:1). In Dark Mode, all 11 variants paste glaring white/pastel pills onto `#1E2F4A` cards. Eighteen inline `Color(0x...)` literals bypass `CasamaColors`, making global palette updates impossible.
- **Guideline**: WCAG 2.1 SC 1.4.3; Material 3 Color Roles & Dark Theme.
- **Recommendation**: Replace raw hexes with theme-aware semantic chip tokens (using the verified Light/Dark palette in Pillar 1.3), ensure every pair achieves ≥ 4.5:1 contrast, add default semantic icons so status is never conveyed by color alone, and guard `Text(label)` inside `Flexible` with `overflow: TextOverflow.ellipsis`.
- **Suggested command**: `/impeccable colorize`

#### [P1-5] `invite_housemate_sheet.dart` Overflows in Landscape/High Font Scale, Violates Touch Targets (40dp), and Hides Copy Feedback Behind the Sheet
- **Location**: `lib/shared/widgets/invite_housemate_sheet.dart:25, 85-87, 103-135, 124-131, 196`
- **Category**: Adaptivity / Accessibility / Conformance
- **Impact**: Wrapping content in a non-scrollable `Column` causes immediate `RenderFlex` vertical overflow in landscape, on compact phones (`<360dp`), or at `1.3×+` font scale. The invite code `Row` (`fontSize: 26`, `letterSpacing: 4`) overflows horizontally on longer codes or scaled fonts. The Close button (`height: 40`) fails iOS `44pt` and Android `48dp` touch minimums. Tapping the copy icon fires a root `ScaffoldMessenger` `SnackBar` that renders *behind* the open modal sheet (invisible confirmation). In Dark Mode, the invite code box uses `darkSurface` inside a `darkSurface` sheet (`1.0:1`), collapsing visual hierarchy.
- **Guideline**: Material 3 Bottom Sheets & 48dp Touch Targets; Apple HIG 44pt Targets & Dynamic Type; `Casama_Project_Documentation.md` §4.6.
- **Recommendation**: Wrap sheet body in `SingleChildScrollView` with `viewInsets.bottom` padding; cap sheet width (`maxWidth: 560`) for tablets; wrap code `Text` in `Flexible` + `FittedBox(fit: BoxFit.scaleDown)`; raise Close button `minHeight` to `48.0`; switch code card fill in Dark Mode to `CasamaColors.darkCard` (`#1E2F4A`); display inline "Copied!" animated feedback inside the sheet rather than a hidden root `SnackBar`.
- **Suggested command**: `/impeccable adapt`

#### [P1-6] Split-Brain Theming & Zero `TextTheme` Adoption (0 `.textTheme` vs 508 Raw `TextStyle`)
- **Location**: `lib/core/theme/app_theme.dart:24-75, 158-256`, `lib/core/constants/colors.dart:69-95`, and all 50 files in `lib/`
- **Category**: Theming / Implementation Integrity
- **Impact**: `ThemeData.darkTheme` (`Colors.white`, `ivory`, `darkSurface` cards, raw `#E57373`) directly conflicts with `CasamaThemeContext` (`darkText`, `darkTextSecondary`, `darkCard`). Zero files consume `Theme.of(context).textTheme` while 508 raw `TextStyle(` calls span 17 ad-hoc font sizes—and even `app_theme.dart` uses 10 raw `const TextStyle(...)` declarations that lose the `Inter` font family. Visual polish and typographic hierarchy drift screen-to-screen.
- **Guideline**: Material 3 Type Scale & Color Roles; Operate Mode consistency.
- **Recommendation**: Reconcile `ThemeData` and `CasamaThemeContext` into one canonical token set (`ThemeExtension`), wrap `app_theme.dart` component text styles in `GoogleFonts.inter(...)`, and migrate shared widgets to consume `Theme.of(context).textTheme` roles (`titleMedium`, `bodyMedium`, `labelLarge`, etc.) before migrating feature screens.
- **Suggested command**: `/impeccable typeset`

#### [P1-7] `CasamaButton` Fixed Height & Unwrapped `Row` Clip Scaled Text; Disabled `ghost` State Is Invisible
- **Location**: `lib/shared/widgets/casama_button.dart:72-108`
- **Category**: Adaptivity / Accessibility
- **Impact**: `Container(height: height)` (`50` default; callers pass `40`/`44`/`46`) clips text vertically at large Dynamic Type / Android `font_scale`, and unwrapped `Text(label)` inside `Row` throws horizontal `RenderFlex overflowed` errors on narrow screens (`<360dp`) or long labels (e.g., `"One-Tap Demo Login (JP - Casa 204)"`). When `onPressed == null` on `CasamaButtonStyle.ghost`, `Colors.transparent.withValues(alpha: 0.5)` stays transparent while `fgColor` stays 100% coral—giving zero visual cue that the button is disabled.
- **Guideline**: WCAG 2.1 SC 1.4.4 (Resize Text); Material 3 & iOS Dynamic Type; Operate Mode complete component states.
- **Recommendation**: Replace fixed `height` with `constraints: BoxConstraints(minHeight: height ?? CasamaSpacing.minTouchTarget)` and vertical padding; wrap `Text(label)` in `Flexible` with `maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis`; dim `fgColor` (or use theme `disabledColor`) when `onPressed == null` across all variants including `ghost`.
- **Suggested command**: `/impeccable adapt`

#### [P1-8] `CasMascotView` Renders Opaque Cream Cutouts with Cropped Mockup Artifacts
- **Location**: `lib/shared/widgets/cas_mascot_view.dart:54-71`, `assets/images/cas/*.png`
- **Category**: Theming / Visual Polish
- **Impact**: All 9 mascot PNGs are `colorType=2` (opaque RGB `#FCF5ED`–`#FEF6EE`, zero alpha channel) and low resolution (`145×160` to `220×180`, upscaling ~2.25× on 3× DPR screens). Worse, multiple assets contain visible screenshot-crop defects: `cas_chatting.png` has clipped navy text `"Action"` in the top-left; `cas_tasks.png` has a red sliver on the left and half a teal wrench badge on the right; `cas_deliveries.png` slices off the orange delivery bubble and feet. On Dark Mode screens (`#0F1A2B`/`#18263D`), every mascot appears as a jagged beige rectangular box, and the fallback widget hardcodes `Color(0xFFFFF8F1)`.
- **Guideline**: Material 3 & HIG Dark Mode asset adaptation; high-DPI asset hygiene.
- **Recommendation**: Re-export all 9 mascot illustrations cleanly as transparent RGBA PNGs (or vector SVGs) at `3×` resolution (`≥450×450px`) with full silhouettes and zero adjacent mockup artifacts; update fallback container to use `context.cardColor` / `context.borderColor`; until transparent assets are ready, apply a circular `ClipOval` + soft surface ring in `CasMascotView` as an interim dark-mode mitigation.
- **Suggested command**: `/impeccable polish`

#### [P1-9] `CasamaAvatar` Runs Synchronous `base64Decode` Inside `build()` and Decodes Unbounded Images
- **Location**: `lib/shared/widgets/casama_avatar.dart:42-80`
- **Category**: Performance
- **Impact**: `EditProfileDialog` encodes picked photos (`600×600` JPEG) as `data:image/jpeg;base64,...` strings. `CasamaAvatar.build()` calls `base64Decode(base64Str)` synchronously on every rebuild—stalling the UI thread during scroll animations or text input. Additionally, `Image.memory`, `Image.network`, and `Image.file` omit `cacheWidth`/`cacheHeight`, decoding multi-megapixel bitmaps into GPU texture memory for `32–92dp` circles.
- **Guideline**: Flutter 60/120 Hz frame-budget performance; `audit.native.md` Image Handling.
- **Recommendation**: Convert `CasamaAvatar` to cache decoded `Uint8List` bytes (or `MemoryImage`) keyed by `avatarUrl` (e.g., via a small LRU cache or `StatefulWidget` updating only in `didUpdateWidget`), and pass `cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round()` to all `Image.*` constructors.
- **Suggested command**: `/impeccable optimize`

#### [P1-10] `AvatarChip` Hardcodes White Text/Border, Violates 11pt Floor (`fontSize: 10`), and Lacks Touch Feedback
- **Location**: `lib/shared/widgets/avatar_chip.dart:25-76`
- **Category**: Theming / Accessibility / Conformance
- **Impact**: Hardcoding `color: Colors.white` (L50, L62) makes a `lib/shared/widgets/` component unusable on any light surface (`1.05:1` on `warmCream`). Passing `fontSize: 10` to `StatusChip` violates iOS HIG's 11pt floor and Material's 11sp `labelSmall`. Raw `GestureDetector` omits ink feedback, keyboard focus, and button semantics; `TextOverflow.ellipsis` has no bounding width; and `name.split(' ').first` produces `""` for leading spaces or empty names.
- **Guideline**: Apple HIG Typography (11pt floor); WCAG 2.1 SC 1.4.3 & 4.1.2; Material 3 touch feedback.
- **Recommendation**: Accept `labelColor` / `dotBorderColor` defaulting to `context.textColor` / `context.surfaceColor` (letting `dashboard_screen.dart` pass `Colors.white` / `CasamaColors.midnightNavy` explicitly); raise chip `fontSize` to `11`–`12`; switch `GestureDetector` to `InkWell` + `Semantics(button: true, label: ...)`; constrain width (`ConstrainedBox(maxWidth: 76)`) and trim `name.trim().split(RegExp(r'\s+')).first`.
- **Suggested command**: `/impeccable harden`

#### [P1-11] Missing Essential Material 3 Component Themes & Form `focusedErrorBorder`
- **Location**: `lib/core/theme/app_theme.dart:85-145, 228-276`
- **Category**: Conformance / Error Recovery
- **Impact**: `InputDecorationTheme` defines `errorBorder` but omits `focusedErrorBorder`, `disabledBorder`, and `errorStyle`—so when a user taps into an invalid field to fix it, the red error border disappears and turns coral, hiding the validation state! Meanwhile, missing `snackBarTheme`, `bottomSheetTheme`, `dialogTheme`, `chipTheme`, `navigationBarTheme`, `textButtonTheme`, `filledButtonTheme`, `switchTheme`, and `dividerTheme` cause systemic visual inconsistency across feature screens.
- **Guideline**: Material 3 Components & Form Error States; `Casama_Project_Documentation.md` §4.4.
- **Recommendation**: Add `focusedErrorBorder`, `disabledBorder`, and `errorStyle` to `InputDecorationTheme` in both themes, and define complete M3 component themes in `CasamaTheme` (starting with `snackBarTheme`, `bottomSheetTheme`, `dialogTheme`, `textButtonTheme`, `filledButtonTheme`, `navigationBarTheme`, `chipTheme`, `dividerTheme`).
- **Suggested command**: `/impeccable polish`

---

### P2 — Minor (Fix in Next Pass)

#### [P2-1] `ThemeNotifier` Defaults to `ThemeMode.light` and `toggleTheme()` Fails From `ThemeMode.system`
- **Location**: `lib/core/theme/theme_provider.dart:9, 33, 41, 44-47`
- **Category**: Theming / User Control
- **Impact**: Fresh installs ignore users' OS Dark Mode preference (`super(ThemeMode.light)`). Calling `toggleTheme()` while `state == ThemeMode.system` on a light device sets `ThemeMode.light` (no visible change). Empty `catch (_) {}` blocks silently drop storage failures.
- **Guideline**: Apple HIG Dark Mode & Android Dark Theme (honor system preference by default).
- **Recommendation**: Default initial state to `ThemeMode.system`; update `toggleTheme(Brightness currentBrightness)` to invert the *resolved* brightness (`currentBrightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark`); log persistence exceptions via `debugPrint`.
- **Suggested command**: `/impeccable harden`

#### [P2-2] `CasamaTheme` Rebuilds `ThemeData` & `GoogleFonts` on Every Getter Access Without Bundled Offline Fonts
- **Location**: `lib/core/theme/app_theme.dart:9-10, 148-149`, `pubspec.yaml:40, 84-100`
- **Category**: Performance / Typography
- **Impact**: Calling `CasamaTheme.lightTheme` and `darkTheme` as getters rebuilds both `ThemeData` instances on every `CasamaApp.build()`. Without bundled `.ttf` assets in `assets/fonts/` (and `GoogleFonts.config.allowRuntimeFetching = false`), offline launches fail to load `Inter` and experience FOUT.
- **Guideline**: Flutter Performance Best Practices; Offline Reliability.
- **Recommendation**: Cache `lightTheme` and `darkTheme` as `static final ThemeData` fields (or memoized builders), bundle `Inter` Regular/Medium/SemiBold/Bold `.ttf` files in `pubspec.yaml`, and disable runtime font fetching in production.
- **Suggested command**: `/impeccable optimize`

#### [P2-3] Missing Form Ergonomics on `CasamaTextField`
- **Location**: `lib/shared/widgets/casama_text_field.dart:6-71`
- **Category**: Usability / Efficiency
- **Impact**: Lack of `textInputAction`, `focusNode`, `onFieldSubmitted`, `autofillHints`, `inputFormatters`, `enabled`, `helperText`, `errorMaxLines`, and built-in password visibility toggle slows down mobile form completion (no Next/Done keyboard hopping, no OS password-manager autofill, truncated multi-line errors, and inconsistent password peek icons across screens).
- **Guideline**: Material 3 Text Fields; Mobile Form Ergonomics.
- **Recommendation**: Extend `CasamaTextField` with optional `textInputAction`, `focusNode`, `onFieldSubmitted`, `autofillHints`, `inputFormatters`, `enabled`, `helperText`, `errorMaxLines = 2`, and convert `isPassword` to include an accessible built-in visibility toggle (`IconButton` with `tooltip: 'Show password'` / `'Hide password'`).
- **Suggested command**: `/impeccable clarify`

#### [P2-4] `CasamaSpacing` Missing Adaptive/Motion Tokens, Contains 8 Dead Tokens, and Is Bypassed Internally
- **Location**: `lib/core/constants/dimensions.dart:3-39`, `lib/shared/widgets/*.dart`
- **Category**: Implementation Integrity / Adaptivity
- **Impact**: `minTouchTarget = 48.0`, `xxs`, `huge`, and `radiusSm`–`radiusPill` are unused (`0` external references), while `lib/shared/widgets/` uses 33 raw spacing/radius literals (`SizedBox(height: 6)`, `EdgeInsets.symmetric(horizontal: 20)`, `Radius.circular(24)`). Missing breakpoint, max-width, motion, and icon/avatar scale tokens make adaptive tablet/landscape layouts inconsistent.
- **Guideline**: `Casama_Project_Documentation.md` §4.5–§4.6; Design System Governance.
- **Recommendation**: Fix doc comment to `4pt grid / 8pt rhythm`, add `CasamaBreakpoints` (`compact = 360`, `medium = 600`, `expanded = 840`, `maxContentWidth = 600`), `CasamaDurations` (`fast = 150ms`, `normal = 220ms`), and `CasamaSizes` (icon/avatar/button heights), and replace all 33 hardcoded literals inside `lib/shared/widgets/` and `app_theme.dart`.
- **Suggested command**: `/impeccable layout`

#### [P2-5] Token Naming, Duplication & Feature Leakage
- **Location**: `lib/core/constants/colors.dart:10, 15-37, 61-95`, `lib/shared/widgets/status_chip.dart:6-19`, `lib/shared/widgets/invite_housemate_sheet.dart`
- **Category**: Implementation Integrity / Theming
- **Impact**: `CasamaColors.ivory` (`#BDC4D4`) is misleadingly named; 5 duplicate color aliases bloat the token list; `tileBills` and `tileChoreRoulette` lack `CasamaThemeContext` getters; `ChipVariant` hardcodes 5 unrelated feature domains into a shared widget; and `invite_housemate_sheet.dart` is a household-feature modal placed inside `lib/shared/widgets/` (inconsistent with `lib/features/household/add_housemate_dialog.dart`).
- **Guideline**: Design System Separation of Concerns.
- **Recommendation**: Rename `ivory` to `coolSlate` (or remove once `darkTextSecondary` unifies it); deduplicate aliases; expose all 6 tile tokens in `ThemeExtension`; refactor `StatusChip` to semantic roles (`success`, `neutral`, `brand`, `danger`, `warning`, `info`) with domain mappers in feature modules; move `invite_housemate_sheet.dart` to `lib/features/household/`.
- **Suggested command**: `/impeccable distill`

#### [P2-6] `CasamaAvatar` Lacks Network Loading State, Caps-Free Fallback Scaling, and Touch Target Guard
- **Location**: `lib/shared/widgets/casama_avatar.dart:59-66, 145-166`
- **Category**: Performance / Accessibility / Usability
- **Impact**: Network avatars flash blank circles while loading; fallback initials (`radius * 0.85`) clip inside `ClipOval` at high system `TextScaler` values (`1.5×–2.0×`); tappable avatars with `radius < 24` drop below Android's `48dp` touch target; `showEditBadge` renders an unstyled `BoxShadow` instead of tonal elevation.
- **Guideline**: Android 48dp / iOS 44pt Touch Targets; Dynamic Type safety.
- **Recommendation**: Add a `loadingBuilder` placeholder shimmer/icon on `Image.network`; clamp fallback `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.2)` or wrap `Text(letter)` in `FittedBox`; pad tappable hit regions to at least `48×48dp` via `ConstrainedBox` / `InkResponse`.
- **Suggested command**: `/impeccable harden`

---

### P3 — Polish (Fix If Time Permits)

#### [P3-1] Missing `ThemeExtension` Prevents Smooth `AnimatedTheme` Light↔Dark Transitions
- **Location**: `lib/core/constants/colors.dart:69-95`, `lib/core/theme/app_theme.dart`
- **Category**: Theming / Motion
- **Impact**: Switching theme mode snaps custom `CasamaThemeContext` colors instantaneously while Material widgets interpolate over `200ms`, creating a brief split-frame flash.
- **Recommendation**: Migrate `CasamaThemeContext` tokens into `class CasamaColorScheme extends ThemeExtension<CasamaColorScheme>` with `Color.lerp` in `lerp()`, keeping the `BuildContext` extension as a thin typed accessor (`Theme.of(this).extension<CasamaColorScheme>()!`).
- **Suggested command**: `/impeccable animate`

#### [P3-2] `invite_housemate_sheet.dart` Visual Craft & Copy-Action Mismatches
- **Location**: `lib/shared/widgets/invite_housemate_sheet.dart:30-57, 172-178`
- **Category**: Conformance / Visual Polish
- **Impact**: Hand-rolled `40×4` drag handle diverges from M3 `showDragHandle: true` (`32×4`); heading mixes emoji (`'Invite Your Housemates 🏡'`) with Material rounded icons; icon badge borrows `context.tileParcelsColor` (wrong domain token); primary button pairs `Icons.share_rounded` with clipboard copy instead of native OS share.
- **Recommendation**: Enable `showDragHandle: true`, remove heading emoji, use a semantic `brandSurface` token, and either wire native OS sharing (`share_plus`) or swap the icon to `Icons.content_copy_rounded` to match the copy action truthfully.
- **Suggested command**: `/impeccable clarify`

#### [P3-3] Reduce Motion & Tabular Numerals Not Wired at System Level
- **Location**: `lib/shared/widgets/casama_button.dart:67`, `lib/core/theme/app_theme.dart:24-62`
- **Category**: Accessibility / Typography
- **Impact**: `CircularProgressIndicator` spins continuously even when `MediaQuery.disableAnimationsOf(context)` is enabled; numeric figures (bills, COD amounts, points) lack `FontFeature.tabularFigures()`, causing jittering column alignment despite §4.2 requiring tabular numerals.
- **Recommendation**: Honor `MediaQuery.disableAnimationsOf(context)` in loading/animated states (showing static `'Loading...'` text or subtle pulse) and expose a `tabularStyle` helper/token in `CasamaTheme` for currency, dates, and point totals.
- **Suggested command**: `/impeccable polish`

---

## Part 5: Cognitive Load, Emotional Journey & Persona Red Flags

### Cognitive Load Assessment (`critique-rubric.md`)
Evaluated at the design-system & shared-component level (**3 / 8 failures — Moderate cognitive load; address soon**):
- [x] **Single focus**: Individual primitives (`CasamaButton`, `CasamaTextField`, `StatusChip`) stay focused on one purpose.
- [x] **Chunking**: `invite_housemate_sheet.dart` chunks into header, code box, 3 benefits (≤4), and 2 actions.
- [ ] **Grouping (FAIL)**: In Dark Mode, `invite_housemate_sheet.dart`'s invite-code box (`darkSurface`) collapses into the sheet (`darkSurface`), and `CasamaButtonStyle.navy` (`#1C2E4A`) collapses into `darkCard` (`#1E2F4A`), destroying figure-ground boundaries.
- [ ] **Visual hierarchy (FAIL)**: Low-contrast `primaryCoral` (`2.85:1`), 17 inconsistent font sizes across 0 `TextTheme` consumers, and stark white `secondary` buttons in Dark Mode invert intended focal priority.
- [x] **One thing at a time**: Modal and form primitives avoid multi-task demands.
- [x] **Minimal choices**: `invite_housemate_sheet.dart` presents 2 clear actions (≤4 options).
- [ ] **Working memory / Recognition (FAIL)**: Detached unlabeled inputs for screen readers, missing `helperText` / `focusedErrorBorder`, invisible Dark Mode labels, and misleading Share-icon-that-copies increase extraneous mental effort.
- [x] **Progressive disclosure**: Complex actions stay scoped inside sheets/dialogs rather than crowding every surface.

### Emotional Journey (Peak-End & Valleys)
- **Peak (Warmth & Hospitality)**: In Light Mode, Warm Cream surfaces, soft rounded cards, friendly Filipino household framing ("Good Kasama points", "Casa 204"), and Cas the Owl create an unusually welcoming first impression.
- **Deepest Valley (Trust Break in Dark Mode)**: The moment a user toggles Dark Mode, the experience fractures—invisible text inside form fields, blinding white buttons and pastel chips, cream-boxed cropped owl cutouts, and vanished navy buttons shatter perceived quality.
- **End-of-Task Valley**: Copying an invite code produces no visible confirmation while the modal stays open because the SnackBar renders behind the sheet, leaving users unsure whether the tap worked.

### Persona Red Flags

#### 1. Accessibility-Dependent User: "Sam" *(Predefined — Screen reader, low vision, 200% font scale)*
- **Form completion (`CasamaTextField`)**: TalkBack/VoiceOver reads `"Email Address"` as disconnected static text, then announces an unlabeled edit box. At `1.5×–2.0×` text scale, `CasamaButton`'s fixed `height: 50` clips button text vertically and overflows horizontally.
- **Reading CTAs & Status (`CasamaButton`, `StatusChip`)**: Primary coral buttons (**2.85:1**), ghost links (**2.71:1**), input hints (**2.35:1**), and 6/11 status chips (**2.49–4.36:1**) fail WCAG AA; disabled `ghost` buttons give no visual cue at all.
- **Interactive avatars (`AvatarChip`, `CasamaAvatar`)**: Raw `GestureDetector` widgets lack button roles, focus highlights, and semantic labels; `CasamaAvatar`'s camera badge is silent to screen readers.

#### 2. Distracted Mobile User: "Casey" *(Predefined — One-handed phone, Dark Mode at night, spotty network)*
- **Nighttime edits (`CasamaTextField`, `CasamaButton`)**: Forced into Light Mode on install (`ThemeMode.light` default); after manually enabling Dark Mode, form inputs become unreadable (**1.11:1**) and `secondary` buttons glare white.
- **Thumb targets & quick taps (`invite_housemate_sheet.dart`, `CasamaAvatar`)**: Close button is only `40dp` tall (below 48dp Android / 44pt iOS); preset/chat avatars (`radius: 16–18` = `32–36dp`) are cramped for thumb taps.
- **Slow connections (`CasamaAvatar`, `app_theme.dart`)**: Network avatars show empty circles with no loading state, and `google_fonts` runtime fetching risks font shifts when offline.

#### 3. Deliberate Stress Tester: "Riley" *(Predefined — Edge cases, landscape, unexpected input)*
- **Landscape & small screens (`invite_housemate_sheet.dart`, `CasamaButton`)**: Rotating to landscape on `showInviteHousemateSheet` immediately triggers `RenderFlex` overflow because the `Column` is non-scrollable; long invite codes overflow the `Row`.
- **Edge-case strings (`AvatarChip`, `CasamaTextField`)**: Passing `" Maria"` (leading space) into `AvatarChip` renders an empty label (`name.split(' ').first == ""`); tapping into an invalid `CasamaTextField` hides the red `errorBorder` because `focusedErrorBorder` is undefined.
- **Theme toggling (`ThemeNotifier`)**: Calling `toggleTheme()` from `ThemeMode.system` when the OS is in Light Mode silently does nothing.

#### 4. Dorm Student at Midnight: "Mika" *(Project-Specific — from `Casama_Project_Documentation.md` §1.5: college student in a shared dorm coordinating late-night Shopee COD parcels & profile updates)*
- **Dark Mode parcel & profile check**: Opens Edit Profile (`EditProfileDialog`) or Change Password at midnight in Dark Mode and cannot read the `#1C2E4A` text she is typing into `CasamaTextField` (`1.11:1`); `CasMascotView` empty states flash bright opaque cream rectangles (`#FCF5ED`) with clipped artwork (`cas_deliveries.png`, `cas_tasks.png`); `COD` status chip (`#E87968` on `#FFECE8`, **2.50:1**) glares and stays unreadable.

#### 5. Busy Apartment Roommate: "Marco" *(Project-Specific — from `Casama_Project_Documentation.md` §1.5: young professional onboarding a new roommate via `showInviteHousemateSheet`)*
- **Inviting a new housemate**: Taps the copy icon next to the household code and sees **no visible confirmation** because the `SnackBar` renders behind the modal bottom sheet. Taps `"Copy Full Invitation Message"` (carrying a Share icon `Icons.share_rounded`) expecting Android/iOS native Share to send straight to Messenger/Viber, only to discover it merely copied text to the clipboard.

---

## Part 6: Patterns & Systemic Issues

1. **Design Tokens Exist on Paper, Not in Consumption**: `Theme.of(context).textTheme` has **0** calls across all 50 files (vs 508 raw `TextStyle`s); `CasamaSpacing.minTouchTarget`, `xxs`, `huge`, and `radiusSm`–`radiusPill` have **0** calls; `140` raw `Color(0x...)` literals leak across 24 feature files (including 18 inside `StatusChip` itself).
2. **Dark Mode Was Layered On Top Rather Than Architected In**: Only `CasamaThemeContext`'s 7 base surface/text getters adapt cleanly; `CasamaTheme.darkTheme`, `CasamaTextField`, `CasamaButton`, `StatusChip`, `AvatarChip`, `CasMascotView`, and `invite_housemate_sheet.dart` all leak hardcoded light-mode colors or opaque light assets.
3. **Fragmented Component APIs**: Four button systems (`CasamaButton`, `ElevatedButton`, `OutlinedButton`, `TextButton`) and three text-input paths (`CasamaTextField`, `TextFormField`, `TextField` 45×) coexist without unified theme inheritance.
4. **Accessibility Is Untreated as a First-Class Layer**: Zero `Semantics` widgets, zero `disableAnimations` checks, zero `textScaler` guards, and systematic sub-AA contrast across primary coral, muted ink, input borders, and status pills.
5. **Documentation-to-Code Drift**: `Casama_Project_Documentation.md` §4.2–§4.7 explicitly specifies contrast verification, tabular numerals, 48dp touch targets, 4 responsive viewport breakpoints, and scrollable landscape dialogs—yet none of these contracts are encoded in `lib/core/` or `lib/shared/widgets/`.

---

## Minor Observations & Questions to Consider

### Minor Observations
- `CasPose.standing` and `CasPose.chatting` have `0` call sites across `lib/` (and `cas_chatting.png` has `"Action"` crop text baked in).
- `CasamaButtonStyle.secondary` is only used twice (`auth_screen.dart:512`, `login_screen.dart:282`), both times with `isPill: true`, hitting the dropped-border bug.
- `CasamaAvatar` default fallback `borderColor` in Light Mode is `Colors.white` (`casama_avatar.dart:100`), making borders invisible on white cards.
- `app_theme.dart` sets `colorScheme.surface: CasamaColors.warmCream` identical to `scaffoldBackgroundColor`, losing Material 3's default card/sheet tonal separation.
- No `DESIGN.md` exists yet in the repository to codify the token contract, component states, and dark-mode rules for contributors.

### Questions to Consider
1. **Coral identity vs WCAG AA**: Are you willing to deepen interactive `primaryCoral` in Light Mode from `#E87968` to `#C44938` (`4.82:1` with white) while keeping `#E87968` for Dark Mode and illustrations—or do you prefer switching primary button labels in Light Mode to `midnightNavy` (`#1C2E4A` on `#E87968` = **4.79:1**, passing AA without changing the coral swatch)?
2. **One button primitive or themed Material 3 buttons?**: Should `CasamaButton` become a thin semantic wrapper directly over Material 3 `FilledButton` / `OutlinedButton` / `TextButton` (inheriting focus rings, haptics, and semantics automatically), rather than maintaining custom `Material` + `InkWell` geometry?
3. **Mascot art pipeline**: Do you have access to the original vector/layered source files for Cas the Owl so all 9 poses can be re-exported cleanly at 3× with transparent backgrounds (fixing the cropped speech bubbles and `"Action"` artifact)?
4. **Enforcing system tokens**: Once `CasamaTheme` and `CasamaColorScheme` (`ThemeExtension`) are fixed, should we add lint/CI guards against raw `Color(0x...)` and raw `TextStyle` literals so feature screens stay on-system?

---

## Recommended Actions (Priority Order)

1. **[P0] `/impeccable colorize`**: Establish a unified `ThemeExtension<CasamaColorScheme>` in `lib/core/constants/colors.dart` & `lib/core/theme/app_theme.dart`; fix Dark Mode text invisibility in `CasamaTextField`, broken `CasamaButton` (`secondary`/`navy` + pill border), all 11 `StatusChip` dark/light AA palettes, AA-compliant `primaryCoral` / `textMuted` / interactive borders, and `invite_housemate_sheet` surface separation.
2. **[P0] `/impeccable typeset`**: Fix `CasamaTheme.darkTheme` (`GoogleFonts.interTextTheme(ThemeData.dark().textTheme)`), wire `Inter` into all component text styles, define all 15 Material 3 text roles with line-heights and tabular-figure helpers, and migrate shared widgets off raw `TextStyle` onto `Theme.of(context).textTheme`.
3. **[P0] `/impeccable harden`**: Add full `Semantics` / `MergeSemantics` / `ExcludeSemantics` support across `CasamaButton`, `CasamaTextField`, `AvatarChip`, `CasamaAvatar`, `CasMascotView`, and `StatusChip`; fix `ThemeNotifier` (`ThemeMode.system` default & `toggleTheme()` bug); guard `AvatarChip` name trimming and `CasamaAvatar` loading/touch targets.
4. **[P1] `/impeccable adapt`**: Make `invite_housemate_sheet.dart` scrollable with tablet width capping, `48dp` Close touch target, inline copy feedback, and scaled-text code fitting; convert `CasamaButton` to `minHeight` constraints + wrapped labels; raise `AvatarChip` chip text to `≥11pt`; add breakpoint/max-width tokens to `dimensions.dart`.
5. **[P1] `/impeccable optimize`**: Eliminate synchronous `base64Decode` in `CasamaAvatar.build()`, add `cacheWidth`/`cacheHeight` to all `Image.*` calls, memoize `CasamaTheme.lightTheme`/`darkTheme` as `static final`, and bundle `Inter` `.ttf` fonts offline in `pubspec.yaml`.
6. **[P2] `/impeccable clarify`**: Upgrade `CasamaTextField` with built-in password visibility toggle, `textInputAction`, `autofillHints`, `helperText`, `errorMaxLines`, and `enabled`; align `invite_housemate_sheet.dart` share vs copy icon/label truthfully and remove decorative heading emoji.
7. **[P2] `/impeccable distill`**: Deduplicate `CasamaColors` aliases, rename `ivory`, generalize `ChipVariant` to semantic roles, relocate `invite_housemate_sheet.dart` to `lib/features/household/`, and consolidate `CasamaButton` onto Material 3 button primitives.
8. **[P2] `/impeccable document`**: Generate a canonical `DESIGN.md` locking down the revised AA light/dark palette, type scale, spacing/breakpoint tokens, and component contracts.
9. **[P1–P3] `/impeccable polish`**: Complete missing Material 3 component themes (`focusedErrorBorder`, `snackBarTheme`, `bottomSheetTheme`, `dialogTheme`, `chipTheme`, `navigationBarTheme`, `dividerTheme`), replace cropped opaque mascot PNGs with transparent 3× assets, wire `ThemeExtension.lerp`, and honor `MediaQuery.disableAnimationsOf`.

> You can ask me to run these one at a time, all at once, or in any order you prefer.
>
> Re-run `/impeccable audit` and `/impeccable critique` after fixes to see your scores improve.
