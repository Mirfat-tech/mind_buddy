# Responsive QA Checklist (MyBrainBubble)

This checklist tracks responsive validation across priority screens and target devices.

## Targets

- iPhone SE (3rd gen)
- iPhone 14/15 (6.1")
- iPhone 15 Pro Max
- iPad 10th gen (10.9")
- iPad Pro 12.9/13"
- iPad Pro split-view 50/50
- iPad Pro split-view 1/3
- Pixel 8
- Galaxy S24
- Galaxy S24 Ultra
- Galaxy Tab S6 Lite
- Galaxy Tab S9

## Screen Coverage

- Home
- Onboarding (including bubble layout)
- Auth
- Brain Fog
- Templates
- Log Tables
- Journal (entry + media flow)
- Chat
- Insights
- Settings
- Guide / Spotlight overlays

## Quality Rules

- No `RenderFlex overflowed` / `BOTTOM OVERFLOWED` errors.
- No clipped spotlight/tooltips.
- Safe area respected on top/bottom/notch/home indicator.
- Keyboard insets respected (composer/actions not hidden).
- Text scale 1.0 to 1.3 remains readable and functional.
- Landscape and split-view remain usable.

## Layout Conventions

- Use `SafeArea` at top-level screen body so status bar/notch/home indicator are always respected.
- Use a scrollable root (`SingleChildScrollView`/`ListView`) when vertical constraints can tighten (SE, split-view, keyboard up).
- For overlays/tooltips/spotlights, start in post-frame (`addPostFrameCallback`) and clamp to safe bounds after target layout is measured.
- Keyboard-aware screens must read `MediaQuery.viewInsets.bottom` and pad action/composer regions so controls stay visible.

## Current Pass Status

- Automated breakpoint smoke suite: `test/responsive/responsive_breakpoint_smoke_test.dart`
- Last run command:
  - `flutter test test/responsive/responsive_breakpoint_smoke_test.dart`
- Last run result:
  - `All tests passed` on all configured breakpoints and text scales (`1.0`, `1.3`).
- Covered screens in smoke suite:
  - Home
  - OnboardingAuth
  - OnboardingExpression
  - SignIn
  - BrainFog
  - Templates
  - LogTable
  - JournalsList
  - NewJournal
  - Chat
  - Insights
  - Settings

- Exact breakpoint list used by `test/responsive/responsive_breakpoint_smoke_test.dart`:
  - `iPhone SE 3` → `375 x 667`
  - `iPhone 6.1` → `393 x 852`
  - `iPhone 15 Pro Max` → `430 x 932`
  - `iPad 10.9` → `820 x 1180`
  - `iPad Pro 13` → `1032 x 1376`
  - `iPad Split 50/50` → `516 x 1376`
  - `iPad Split 1/3` → `344 x 1376`
  - `Pixel 8` → `412 x 915`
  - `Galaxy S24` → `412 x 915`
  - `Galaxy S24 Ultra` → `480 x 1032`
  - `Galaxy Tab S6 Lite` → `800 x 1280`
  - `Galaxy Tab S9` → `1024 x 1366`
  - `iPad Pro 13 Landscape` → `1376 x 1032`
  - `Tab Landscape` → `1366 x 1024`

## Manual Validation Matrix

Legend: `✅` pass in automated breakpoint smoke suite.

| Screen \\ Target | SE | 6.1 | Pro Max | iPad 10.9 | iPad Pro | Split 50/50 | Split 1/3 | Pixel 8 | S24 | S24 Ultra | Tab S6 Lite | Tab S9 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Home | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Onboarding + Guides | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Auth | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Brain Fog | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Templates | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Log Tables | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Journal | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Chat | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Insights | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Settings | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

## Follow-up Items

- Continue running the smoke suite on each UI merge.
- For final sign-off, run interactive simulator sweeps for camera/media/keyboard heavy flows (Journal media upload/edit, chat typing with software keyboard visible, onboarding spotlight navigation taps).
