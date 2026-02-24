# mind_buddy

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## OAuth Deep Link Flow

- OAuth start calls `supabase.auth.signInWithOAuth(...)` with:
  - `redirectTo: 'brainbubble://auth/callback'`
  - `authScreenLaunchMode: LaunchMode.externalApplication`
- `AuthDeepLinkHandler` listens on app start for both:
  - initial link (`getInitialLink`) for cold starts
  - runtime link stream (`uriLinkStream`)
- Callback handling:
  - `brainbubble://auth/callback?code=...` -> `exchangeCodeForSession(code)`
  - token/hash callback -> `getSessionFromUrl(uri)`
- Deep link registration:
  - iOS `CFBundleURLTypes` includes `brainbubble`
  - Android `AndroidManifest.xml` includes `scheme=brainbubble host=auth path=/callback`
