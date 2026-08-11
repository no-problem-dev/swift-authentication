# Changelog

All notable changes to this project are recorded in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [7.0.0] - 2026-08-11

### Changed

- Every string this package renders or throws is now English. Nothing stops compiling, but the text
  changes in the consumer's app, not in this repository: `GoogleSignInButton`'s default `title` was
  `"Google でログイン"` and is now `"Sign in with Google"` (which is also what Google's branding
  rules specify, and what the adjacent `ASAuthorizationAppleIDButton` says in English), the
  configuration-error screen shown when no store is in the environment is translated, and the three
  `AuthError.configuration` messages thrown by `GoogleCredentialProvider` are translated. An app
  that wants Japanese passes its own `title`, as it already could.

## [6.0.0] - 2026-08-11

### Added

- **BREAKING** — `AuthError.sessionExpired(_:)` and `.notPermitted(_:)`, with the matching
  `AuthError.Code` cases. Source-breaking for an exhaustive switch.

  The package had **zero** references to `unauthorized`, `401` or `403`: it compiled without ever
  expressing the distinction, rethrowing a raw `APIError` and flattening everything into
  `postAuthenticationFailed`. That is the real defect the upstream split exposed — telling a dead
  session from a refusal the account will keep receiving is precisely this package's job, and
  re-authenticating fixes only the first.

  A 401 that reaches here now genuinely means the session is dead: api-client 5.0.0 already
  refreshes the token and resends once before raising it.

### Changed

- `AuthenticationStore` republishes an `AuthError` from a `PostAuthenticationAction` unchanged
  instead of wrapping it. Wrapping would have restored exactly what upstream just fixed — one case
  for both refusals, told apart only by unwrapping.
- Depends on swift-api-contract directly. api-client 3.0.3 stopped re-exporting it, so every symbol
  this package took from there was arriving through a re-export that is gone.


### Added

- **`AuthError.sessionExpired` and `AuthError.notPermitted`.** swift-api-client 4.0.0 splits
  `APIError.unauthorized` into a 401 and a 403, and this is the package that exists to act on
  that difference. A 401 means the session is dead and a new sign-in is the fix — the client
  has already refreshed the token and resent once by the time it surfaces, so the credential
  in hand will not start working. A 403 means the account itself is refused, and re-signing-in
  produces the same answer, so a flow that responds to it the same way loops. Both carry the
  underlying error, which carries the response body the server sent.

### Changed

- **BREAKING** — `APIUserProvisioning.perform(for:)` raises those two instead of passing an
  `APIError` through, and `AuthenticationStore` publishes an `AuthError` from a
  `PostAuthenticationAction` unchanged rather than wrapping it in
  `postAuthenticationFailed`. Wrapping would have put the caller back where it started: one
  case covering both refusals, told apart only by unwrapping. Code matching
  `AuthError.Code.postAuthenticationFailed` for a 401 or a 403 now matches `.sessionExpired`
  or `.notPermitted`.
- Raised the swift-api-client pin to 5.0.0, and `AuthenticationAPI` depends on
  swift-api-contract directly. api-client stopped re-exporting `APIContract` in 3.0.3, so the
  contract types this target names in its own public API — `APIExecutable`, `APIContract`,
  `EmptyOutput` — had no module to come from.

### Known limitation

- A permanently refused account is retried on every auth-state change. `AuthenticationStore`
  records provisioning as one claimed user id, which cannot distinguish "not attempted" from
  "refused for good": keeping the claim would report the user as authenticated without having
  provisioned, so the claim is released and the next emission tries again.

## [5.2.0] - 2026-08-08

### Added

- **The label on the Apple button can be chosen.** In an app that does not make people pick
  between signing up and signing in, Google saying "Continue" next to Apple saying "Sign in"
  reads as two different things happening (reported from real use). Apple provides three
  labels — `signIn` / `continue` / `signUp` — for exactly this. The default stays `.signIn`,
  so existing call sites are unchanged.

## [5.1.0] - 2026-08-06

### Added

- **The official buttons work for apps that hold their own session.** The Apple and Google
  sign-in buttons were pinned to `authenticationStore`, so an app with its own session
  (an anonymous account being linked, say — a transition this package's store does not
  cover) could not borrow just the appearance, and hand-rolled a list row out of SF Symbols
  instead. A row with `apple.logo` in it is not accepted as a Sign in with Apple button.
  Both buttons gain an initialiser that runs a closure when pressed. Purely additive; the
  existing store-backed form works as before.

## [5.0.1] - 2026-08-02

**Ships a privacy manifest.** Consumers no longer have to declare on this package's behalf.

`FirebaseConfigurator` reads and writes the debug_mode marker and the "is this the first
launch after a reinstall" marker through `UserDefaults`. That is an API Apple requires a
reason for, and without the declaration the consumer receives an ITMS-91053 warning.

- One declaration only (`UserDefaults` / `CA92.1` = this app's own container)
- `AuthenticationFirebase` is the only target that touches `UserDefaults`, so the manifest
  goes there and nowhere else
- **Collection is not declared.** Firebase Authentication is what holds the email address and
  the display name, and it ships its own manifest. Declaring it here too would double-count it
- Nothing is added to the other five targets, none of which call a reason-requiring API.
  **Shipping an empty manifest makes "we checked and there is nothing" indistinguishable
  from "we forgot"**

Nothing to do on the consumer side beyond raising the version you depend on.

## [5.0.0] - 2026-07-20

### Fixed

- **`UserProvisioningContract` hard-coded the shape of the response body, so a backend that
  returned a different shape broke sign-in itself.**
  `Output` required `{ initialized, message }`, while `APIUserProvisioning.perform` threw the
  result away with `_ =`. A backend returning something else failed to decode, and the caller
  saw it as an authentication failure. The shape of the response body is the app's business,
  not something this package should know. `Output` is now `EmptyOutput` and the body is not read.

  The same defect was fixed on the 1.x line as 1.1.10 (2026-07-20), but came back when the
  2.0.0 redesign rebuilt `AuthInitializeContract` as `UserProvisioningContract`. Neither line
  caught it, because the existing tests **bypassed the real decode path** with a mock that
  replaced `executeWithResponse`. A regression test that goes through the real decoder has
  been added.

### ⚠️ Breaking Changes

- Removed `UserProvisioningResponse`. With the body no longer read, it has no use. Nothing in
  the workspace used it. If you need your own response type, define your own
  `APIContract & APIInput` (`Input == Self`) and hand it straight to `APIExecutable`.

### Changed

- Removed the line in `UserProvisioningContract`'s documentation saying to "pass your own
  contract to `APIUserProvisioning` if you need a different response type".
  `APIUserProvisioning.init` takes only `apiClient` and `path` — **there was no way to pass a
  contract** (the documentation promised an escape hatch the implementation did not have).
  Now that the body is not read, the escape hatch is not needed.

## [4.0.0] - 2026-07-19

### ⚠️ Breaking Changes

- Updated the swift-api-client dependency to `from: "3.0.0"`. api-client 3.0.0 renamed the
  `AuthTokenProvider` requirement from `getToken()` to `fetchToken()`, so
  **`APITokenProviderAdapter.getToken()` is renamed to `fetchToken()`**.
  Anywhere calling that type directly needs the new name (injection through the protocol is
  unaffected).

  api-client 3.0.0 made that rename in the 2026-06-27 audit, as a Swift API Design Guidelines
  violation (the `get` prefix), but no consumer moved afterwards, leaving a new major nobody
  was on. This release raises all three consumers — authentication, cached-remote-image and
  llm-cloud — to 3.x at once, ending the split generations across the family.

## [3.0.0] - 2026-07-19

### ⚠️ Breaking Changes

- Updated the swift-api-client dependency to `from: "2.3.1"` (unifying the pinned generation).
  `UserProvisioningContract` now conforms to APIInput 2.x, and `decode`'s decoder argument
  changes from `JSONDecoder` to `any APIBodyDecoder` (the Codec seam).
- `AuthTokenProviding.token()` is now `async throws`. `FirebaseTokenProvider` used to swallow
  a token fetch failure and return `nil`; that silent fallback is gone and Firebase's error
  propagates as-is (`nil` now means "not authenticated", and nothing else).
  `APITokenProviderAdapter.getToken()` passes the same error through.

### Added

- Unit tests for `AuthenticationStore.deleteAccount()` (state transition on success, cancelling
  the provisioning reservation, safety under repeated calls, and the `deleteAccountFailed`
  wrapping on failure).
- Unit tests for `APITokenProviderAdapter` (token pass-through, `nil` when not authenticated,
  error propagation).

## [2.0.0] - 2026-05-30

### ⚠️ Breaking Changes (a full redesign, no backward compatibility)

The single target that bundled Firebase, GoogleSignIn, REST and UI together is replaced by a
clean architecture that splits targets by responsibility and by vendor dependency.

- **Target split**: `Authentication` (the core, no dependencies) / `AuthenticationUI` /
  `AuthenticationApple` / `AuthenticationGoogle` / `AuthenticationFirebase` /
  `AuthenticationAPI`. The core and the UI no longer depend on a vendor SDK, so screens can be
  previewed without Firebase.
- **Three layers of responsibility**: obtaining credentials (`CredentialProvider`) / exchanging
  them for a session (`Authenticator`) / what happens after login (`PostAuthenticationAction`).
- **A vendor-independent type system**: the per-provider methods such as `signInWithGoogle()`
  are gone, replaced by a single `signIn(with: AuthCredential)`. `AuthProviderID` is extensible.
- **Renaming**: the `Impl` suffix is gone everywhere. A concrete name says what the
  implementation is (`FirebaseAuthenticator` / `APIUserProvisioning` / `AppleCredentialProvider`
  and so on). `AuthenticationUseCase(Impl)` → the `@Observable` `AuthenticationStore`.
- **The state holder**: `@MainActor @Observable final class AuthenticationStore`, injected
  through the Environment (`@Entry authenticationStore`).
- **Idempotence of the post-login work** is now handled in one place in `AuthenticationStore`
  (folding in the old v1.1.9 duplicate-call fix, and removing the double fire between the
  explicit sign-in path and the listener path).
- Fixed nonce handling for Apple Sign-In (SHA256 on the request, the raw nonce on the credential).
- `FirebaseConfigure` → `FirebaseConfigurator` (keeping the emulator, the RELEASE guard and the
  first-launch sign-out).
- Added unit tests for the core that run with no SDK at all (swift-testing).

## [1.1.9] - 2026-01-18

### Fixed
- Prevented the duplicate `initializeUser()` call in `observeAuthState()`
  - Handles Firebase Auth's `addStateDidChangeListener` firing more than once on an auth state change
  - Added a `hasInitialized` flag so the API is called only once per authentication session
  - The flag is reset on sign-out

## [1.1.8] - 2026-01-03

### Added
- A comprehensive authentication test suite (52 tests)
  - Unit tests for AuthenticationManager
  - Tests for FirebaseAuthTokenProvider
  - Better coverage through mocks and stubs

## [1.1.7] - 2026-01-03

### Changed
- Swift 6.2 support
  - `APIExecutor` → `APIExecutable`
  - `any APIClient` → `some APIExecutable`
  - Environment values defined concisely with the `@Entry` macro
- MainActor
  - Getting the view controller is wrapped in a MainActor Task, for concurrency safety
- Tidying
  - Removed redundant comments
  - Improved readability

## [1.1.6] - 2025-11-13

### Changed
- Package.swift states dependency versions explicitly as `.upToNextMajor(from:)`
  - Functionally the same as `from:`, but it makes the semantic-versioning intent explicit
  - Affects: swift-api-client (1.0.0), firebase-ios-sdk (12.5.0), GoogleSignIn-iOS (9.0.0), swift-docc-plugin (1.4.0)

## [1.1.5] - 2025-11-12

### Added
- Firebase Authentication emulator support
  - Added an `Environment` enum (`.production` / `.emulator(host:port:)`)
  - `FIREBASE_AUTH_EMULATOR_HOST` set automatically
  - Using the emulator in a RELEASE build is forbidden (a safety measure)
  - Default emulator setting: localhost:9099
- Automatic sign-out on first launch
  - Clears the automatic login that Firebase Auth's keychain persistence leaves behind when the app is reinstalled after being deleted
  - The first-launch flag is kept in UserDefaults
  - Entirely transparent; the user does not have to think about it

### Fixed
- Better emulator connection
  - Moved from setting an environment variable (setenv) to calling `Auth.auth().useEmulator()` explicitly
  - Corrected to the pattern that actually works on the iOS SDK
- Fixed the `FirebaseApp` initialisation order
  - `signOutOnFirstLaunchIfNeeded()` moved after `FirebaseApp.configure()`
  - Added a defensive check for `FirebaseApp` not being initialised

### Design notes
- Authentication only (not Firestore, not Storage)
- Data access goes through a REST API
- The environment switches automatically between DEBUG and RELEASE

## [1.1.4] - 2025-11-11

### ⚠️ Breaking Changes
- The authentication UI is rebuilt from scratch, into a customisable design
- Removed `AuthenticationView`; `GoogleSignInButton` and `AppleSignInButton` are provided instead
- Changed `AuthenticatedRootView`'s API to a ViewBuilder pattern

### Added
- `GoogleSignInButton`: a standalone button component for Google sign-in
  - Shows a loading state
  - An error handling callback
  - An accessible design
  - With a SwiftUI preview
- `AppleSignInButton`: a button component for Apple sign-in
  - iOS only (macOS shows an unsupported message)
  - Customisable styles (.black, .white, .whiteOutline)
  - A loading overlay
  - With a SwiftUI preview
- Google logo assets (1x, 2x, 3x) added as an Asset Catalog
- Comprehensive SwiftUI previews on every component

### Changed
- `AuthenticatedRootView` now takes four ViewBuilder parameters:
  - `loading`: shown while loading or initialising (used for both the auth check and initialisation)
  - `unauthenticated`: shown when not authenticated (the sign-in screen)
  - `error`: shown when something fails
  - `authenticated`: shown once authenticated (the main content)
- Both buttons share one outline style, for visual consistency
- Package.swift handles resources (Asset Catalog support)

### Removed
- `AuthenticationView`: replaced by the fully customisable design

### Design philosophy
- The package provides the authentication logic and the basic button UI, and nothing more
- The splash screen, the layout of the sign-in screen, and where the terms of use and privacy policy go are entirely the app's to decide
- The ViewBuilder pattern lets any UI be slotted in for each authentication state

## [1.1.3] - 2025-11-09

### Fixed
- Made the automatic release workflow's messages consistently Japanese (PR description, release notes, log messages)

## [1.1.2] - 2025-11-04

### Added
- DocC documentation generated automatically and published to GitHub Pages
  - Added the Swift DocC Plugin as a dependency
  - A GitHub Actions workflow generates and deploys the documentation
  - Added a link to the full documentation in the README (https://no-problem-dev.github.io/swift-authentication/documentation/authentication/)

### Changed
- The documentation is easier to reach

## [1.0.3] - 2025-02-11

### Added
- A backend API prerequisites section in the README
  - Documented the required POST `/auth/initialize` endpoint
  - Stated the required JSON response format, in camelCase
  - Explained the authentication flow between Firebase auth and the backend
  - Noted that the Authorization header is set to the Firebase ID token automatically

## [1.0.2] - 2025-02-11

### Improved
- Shortened the README down to what matters
  - Removed the troubleshooting section (Google Sign-In, token refresh, build errors)
  - Removed the architecture section (internal implementation detail)
  - Kept only what someone using the package needs

## [1.0.1] - 2025-02-11

### Improved
- A comprehensive setup guide and badges in the README
  - Badges for Swift 6.0, platforms, SPM, Firebase and the licence
  - A full prerequisites section (Firebase setup, GoogleService-Info.plist, URL schemes)
  - A quick start section with a four-step implementation guide
  - A detailed sign-in screen example
  - Examples of reading the user profile and signing out
  - A custom authentication flow example
  - An example of integrating API requests with FirebaseAuthTokenProvider
  - A troubleshooting section for common problems
  - An expanded architecture section covering the internals
  - A reference to the LICENSE file

## [1.0.0] - 2024-12-XX

### Added
- First release
- Firebase Authentication integration
- Google Sign-In support
- A modern async/await API
- SwiftUI Environment Values support
- Authentication state management
- iOS 17.0+ and macOS 14.0+ support

[Unreleased]: https://github.com/no-problem-dev/swift-authentication/compare/5.2.0...HEAD
[5.2.0]: https://github.com/no-problem-dev/swift-authentication/compare/5.1.0...5.2.0
[5.1.0]: https://github.com/no-problem-dev/swift-authentication/compare/5.0.1...5.1.0
[1.1.9]: https://github.com/no-problem-dev/swift-authentication/compare/v1.1.8...v1.1.9
[1.1.8]: https://github.com/no-problem-dev/swift-authentication/compare/v1.1.7...v1.1.8
[1.1.7]: https://github.com/no-problem-dev/swift-authentication/compare/v1.1.6...v1.1.7
[1.1.6]: https://github.com/no-problem-dev/swift-authentication/compare/v1.1.5...v1.1.6
[1.1.5]: https://github.com/no-problem-dev/swift-authentication/compare/v1.1.4...v1.1.5
[1.1.4]: https://github.com/no-problem-dev/swift-authentication/compare/v1.1.3...v1.1.4
[1.1.3]: https://github.com/no-problem-dev/swift-authentication/compare/v1.1.2...v1.1.3
[1.1.2]: https://github.com/no-problem-dev/swift-authentication/compare/v1.0.3...v1.1.2

<!-- Auto-generated on 2025-11-09T05:08:08Z by release workflow -->

<!-- Auto-generated on 2025-11-10T22:26:25Z by release workflow -->

<!-- Auto-generated on 2025-11-12T14:33:26Z by release workflow -->

<!-- Auto-generated on 2025-11-13T00:46:32Z by release workflow -->

<!-- Auto-generated on 2026-01-03T00:20:28Z by release workflow -->

<!-- Auto-generated on 2026-01-03T01:27:28Z by release workflow -->
