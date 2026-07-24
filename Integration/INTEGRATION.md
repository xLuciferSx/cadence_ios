# Cadence — Accounts + RevenueCat integration (DRAFT)

These files are **not yet part of any Xcode target**, so they don't affect the
build until you add them. They're written in the app's swift-dependencies style.

- `BillingClient.swift` — RevenueCat wrapper (`@Dependency(\.billing)`).
- `AuthClient.swift` — Google/Apple → backend token exchange + `/v1/me`
  (`@Dependency(\.auth)`).

## 1. Add packages (Xcode → File → Add Package Dependencies)
- RevenueCat: `https://github.com/RevenueCat/purchases-ios` → add **RevenueCat** to the **app** target.
- Google Sign-In: `https://github.com/google/GoogleSignIn-iOS` → app target.
- (Apple sign-in uses the built-in **AuthenticationServices**; enable the
  "Sign in with Apple" capability on the app target.)

Then drag `BillingClient.swift` and `AuthClient.swift` into a target that can see
`Dependencies` and `KeyboardFoundation` (e.g. a new `Accounts` SPM module in
`KeyboardModules`, or the app target).

## 2. Configure at launch (VoiceKeyboardApp.swift)
```swift
@Dependency(\.billing) var billing
init() {
  billing.configure("test_CXEDAvYmamHjtliYwpJBQSAndAe") // RevenueCat PUBLIC SDK key
}
```

## 3. Sign in, then link RevenueCat to the Cadence user
```swift
@Dependency(\.auth) var auth
@Dependency(\.billing) var billing

// Google (after GoogleSignIn returns an idToken):
let session = try await auth.signInWithGoogle(idToken)
let account = try await auth.me()
await billing.logIn(account.user.id)   // <-- makes webhooks map to this user
```
Apple: use `ASAuthorizationController`; pass the `identityToken` (and, on first
sign-in only, the name/email) to `auth.signInWithApple(...)`.

## 4. Show the paywall from the backend catalogue
```swift
let packages = try await billing.currentOffering()      // RevenueCat packages
// price/marketing copy can come from GET /billing/plans on the backend
let becamePro = try await billing.purchase(packages[0]) // native App Store sheet
```

## 5. Gate Pro features on the backend (source of truth)
```swift
let account = try await auth.me()
if account.isPro { /* unlock */ }
// or account.remaining.cleanups == nil (unlimited) / > 0
```
`/v1/*` also enforces quota server-side (429 `quota_exceeded` when exceeded), so
the client gate is UX only.

## 6. Use the account token for the keyboard (optional, later)
Today the keyboard authenticates with the static device token in
`AppConfig.deviceToken`. To move to per-user JWTs, have `AppConfig`'s backend
bearer prefer the stored `accountAccessToken` (written by `AuthClient`) when
present, falling back to the device token. Refresh via `auth.refresh()` on 401.

## Notes
- Tokens are stored in the shared App Group in this draft; move to the shared
  **Keychain** (`KeyboardFoundation/Keychain.swift`) for production.
- Entitlement id is `pro` on both sides (RevenueCat + backend
  `REVENUECAT_ENTITLEMENT_PLANS`). Keep them in sync.

## 8. Email/password (primary) + feature switch
Email/password is the default sign-in. Google/Apple are behind backend feature
switches (`AUTH_GOOGLE_ENABLED` / `AUTH_APPLE_ENABLED`, off by default) and are
also surfaced to the client via `GET /auth/config`.

```swift
@Dependency(\.auth) var auth

// Decide which buttons to show:
let methods = try await auth.config()          // .password / .google / .apple
// Render the email+password form when methods.password; show Google/Apple
// buttons only when methods.google / methods.apple.

// Create an account / sign in:
let session = try await auth.register(email, password, name)   // POST /auth/register
let session = try await auth.signInWithEmail(email, password)  // POST /auth/login
```
Keep the Google/Apple code paths compiled but hidden behind `methods.google` /
`methods.apple`, so flipping the backend flags turns them on with no app update.
