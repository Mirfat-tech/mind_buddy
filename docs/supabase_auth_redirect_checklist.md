# Supabase Auth Redirect Checklist

Use this in Supabase Dashboard -> Authentication -> URL Configuration.

## 1) Site URL
- Set **Site URL** to your real app/web domain (not the Supabase project URL).
- Example: `https://brainbubble.app`

## 2) Redirect URLs
Add these redirect URLs:

- `https://brainbubble.app/auth/callback`
- `brainbubble://auth/callback`
- `com.brainbubble.app://auth/callback`

Optional dev URLs:

- `http://localhost:3000/auth/callback`
- `http://localhost:5173/auth/callback`
- `http://127.0.0.1:3000/auth/callback`
- `http://127.0.0.1:5173/auth/callback`

## 3) Provider configuration
- Google and Apple providers enabled in Supabase.
- OAuth client IDs/secrets configured correctly.
- Bundle/package IDs match app settings:
  - iOS bundle ID in Apple auth settings.
  - Android package + SHA fingerprints in Google auth settings.

## 4) App redirect behavior
- Flutter OAuth requests must use: `redirectTo: brainbubble://auth/callback`
- Deep link callback must parse and exchange session from callback URL.

## 5) Expected UX outcome
- Hosted page no longer shows confusing destination text like project-ref URLs.
- App returns directly to BrainBubble callback deep link and creates session.
