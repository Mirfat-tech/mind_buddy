# Responsive Pass Report

## Scope

Priority pass executed for:

- Onboarding spotlight/tooltips
- Brain Fog
- Templates / Log Tables
- Insights (including dense cards like mood/water)
- Chat composer

Automated validation command:

- `flutter test test/responsive/responsive_breakpoint_smoke_test.dart`
- Result: `All tests passed`
- `flutter test test/responsive/responsive_visual_baseline_test.dart`
- Result: `All tests passed` (golden/screenshot baselines for onboarding expression, brain fog, and insights at SE/6.1/iPad split 1/3).

## Files Updated

- `/Users/mirfatal-ghaithy/mind_buddy/lib/guides/guide_manager.dart`
- `/Users/mirfatal-ghaithy/mind_buddy/lib/features/brain_fog/brain_fog_screen.dart`
- `/Users/mirfatal-ghaithy/mind_buddy/lib/features/templates/templates_screen.dart`
- `/Users/mirfatal-ghaithy/mind_buddy/lib/features/templates/log_table_screen.dart`
- `/Users/mirfatal-ghaithy/mind_buddy/lib/features/insights/insights_screen.dart`
- `/Users/mirfatal-ghaithy/mind_buddy/lib/features/chat/chat_screen.dart`
- `/Users/mirfatal-ghaithy/mind_buddy/lib/features/onboarding/onboarding_auth_screen.dart`
- `/Users/mirfatal-ghaithy/mind_buddy/docs/RESPONSIVE_QA.md`
- `/Users/mirfatal-ghaithy/mind_buddy/test/responsive/responsive_breakpoint_smoke_test.dart`

## What Changed

### Guides / Spotlight

- Dynamic tooltip clamping to safe area.
- Overlay and spotlight taps both advance.
- Added tap debounce to prevent multi-step skips.
- Added robust guide start timing (post-frame + retry in Brain Fog where layout is dynamic).

### Brain Fog

- Guide startup waits for target readiness.
- Unstable moving target replaced by stable canvas container target.
- Added one-time-per-open guard to avoid guide restart loops.

### Insights

- Removed guide auto-trigger from build path.
- Added one-shot scheduled guide launch.
- Added `requireAllTargetsVisible` to avoid partial/late steps.
- Wrapped body in `SafeArea(bottom: true)`.

### Chat

- Composer now animates with keyboard insets.
- Increased message-list bottom padding to keep last items/composer visible.
- Reduced risk of hidden controls on smaller phones and in landscape.

### Onboarding Auth

- Converted to scrollable + safe-area layout.
- Added keyboard-aware bottom padding.
- Preserves bottom “I’ll decide later” and helper text without overflow.

### Log Table

- Duration picker bottom sheet now uses `isScrollControlled`, safe-area, and inset-aware sizing for small heights/landscape.

### Home

- Templates section header made responsive with truncation-aware title.
- Grid now adapts to narrow widths (`2` columns under very narrow widths).
- Template card badge area uses scale-down fitting to prevent row overflow.

### Journal

- Added Journals List + New Journal to breakpoint smoke coverage.
- Verified no overflow across configured targets/text scales in automated suite.

## Per-Screen Summary

- Home
  - Files: `lib/features/home/widgets/templates_section.dart`
  - Fixes: adaptive grid columns, overflow-safe header row and badge row.
  - Remaining blockers: none in automated smoke suite.
- Onboarding + Auth
  - Files: `lib/features/onboarding/onboarding_auth_screen.dart`
  - Fixes: scrollable safe-area layout, keyboard-aware bottom padding, removed unbounded `Spacer`.
  - Remaining blockers: none in automated smoke suite.
- Brain Fog + Spotlight
  - Files: `lib/guides/guide_manager.dart`, `lib/features/brain_fog/brain_fog_screen.dart`
  - Fixes: stable multi-step sequencing, overlay/spotlight tap progression, safer start timing.
  - Remaining blockers: none in automated smoke suite.
- Templates + Log Table
  - Files: `lib/features/templates/templates_screen.dart`, `lib/features/templates/log_table_screen.dart`
  - Fixes: safer list/card sizing, bottom sheet inset handling.
  - Remaining blockers: none in automated smoke suite.
- Journal
  - Files: `test/responsive/responsive_breakpoint_smoke_test.dart`
  - Fixes: added Journals List and New Journal to responsive smoke validation.
- Remaining blockers: none in automated smoke suite.
- Chat
  - Files: `lib/features/chat/chat_screen.dart`
  - Fixes: keyboard inset-aware composer padding + bottom list padding.
- Remaining blockers: none in automated smoke suite.
- Insights
  - Files: `lib/features/insights/insights_screen.dart`
  - Fixes: overflow-safe section titles/month header/stats, compact chart sizing for constrained heights.
  - Remaining blockers: none in automated smoke suite.
- Settings
  - Files: `test/responsive/responsive_breakpoint_smoke_test.dart`
  - Fixes: validated at all configured breakpoints.
  - Remaining blockers: none in automated smoke suite.

## Known Remaining Risks / Follow-up

- Interactive simulator sweeps are still recommended for media capture/upload flows and long-session keyboard interactions.

## How To Reproduce Previous Overflow Bugs

1. Home template card row overflow
- Open Home on narrow phone width (`375x667` or text scale `1.3`).
- Previous bug: template header/badge row overflowed horizontally in `templates_section.dart`.
- Fixed by adaptive grid count + row truncation/fitting.

2. Onboarding auth unbounded flex / overflow
- Open onboarding auth on short-height device (`iPhone SE` size).
- Previous bug: `Spacer` inside scrollable column caused unbounded height flex assertions.
- Fixed by removing flex-only spacer and using bounded spacing with scroll-safe layout.

3. Insights header/card/chart overflows
- Open Insights on `iPhone 6.1` and `iPad split 1/3`, text scale `1.3`.
- Previous bugs:
  - Month header row overflow right.
  - Habit card metric row overflow right.
  - Water chart footer/cell vertical overflow.
- Fixed with expanded/truncated header, stat-column fitting, and compact chart sizing on tight heights.

4. Chat keyboard clipping risk
- Open chat and simulate keyboard inset.
- Previous risk: composer and bottom messages could be clipped under keyboard.
- Fixed by keyboard inset animated bottom padding + larger list bottom padding.

## Simulator Verification

- Attempted real-simulator verification commands:
  - `flutter devices`
  - `xcrun simctl list devices`
  - `flutter run -d B3BF6B1A-9339-476E-9B48-9CFC983DDA3F --no-resident --target lib/main.dart` (iPhone SE)
- Available simulator inventory confirmed includes:
  - iPhone SE (3rd generation)
  - iPhone 15 Pro Max
  - iPad Pro (12.9-inch) (6th generation)
- Current environment limitation:
  - Long-running Xcode simulator builds prevented completing full manual visual sweeps in this pass for SE, 15 Pro Max, and iPad split-view interaction checks.
  - Because of that, manual “no clipping” visual confirmation on those three simulators is not marked as completed here.
- Automated substitute completed:
  - Breakpoint smoke tests + visual baseline tests across SE/6.1/iPad split 1/3 with passing results.
