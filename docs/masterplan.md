   Casama — Phased Frontend UI/UX & Motion Redesign Plan                                                                                         
                                                                                                                                                 
  Architectural Guardrails & Source-of-Truth Hierarchy                                                                                           
                                                                                                                                                 
  • Strict Frontend Scope: All changes stay strictly within lib/core/, lib/shared/widgets/, and lib/features/ (plus pubspec.yaml asset           
  verification and test/ widget/E2E test synchronization). Zero changes will be made to database schemas, Supabase configuration, or the         
  data/repository layer (lib/data/models.dart, lib/data/casama_repository.dart, lib/data/mock_repository.dart, lib/data/supabase_repository.dart,
  lib/data/repository_provider.dart).                                                                                                            
  • Reference Precedence:                                                                                                                        
      1. Shell, Navigation, Consolidation & Motion: docs/casama-app-mockup.html (5-slot bottom bar with raised CASnap trigger, slide-over drawer,
      unified 4-tab Boards hub with directional swipe + morphing FAB, embedded Task Roulette sheet, CASnap camera/gallery/lightbox, and slide-up 
      creation sheets).                                                                                                                          
      2. Splash, Onboarding & Auth Visuals: docs/starting.html (split-tone Forest Teal wave headers, rounded-top 28dp white sheet cards, warm    
      sand filled inputs, inline Terms checkbox).                                                                                                
      3. Material 3 Visual Polish & Surface Details: docs/core_screens.html (stepped #37655E → #688C83 → #A5B9B0 → #EAE4D7 organic wave headers, 
      #F4B544 celestial gold ring ornaments, 6%/9% ambient canvas waves, pure white 20dp hairline-bordered cards, Plus Jakarta Sans + Inter      
      typography, chat bubbles, and profile hub).                                                                                                
                                                                                                                                                 
  ──────                                                                                                                                         
  1. Design System, Mascot Adapter & Shared UI/Motion Primitives                                                                                 
                                                                                                                                                 
  1.1 Color Tokens & Harmonized Dark Mode (lib/core/constants/colors.dart & lib/core/theme/app_theme.dart)                                       
                                                                                                                                                 
  Introduce a ThemeExtension<CasamaPalette> (exposed via CasamaThemeContext for backward compatibility and smooth AnimatedTheme interpolation)   
  implementing the exact palette from core_screens.html / casama-app-mockup.html alongside a warm nocturnal Dark Mode:                           
                                                                                                                                                 
   Role                        │ Light Token (core_screens.html)        │ Harmonized Dark Token             │ Usage
  ─────────────────────────────┼────────────────────────────────────────┼───────────────────────────────────┼────────────────────────────────────
   Canvas / Scaffold           │ #EAE4D7 (Auth/Splash #F9F4EC)          │ #0D171E                           │ Full-bleed page canvas
   Header Wave Stack           │ #37655E → #688C83 → #A5B9B0 → #EAE4D7  │ #1D3B36 → #264B45 → #162A2D →     │ Stepped organic wave headers
                               │                                        │ #0D171E                           │
   Celestial Ornament          │ #F4B544 (40–45% opacity)               │ #F4B544 (28% opacity)             │ Top-right orbital gold ring art
   Ambient Body Waves          │ #37655E (6% & 9% opacity)              │ #5EB5AD (4% & 6% opacity)         │ Subtle lower-canvas curves
   Surface (Nav / Sheets)      │ #FFFFFF                                │ #14222B                           │ Bottom bar, drawer, slide-up
                               │                                        │                                   │ sheets
   Card Surface                │ #FFFFFF                                │ #1A2C37                           │ All 20dp-radius cards (1px border)
   Track / Filled Input        │ #EAE6DF (Auth #EAE4DC)                 │ #223846                           │ 50dp inputs, segmented pill tracks
   Hairline / Input Border     │ #DCE3E0 (Checkbox/Focus #7F8E96 /      │ #2C4654 (Interactive #6C8896 /    │ Card hairlines & interactive
                               │ #37655E)                               │ #5EB5AD)                          │ outlines
   Primary Coral (AA Text/CTA) │ #C44938 (4.82:1 w/ white)              │ #F08B7B (#0D171E on-fill / coral  │ Primary CTAs, active nav tabs,
                               │                                        │ text)                             │ badges
   FAB / Shutter Warm Coral    │ #E87461 (Soft Blush #FFF0ED)           │ #E87461 (Dark Blush #3A2220)      │ Raised CASnap shutter & morphing
                               │                                        │                                   │ FAB
   Forest Teal Accent          │ #37655E (Sage Tint #E0ECE7)            │ #66B2A8 (Dark Sage #1B3633)       │ Active filter pills, outgoing chat
                               │                                        │                                   │ bubbles
   Typography Ink              │ Primary #1C2E4A · Secondary #54646C    │ Primary #F2F5F7 · Secondary       │ Headings, body, uppercase kickers
                               │                                        │ #A3B4BE                           │
   Semantic Status Pills       │ Home/Paid #2E7D32/#E8F5E9 · Out        │ #81C784/#1B3626 · #CBD5E1/#263440 │ All ≥4.5:1 WCAG AA in both themes
                               │ #595959/#EEEEEE · Overdue/Open         │ · #F28B82/#3D1F25 ·               │
                               │ #C62828/#FFEBEE · Unpaid               │ #FFB74D/#3B2B17 · #90CAF9/#1B2E45 │
                               │ #B54708/#FFF3E0 · Info #1565C0/#E3F2FD │ · #FFD54F/#3A3016                 │
                               │ · Gold #8D5500/#FFF8E1                 │                                   │
                                                                                                                                                 
  1.2 Typography & Spacing (lib/core/theme/app_theme.dart, lib/core/constants/dimensions.dart)                                                   
                                                                                                                                                 
  • Font Hierarchy: Configure GoogleFonts.plusJakartaSans (w600, w700, w800) for displayLarge (28), headlineLarge (24–26), headlineMedium (22),  
  titleLarge (18–20), and titleMedium (15.5–16), paired with GoogleFonts.inter (w400, w500, w600, w700) for bodyLarge (15), bodyMedium (14),     
  bodySmall (12.5–13), labelLarge (14), labelMedium (12), and labelSmall (11, 0.5px letter-spacing for uppercase section labels).                
  • Dark Mode TextTheme Fix: Initialize darkTheme from GoogleFonts.interTextTheme(ThemeData.dark().textTheme) so unoverridden Material 3 text    
  roles never render black ink in dialogs or pickers; cache lightTheme and darkTheme.                                                            
  • Tabular Numerals Helper: Add a TextStyle.tabular extension (FontFeature.tabularFigures()) applied to all ₱ currency readouts, presence counts,
  timers, and points.                                                                                                                            
  • Spacing & Radii Tokens: Add radiusCard = 20.0, radiusSummary = 18.0, radiusInput = 14.0, radiusSheet = 28.0, minTouchTarget = 48.0, and      
  responsive breakpoint helpers (<360 compact, 360–599 phone, ≥600 tablet max-width 600dp centering).                                            
                                                                                                                                                 
  1.3 Mascot Asset Routing (lib/shared/widgets/cas_mascot_view.dart & pubspec.yaml)                                                              
                                                                                                                                                 
  │ Important Codebase Discovery: assets/images/cas/ currently contains six .jpg files on disk (migo_chat.jpg, migo_chores.jpg,                  
  │ migo_deliveries.jpg, migo_roulette.jpg, migo_tasks.jpg, together_cards.jpg), whereas cas_mascot_view.dart still references removed cas_*.png 
  │ paths and the spec lists .png extensions.                                                                                                    
                                                                                                                                                 
  • Plan for CasMascotView:                                                                                                                      
      • Never draw custom SVG/CustomPainter owls; route 100% of mascot placements through CasMascotView (removing raw Image.asset calls in       
      Onboarding, Splash, and Create Meet-up).                                                                                                   
      • Map semantic CasPose slots to the 6 mascot assets:                                                                                       
          • together_cards → Splash / Getting Started, Household Setup, Home Split Hero, Profile peeking accent, About/Celebrations              
          • migo_chat → Chat Directory Split Hero, Bills summary peek (phone pose in mockup), empty chat states                                  
          • migo_deliveries → Parcels summary peek & Parcels empty/received states                                                               
          • migo_tasks → Tasks summary peek & Tasks empty/completed states                                                                       
          • migo_chores → Lost & Found / Shared Items summary peek & chore states                                                                
          • migo_roulette → Task Roulette winner state & Leaderboard banner                                                                      
      • Support .png asset paths with seamless fallback to the .jpg files currently in assets/images/cas/ (via rootBundle manifest lookup or     
      graceful Image.asset fallback chain) and frame non-transparent raster backgrounds cleanly inside soft rounded/circular cards when          
      straddling dark or Forest Teal surfaces so there are no harsh square seams. Default excludeFromSemantics: true for decorative placements.  
                                                                                                                                                 
                                                                                                                                                 
  1.4 Shared Chrome & Motion Primitives (lib/core/motion/ & lib/shared/widgets/)                                                                 
                                                                                                                                                 
  Create a lightweight, centralized motion & shell kit translating every CSS/JS interaction from casama-app-mockup.html:                         
                                                                                                                                                 
   Widget / Module                                   │ Motion & Visual Specification
  ───────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────
   CasamaMotion (lib/core/motion/casama_motion.dart) │ Centralizes durations (press: 150ms, fabExit: 180ms, scrim/lightbox: 200ms, listPop:
                                                     │ 220ms, boardSlide/drawer: 250ms, sheet: 280ms, fabEnter: 320ms, camFlip: 350ms,
                                                     │ shutterFlash: 450ms, roulette: 4000ms), curves (springOvershoot = Cubic(0.34, 1.56, 0.64,
                                                     │ 1.0), rouletteDecel = Cubic(0.12, 0.7, 0.1, 1.0), Curves.easeOut, Curves.easeIn), and
                                                     │ CasamaMotion.reduced(context) (MediaQuery.disableAnimationsOf(context)).
   CasamaPressable                                   │ Wraps buttons, cards, pills, and tabs with AnimatedScale (0.95 default, 0.90 for
                                                     │ CasamaPressable.fab, 150ms Curves.easeOut) + optional HapticFeedback.selectionClick().
                                                     │ Collapses to instant zero-scale tap when reduced motion is active.
   CasamaWaveHeader & CasamaAmbientCanvas            │ CustomPainter rendering the stepped Forest Teal-to-Warm Beige organic waves + top-right
                                                     │ #F4B544 concentric orbital ornament, 48×48dp white circular Drawer/Back & Notification
                                                     │ buttons, optional right action pill (Spin Roulette, Setup Billing), and optional embedded
                                                     │ 4-tab Boards pill bar. CasamaAmbientCanvas paints the translucent 6%/9% lower body
                                                     │ curves.
   CasamaSplitHero & CasamaPeekingSummaryBar         │ CasamaSplitHero: 36% left CasMascotView + right 20dp white status card (Home, Chat).
                                                     │ CasamaPeekingSummaryBar: 2-metric 18dp white card with vertical hairline divider and
                                                     │ 76×76dp CasMascotView peeking from top: -44dp, right: 18dp (Parcels, Tasks, Bills,
                                                     │ Items).
   CasamaPillFilterRail & CasamaSegmentedTrack       │ Animated (150ms) horizontally scrollable 36dp filter pills (48dp hit zone; #37655E active
                                                     │ fill) and 48dp #EAE6DF segmented pill track with sliding/elevated #FFFFFF active thumb
                                                     │ (Parcels Upcoming/History, Items Lost/Found/Shared).
   CasamaSheetScaffold (showCasamaSheet)             │ Slide-up modal sheet (280ms Curves.easeOut, 200ms #1C2E4A 45% scrim + 2px blur), 28dp top
                                                     │ corners, 36×4dp drag handle, 44dp sage icon circle + title/subtitle + 48×48dp #EAE6DF
                                                     │ circular close button, SafeArea + SingleChildScrollView + viewInsets.bottom keyboard
                                                     │ padding.
   CasamaTopToast                                    │ Overlay pill toast (#1C2E4A, top: SafeArea + 16dp, 200ms fade/slide, 2200ms auto-hide)
                                                     │ replacing hidden behind-sheet SnackBars for copy-code, CASnap sent, and quick reactions.
  ──────                                                                                                                                         
  2. Navigation Shell, Route Architecture & Complete Screen Inventory                                                                            
                                                                                                                                                 
  2.1 5-Slot Bottom Shell, Slide-Over Drawer & Router (lib/features/dashboard/main_navigation_shell.dart, lib/core/router/app_router.dart)       
                                                                                                                                                 
  • 5-Slot Bottom Navigation Bar (72dp height + SafeArea, 28dp top radius, #FFFFFF / dark #14222B, 1px #DCE3E0 border):                          
      1. Home (Icons.cottage_rounded / home)                                                                                                     
      2. Boards (Icons.dashboard_rounded — opens the unified 4-tab BoardsHubScreen, remembering the last active sub-board: Parcels, Tasks, Bills,
      or Items)                                                                                                                                  
      3. Raised Center CASnap Trigger (64×64dp -24dp raised #E87461 circle with 4px white inner border, 3px #E87461 outer ring, coral shadow,    
      camera icon, and "CASnap" label; preserves Key('center_quicksnap_shutter_button'); 0.90 press scale; launches full-screen                  
      QuickSnapCameraScreen)                                                                                                                     
      4. Chat (Icons.chat_bubble_rounded + coral unread count badge)                                                                             
      5. Profile (Icons.person_rounded)                                                                                                          
  • Contextual Morphing Board FAB (CasamaMorphingFab):                                                                                           
      • Anchored at right: 16dp, bottom: 88dp inside MainNavigationShell only when Boards (slot 1) is active:                                    
      • Enters with 320ms spring overshoot (Cubic(0.34, 1.56, 0.64, 1.0)), exits in 180ms (Curves.easeIn), and morphs icon + label smoothly      
      across sub-tabs:                                                                                                                           
          • Parcels → add_box "Add parcel" (opens AddParcelSheet)                                                                                
          • Tasks → add_task "Add task" (opens NewTaskSheet)                                                                                     
          • Bills → edit_note "Edit billings" (opens SetupBillingSheet)                                                                          
          • Items → sell "Report item" (opens ReportItemSheet)                                                                                   
                                                                                                                                                 
  • Slide-Over Household Drawer (CasamaHouseholdDrawer):                                                                                         
      • Left slide-in (250ms Curves.easeOut, 300–320dp width, 28dp right corners) over #1C2E4A 45% scrim (200ms fade):                           
      • Forest Teal header (Community Space • N members, Casa 204, tap-to-copy INVITE CODE: CASA204 pill with CasamaTopToast, 56×56dp            
      CasMascotView).                                                                                                                            
      • Household Tools quick-jump list with live count badges (Parcels, Household Tasks, Bills & Payments, Lost & Found Items, and Task Roulette
      → switches to Boards → Tasks and opens TaskRouletteSheet).                                                                                 
      • Casa Highlights: Good Kasama Leaderboard card (#1 badge → pushes /leaderboard).                                                          
      • Footer: Invite Housemate (opens InviteHousemateSheet), My Household (switches to Profile), App Settings (/settings), and Privacy &       
      Permissions (/terms?readOnly=true).                                                                                                        
  • Router Compatibility (app_router.dart):                                                                                                      
      • Support query deep links on /boards?tab=parcels|tasks|bills|items, and redirect standalone legacy routes (/parcels, /maintenance, /bills,
      /lost-found, /roulette, /add-bill, /create-meetup) cleanly into the unified shell/sheets so existing callers and deep links continue       
      working without breakage.                                                                                                                  
                                                                                                                                                 
                                                                                                                                                 
  2.2 Complete Screen & Widget Inventory (lib/features/ & Feature Sheets)                                                                        
                                                                                                                                                 
   File Path                                  │                 Action                 │ Redesign / Binding Summary
  ────────────────────────────────────────────┼────────────────────────────────────────┼─────────────────────────────────────────────────────────
   Auth & Onboarding (starting.html)          │                                        │
   auth/splash_screen.dart                    │             Full Redesign              │ Forest Teal top stage (~42%) with house+sparkle mark,
                                              │                                        │ "Casama" wordmark, CasMascotView(together_cards),
                                              │                                        │ stepped waves into 28dp white bottom card ("Your shared
                                              │                                        │ home, simplified.", "Get Started →", "I already have an
                                              │                                        │ account"). Auto-redirect authenticated sessions when
                                              │                                        │ appropriate while preserving test entry.
   auth/auth_screen.dart                      │             Full Redesign              │ Implement both Sign Up (starting.html:1-123 — split-
                                              │                                        │ tone wave header, "Step 1 of 4" translucent pill,
                                              │                                        │ peeking CasMascotView, 28dp white card, #EAE4DC 50dp
                                              │                                        │ inputs, password toggles, inline Terms/Privacy
                                              │                                        │ checkbox, "Create Account →", "Log In" toggle) and Log
                                              │                                        │ In (starting.html:261-313 — "Welcome back", Forgot
                                              │                                        │ Password modal, "Log In", "OR", "One-Tap Demo Login").
                                              │                                        │ Bound to repo.register, repo.login,
                                              │                                        │ repo.recordTermsConsent.
   auth/login_screen.dart                     │         Consolidate / Redirect         │ Thin wrapper/redirect to AuthScreen(initialTabIndex: 1)
                                              │                                        │ so /login never drifts.
   auth/register_screen.dart                  │         Consolidate / Redirect         │ Thin wrapper/redirect to AuthScreen(initialTabIndex:
                                              │                                        │ 0).
   auth/optional_profile_screen.dart          │                 Reskin                 │ Match starting.html split-tone wave header ("Step 2 of
                                              │                                        │ 4"), 28dp white card, #EAE4DC inputs, tappable
                                              │                                        │ CasamaAvatar + ProfileCameraSheet, single Skip action.
   household/household_setup_screen.dart      │             Reskin + Wire              │ Match starting.html wave header ("Step 3 of 4"), Join
                                              │                                        │ (CASA204 pill) & Create tabs with CasMascotView, wired
                                              │                                        │ into post-signup FTUE before tour/dashboard.
   onboarding/device_permissions_screen.dart  │              Reskin + Fix              │ Match wave header ("Step 4 of 4" only during
                                              │                                        │ onboarding; fromSettings mode pops cleanly back to
                                              │                                        │ /settings); bind toggles to
                                              │                                        │ repo.updateNotificationPreferences.
   onboarding/casama_intro_screen.dart &      │          Consolidate + Reskin          │ Streamlined, scrollable CasMascotView tour card
   interactive_tutorial_screen.dart           │                                        │ matching the new 5-slot shell (Home, Boards, CASnap,
                                              │                                        │ Chat, Profile); retire duplicate tutorial_screen.dart
                                              │                                        │ (redirect /tutorial → /interactive-tutorial).
   Shell, Drawer, Home & Calendar             │                                        │
   dashboard/main_navigation_shell.dart       │             Full Redesign              │ 5-slot rounded-top bar, raised CASnap shutter,
                                              │                                        │ CasamaMorphingFab on Boards, CasamaHouseholdDrawer
                                              │                                        │ host, and CasamaTopToast overlay.
   dashboard/dashboard_screen.dart            │             Full Redesign              │ Matches casama-app-mockup.html:72-85 +
                                              │                                        │ core_screens.html:1-313: CasamaWaveHeader (Good
                                              │                                        │ evening, <Name>), CasamaSplitHero (together_cards + "3
                                              │                                        │ of 4 Home" card + horizon pills), "Who's Home" card
                                              │                                        │ with animated "You: Home / Out" inline toggle
                                              │                                        │ (repo.updatePresence) + long-press/tap note sheet,
                                              │                                        │ dynamic "Live Attention Needed" rows (overdue bills →
                                              │                                        │ Boards: Bills, urgent tasks → Boards: Tasks), Shared
                                              │                                        │ CASnaps card, and compact "Casa Schedule" card.
   calendar/household_calendar_view.dart      │             Full Redesign              │ Compact 5-day pill strip (core_screens.html:214-248)
                                              │                                        │ with expandable full-month sheet/toggle, filter pills
                                              │                                        │ (All, Parcels, Tasks, Bills, Meetups) including
                                              │                                        │ repo.bills deadlines, O(1) date indexing, and real
                                              │                                        │ formatted times.
   Unified Boards Hub, Roulette & Billing     │                                        │
   Sheets                                     │                                        │
   dashboard/boards_screen.dart               │             Full Redesign              │ Becomes BoardsHubScreen: persistent CasamaWaveHeader
                                              │                                        │ with embedded 4-tab pill bar (Parcels, Tasks, Bills,
                                              │                                        │ Items) + PageView / directional slide-fade (250ms
                                              │                                        │ Curves.easeOut) synced with CasamaMorphingFab.
   parcels/parcels_screen.dart                │             Full Redesign              │ Embeddable board view + standalone wrapper:
                                              │                                        │ CasamaPeekingSummaryBar (migo_deliveries, Expected
                                              │                                        │ count + COD total), CasamaSegmentedTrack (Upcoming /
                                              │                                        │ History), white 20dp parcel cards showing For
                                              │                                        │ <buyerName>, note box, "Can receive:" avatars, and 48dp
                                              │                                        │ "Can't Receive" (repo.toggleParcelAvailability) + "I
                                              │                                        │ Got It" (repo.receiveParcel) for all couriers, plus
                                              │                                        │ slide-up AddParcelSheet (repo.addParcel).
   tasks/maintenance_screen.dart              │             Full Redesign              │ Header "Spin Roulette" pill, CasamaPeekingSummaryBar
                                              │                                        │ (migo_tasks), CasamaPillFilterRail (All, To Do, In
                                              │                                        │ Progress, Done), compact task cards with 48×48dp
                                              │                                        │ animated checkbox + strikethrough micro-state
                                              │                                        │ (repo.completeTask), real category/assignee/due
                                              │                                        │ subtitle, inline "Spin" pill on unassigned DIY tasks,
                                              │                                        │ and slide-up NewTaskSheet (repo.addTask).
   chore_roulette/chore_roulette_screen.dart  │            Convert to Sheet            │ Refactored into TaskRouletteSheet (casama-app-
                                              │                                        │ mockup.html:180-188, core_screens.html:3316-3627;
                                              │                                        │ /roulette opens Tasks + this sheet): target task
                                              │                                        │ selector, "✓ Home Housemates (N)" filter pill, "1 spin
                                              │                                        │ / 24h • Ready" cooldown pill (SharedPreferences
                                              │                                        │ timestamp), 240×240dp housemate slice wheel
                                              │                                        │ (AnimationController 4000ms, Cubic(0.12, 0.7, 0.1,
                                              │                                        │ 1.0), exact 12 o'clock landing math), center 72dp
                                              │                                        │ #C44938 SPIN hub, and post-spin "Reject (-3 pts)" /
                                              │                                        │ "Accept (+2 bonus)" decision bar.
   bills/bills_dashboard_screen.dart          │             Full Redesign              │ Header "Setup Billing" pill, CasamaPeekingSummaryBar
                                              │                                        │ (migo_chat, Total Due including overdue bills + Overdue
                                              │                                        │ highlight), CasamaPillFilterRail (All, Overdue, Unpaid,
                                              │                                        │ Paid, categories), 20dp bill cards (#FFCDD2 border when
                                              │                                        │ overdue, edit pencil opening SetupBillingSheet pre-
                                              │                                        │ selected to that bill, "Mark Paid" →
                                              │                                        │ repo.markBillPaid).
   bills/add_bill_screen.dart                 │            Convert to Sheet            │ Refactored into SetupBillingSheet
                                              │                                        │ (core_screens.html:2998-3314): quick-select pill strip
                                              │                                        │ (+ New Bill or existing bills), category chips with
                                              │                                        │ Material icons, #EAE6DF 50dp inputs (Bill Name, Amount
                                              │                                        │ Due ₱, Due Date picker), reminder pills (1d, 3d, On due
                                              │                                        │ date), privacy note, and "Save Billing Setup" calling
                                              │                                        │ repo.addBill or repo.updateBill.
   bills/bill_detail_screen.dart              │                 Reskin                 │ Reskinned with CasamaWaveHeader, 20dp white hairline
                                              │                                        │ cards, tabular ₱ amounts, Edit trigger
                                              │                                        │ (SetupBillingSheet), and AA semantic badges.
   items/lost_found_screen.dart               │             Full Redesign              │ CasamaPeekingSummaryBar (migo_chores, Open Reports +
                                              │                                        │ Shared Items), CasamaSegmentedTrack (Lost, Found,
                                              │                                        │ Shared), 20dp item cards (Manage Post on own items;
                                              │                                        │ Message using item.reportedBy UUID + I Found It /
                                              │                                        │ That's Mine via repo.claimItem; Shared appliance strip
                                              │                                        │ with Borrow/Return/Ping), and slide-up ReportItemSheet
                                              │                                        │ (repo.postItem, no fake Unsplash photos).
   CASnap (lib/features/quicksnap/)           │                                        │
   quicksnap/quicksnap_home_widget.dart       │             Full Redesign              │ Redesigned into the Home Shared CASnaps card (casama-
                                              │                                        │ app-mockup.html:142): header with total photo badge +
                                              │                                        │ "View all ›", 3×2 square rounded-16dp grid (5 recent
                                              │                                        │ repo.quickSnaps tiles with sender avatar/name & "To
                                              │                                        │ You" badge + 6th +N View all sage tile, or warm empty
                                              │                                        │ state CTA), and "Browse all N shared shots →" button.
   quicksnap/quicksnap_camera_screen.dart     │ Full Redesign (Preserve Camera Engine) │ Keeps live CameraController, permission flow,
                                              │                                        │ Retake/Send state, and test Keys, restyled to casama-
                                              │                                        │ app-mockup.html:202-217: #070C16 dark canvas, top Close
                                              │                                        │ + "Everyone ▾" pill (opening #141B29 slide-up "Send
                                              │                                        │ CASnap to..." recipient selector sheet) + Flash toggle,
                                              │                                        │ centered 1:1 32dp-rounded viewfinder with corner frame
                                              │                                        │ brackets + CasMascotView fallback + 450ms white shutter
                                              │                                        │ flash overlay, bottom History (opens Gallery) + 84dp
                                              │                                        │ #F4B544 gold-ringed shutter + Flip (350ms 180° icon
                                              │                                        │ rotation), and CasamaTopToast("Sent to ...").
   quicksnap/quicksnap_feed_screen.dart &     │             Full Redesign              │ Redesigned into Casa 204 Gallery (casama-app-
   quicksnap_image_view.dart                  │                                        │ mockup.html:194-200): CasamaWaveHeader (Close,
                                              │                                        │ title/count, Camera button), sticky #EAE4D7 backdrop-
                                              │                                        │ blurred sender filter pills (All, Your Shots, per-
                                              │                                        │ housemate, Direct), date-grouped (Today, Yesterday,
                                              │                                        │ Month) 3-column square grid, and 200ms Hero/fade
                                              │                                        │ Lightbox Viewer overlay supporting existing
                                              │                                        │ repo.reactToQuickSnap, repo.commentOnQuickSnap, and
                                              │                                        │ repo.deleteQuickSnap.
   Casama Connect (Chat & Sheets)             │                                        │
   chat/chat_directory_screen.dart            │             Full Redesign              │ Matches core_screens.html:616-635 + casama-app-
                                              │                                        │ mockup.html:87-94: CasamaWaveHeader with person_add
                                              │                                        │ (InviteHousemateSheet) + calendar_add_on
                                              │                                        │ (PlanMeetupSheet) + Bell, CasamaSplitHero (migo_chat +
                                              │                                        │ "N Unread • N Space" card), 48dp white search pill,
                                              │                                        │ Forest Teal #37655E Household Group Chat hero card,
                                              │                                        │ Custom Chat Spaces with single + Space / Code pill,
                                              │                                        │ unified Housemates card with live presence dots, and
                                              │                                        │ Active Meet-up card. (Eliminates the 6 duplicate
                                              │                                        │ buttons.)
   chat/group_chat_screen.dart,               │   Full Redesign (Unified Primitives)   │ Share one CasamaChatHeader (core_screens.html:756-831),
   direct_chat_screen.dart,                   │                                        │ CasamaChatBubble (white incoming w/ #37655E sender
   chat_space_screen.dart                     │                                        │ name; #37655E Forest Teal outgoing w/ white text +
                                              │                                        │ done_all + 12h time; cached Uint8List images),
                                              │                                        │ CasamaMeetupCard (3-column 48dp animated RSVP pills:
                                              │                                        │ Going, Maybe, Can't), and docked CasamaChatComposer
                                              │                                        │ (48dp #EAE6DF + button, #EAE6DF pill input, 48dp
                                              │                                        │ #E87461 send button). Removes fake Call/Mute/Clear
                                              │                                        │ stubs in Direct Chat.
   chat/create_meetup_screen.dart             │            Convert to Sheet            │ Refactored into PlanMeetupSheet (core_screens.html:982-
                                              │                                        │ 1251): Activity Title, 2-column native Date & Time
                                              │                                        │ pickers, Location input + "Zero GPS tracking" caption,
                                              │                                        │ selectable Invitee pills, and "Send Meet-up
                                              │                                        │ Invitation".
   household/add_housemate_dialog.dart &      │         Consolidate + Redesign         │ Unified into InviteHousemateSheet
   shared/widgets/invite_housemate_sheet.dart │                                        │ (core_screens.html:636-744): CASA204 copy bar with
                                              │                                        │ inline "Copied!" morph (2000ms), 3 privacy check
                                              │                                        │ bullets, horizontal Current Housemates pill strip,
                                              │                                        │ optional expandable handle-invite/pending section bound
                                              │                                        │ to repo.invitations, and "Share Invite Link & Code"
                                              │                                        │ CTA.
   Profile, Points, Settings & Legal          │                                        │
   profile/profile_screen.dart                │             Full Redesign              │ Matches core_screens.html:315-577: CasamaWaveHeader,
                                              │                                        │ 92dp coral-ringed avatar with 14°-tilted peeking
                                              │                                        │ CasMascotView + 32dp #C44938 camera badge
                                              │                                        │ (ProfileCameraSheet), single "Edit Profile" pill, Good
                                              │                                        │ Kasama Points card (pushes /leaderboard or opens Points
                                              │                                        │ Ledger sheet), Personal Information card, Account &
                                              │                                        │ Preferences card (My Household, App Settings, Privacy &
                                              │                                        │ Permissions), and #FFEBEE/#C62828 "Log Out" pill with
                                              │                                        │ confirmation dialog.
   profile/edit_profile_dialog.dart &         │                 Reskin                 │ Reskinned onto CasamaSheetScaffold, #EAE6DF inputs,
   shared/widgets/profile_camera_sheet.dart   │                                        │ tappable avatar + 48dp preset chips, preserving
                                              │                                        │ ProfileCameraSheet and
                                              │                                        │ Key('profile_camera_close_button').
   points/leaderboard_screen.dart             │           Reskin + Live Data           │ CasamaWaveHeader, CasMascotView(migo_roulette) hero
                                              │                                        │ card, dynamic repo.members ranking (replacing static
                                              │                                        │ hardcoded list), Monthly/History tabs (integrating
                                              │                                        │ repo.pointHistory), and updated +5 / +2 pts rules card.
   settings/app_settings_screen.dart          │           Reskin + Declutter           │ CasamaWaveHeader, 20dp white/dark hairline cards,
                                              │                                        │ animated Light/Dark/System theme pills, persisted
                                              │                                        │ notification switches, kDebugMode-gated diagnostics
                                              │                                        │ (hiding "Mock Mode" & fake cache reset in release UI),
                                              │                                        │ and proper /permissions?fromSettings=true &
                                              │                                        │ /terms?tab=...&readOnly=true routing.
   legal/terms_consent_screen.dart &          │              Reskin + Fix              │ Wave header + 20dp cards, full-row 48dp consent
   terms_privacy_screen.dart                  │                                        │ checkboxes, `?tab=terms
  ──────                                                                                                                                         
  3. Phased Frontend Implementation Order                                                                                                        
                                                                                                                                                 
  1. Phase 1 — Design System, Mascot Adapter & Motion Foundation                                                                                 
      • Implement CasamaPalette (ThemeExtension) + harmonized Light/Dark tokens in colors.dart & app_theme.dart (Plus Jakarta Sans + Inter,      
      tabular numerals, dark TextTheme fix).                                                                                                     
      • Build casama_motion.dart (CasamaPressable, CasamaDirectionalSwitcher, CasamaMorphingFab, CasamaTopToast), CasamaWaveHeader,              
      CasamaAmbientCanvas, CasamaSplitHero, CasamaPeekingSummaryBar, CasamaPillFilterRail, CasamaSegmentedTrack, CasamaSheetScaffold, and update 
      CasMascotView (migo_* / together_cards mapping).                                                                                           
  2. Phase 2 — Splash, Onboarding & Auth (starting.html)                                                                                         
      • Redesign SplashScreen and AuthScreen (Sign Up + Log In), reskin OptionalProfileScreen, HouseholdSetupScreen, DevicePermissionsScreen, and
      streamlined Tour, and convert /login, /register, /tutorial into clean redirects.                                                           
  3. Phase 3 — 5-Slot Shell, Slide-Over Drawer, Home Dashboard & Schedule                                                                        
      • Upgrade MainNavigationShell + app_router.dart + CasamaHouseholdDrawer.                                                                   
      • Redesign DashboardScreen (Split Mascot Hero, animated "Who's Home" card, dynamic "Live Attention Needed", Shared CASnaps slot, and       
      compact Casa Schedule / HouseholdCalendarView).                                                                                            
  4. Phase 4 — Unified Boards Hub, Action Sheets & Task Roulette Physics                                                                         
      • Transform BoardsScreen into the 4-tab swipeable BoardsHubScreen with directional 250ms transitions and morphing contextual FAB.          
      • Redesign Parcels, Tasks, Bills, and Items views + slide-up sheets (AddParcelSheet, NewTaskSheet, SetupBillingSheet, ReportItemSheet),    
      reskin BillDetailScreen, and build TaskRouletteSheet (4000ms decelerating housemate wheel, exact slice math, Accept/Reject stakes, 24h     
      cooldown).                                                                                                                                 
  5. Phase 5 — CASnap Camera, Recipient Selector, Gallery & Lightbox                                                                             
      • Reskin QuickSnapCameraScreen (#070C16 frame, 1:1 bracketed viewfinder, 450ms shutter flash, 350ms 180° flip rotation, #141B29 recipient  
      sheet, CasamaTopToast), QuickSnapHomeWidget (3×2 Shared CASnaps card), and QuickSnapFeedScreen (Casa 204 Gallery with sticky filters, date 
      groups, and 200ms Hero/fade Lightbox).                                                                                                     
  6. Phase 6 — Casama Connect (Chat Directory, Unified Threads & Sheets)                                                                         
      • Redesign ChatDirectoryScreen, extract shared CasamaChatHeader / CasamaChatBubble / CasamaChatComposer / CasamaMeetupCard across          
      GroupChatScreen, DirectChatScreen, and ChatSpaceScreen, and wire PlanMeetupSheet, CreateChatSpaceSheet, and consolidated                   
      InviteHousemateSheet.                                                                                                                      
  7. Phase 7 — Profile Hub, Leaderboard, Settings, Legal & Test Sync                                                                             
      • Redesign ProfileScreen (with tilted peeking mascot + confirmed Log Out), reskin EditProfileDialog / ProfileCameraSheet, wire live        
      LeaderboardScreen, declutter/reskin AppSettingsScreen + Legal screens, and synchronize widget/E2E tests.                                   
                                                                                                                                                 
  ──────                                                                                                                                         
  4. Frontend Verification Checkpoints & Key Pitfalls                                                                                            
                                                                                                                                                 
  Verification Matrix (Run at Each Phase Gate & Final Sign-Off)                                                                                  
                                                                                                                                                 
  1. Motion Smoothness & Frame Budget:                                                                                                           
      • Verify all animations use GPU-composited transforms/opacities (AnimatedScale, SlideTransition, FadeTransition, RotationTransition,       
      AnimatedBuilder on Roulette wheel) with zero per-frame full-screen setState and memoized Uint8List base64 image decoding in                
      chats/items/avatars.                                                                                                                       
  2. Reduced-Motion Accessibility (MediaQuery.disableAnimationsOf(context)):                                                                     
      • Widget-test with MediaQueryData(disableAnimations: true) confirming CasamaPressable skips scaling, Boards switches tabs without          
      horizontal slide, CasamaMorphingFab swaps without spring overshoot, CASnap skips shutter flash/flip spin, and TaskRouletteSheet resolves   
      the winner cleanly without a 4-second spin.                                                                                                
  3. Safe-Area, Keyboard IME & Responsive Layout Checks:                                                                                         
      • Test across 360×640 (compact phone), 390×844 (standard phone), landscape (844×390), 768×1024 (tablet), and textScaler: TextScaler.       
      linear(1.4) — verifying zero RenderFlex overflows, proper viewInsets.bottom clearance on all 7 slide-up sheets + chat composer, and        
      ≥48×48dp touch targets.                                                                                                                    
  4. Light & Dark Theme Parity:                                                                                                                  
      • Verify every redesigned screen and modal sheet in both Light (#EAE4D7 / #37655E / #FFFFFF) and Dark (#0D171E / #1D3B36 / #1A2C37) modes  
      for ≥4.5:1 text contrast and zero unadapted #FFFFFF / #1C2E4A leaks.                                                                       
  5. Static Analysis & Automated Tests:                                                                                                          
      • flutter analyze → 0 issues.                                                                                                              
      • flutter test test/unit_test.dart → 100% pass unchanged (proves zero regressions in MockRepository / models).                             
      • flutter test test/widget_test.dart test/e2e_integration_test.dart → Update copy/finder assertions to match the new CASnap / Boards /     
      starting.html labels while preserving all existing test Keys (center_quicksnap_shutter_button, quicksnap_shutter_button,                   
      send_quicksnap_button, allow_camera_permission_button, deny_camera_permission_button, profile_camera_close_button), plus add targeted      
      widget tests for Boards swipe/morphing FAB and Task Roulette landing angle accuracy.