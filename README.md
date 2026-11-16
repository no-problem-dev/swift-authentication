English | [日本語](./README.ja.md)

# swift-authentication

Sign-in for iOS apps whose own server issues the session. Apple and Google prove who the person is; the app's server issues the user id and the tokens.

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017+%20%7C%20macOS%2014+-blue.svg)
![SPM](https://img.shields.io/badge/SwiftPM-compatible-brightgreen.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

## Design

- **The session comes from the app's server.** The app's Worker (`@studio/app-auth`) issues the user id, a 24-hour access token and a refresh token per device. Every request goes to a domain the app owns, so sign-in does not depend on reaching a third-party authentication service — Google's endpoints, for one, are unreachable from mainland China.
- **Apple and Google are ways to prove who the person is.** The device sends their identity token; the server verifies it with the provider's public keys and links it to the account, or signs in to the account it already belongs to.
- **Firebase is not part of this package.** Apps moving off Firebase Authentication use [swift-authentication-firebase](https://github.com/no-problem-dev/swift-authentication-firebase) for the move only: it hands the session an earlier version left on the device to the server, which keeps the person's user id.

| Responsibility | Protocol (core) | Concrete (separate target) |
|---|---|---|
| Credential acquisition | `CredentialProvider` | `AppleCredentialProvider` / `GoogleCredentialProvider` |
| Session exchange | `Authenticator` | `SessionAuthenticator` |
| Bearer tokens | `AuthTokenProviding` | `SessionTokenProvider` |

**`AuthenticationStore`** (`@Observable`, `@MainActor`) wires these together and exposes a `state` property that views observe. What the app does once someone is signed in is the app's business.

### Target Layout

| Target | Role | External dependencies |
|---|---|---|
| **`Authentication`** | Core abstractions (protocols, value types, `AuthenticationStore`) | **None** |
| **`AuthenticationSession`** | Sessions from the app's server: sign-in, linking, refresh, keychain storage, the legacy exchange | Foundation / Security (system) |
| **`AuthenticationUI`** | SwiftUI views + Environment DI | SwiftUI (system) |
| **`AuthenticationApple`** | Apple credential acquisition | AuthenticationServices / CryptoKit (system) |
| **`AuthenticationGoogle`** | Google credential acquisition | GoogleSignIn |

Only `AuthenticationGoogle` depends on an SDK. Views depend on `Authentication` and `AuthenticationUI` alone, so SwiftUI previews load nothing else.

## Usage

### 1. Compose `AuthenticationStore` at the composition root

```swift
import SwiftUI
import Authentication
import AuthenticationUI
import AuthenticationSession
import AuthenticationApple

@main
struct MyApp: App {
    @State private var store: AuthenticationStore
    private let authenticator: SessionAuthenticator

    init() {
        authenticator = SessionAuthenticator(
            baseURL: URL(string: "https://api.example.com")!,   // A domain you own, not workers.dev.
            installID: { InstallID.current }                    // A UUID the app keeps in UserDefaults.
        )
        _store = State(initialValue: AuthenticationStore(
            authenticator: authenticator,
            credentialProviders: [AppleCredentialProvider()]
        ))
    }

    var body: some Scene {
        WindowGroup {
            AuthenticatedRootView(
                loading: { ProgressView() },
                unauthenticated: { ProgressView().task { try? await authenticator.establishSession() } },
                error: { error in Text(error.localizedDescription) },
                authenticated: { user in MainView(userID: user.id) }
            )
            .authenticationStore(store)
        }
    }
}
```

Your API client takes its bearer token from `authenticator.tokenProvider`:

```swift
let token = try await authenticator.tokenProvider.requiredToken()
// After a 401, once:
let renewed = try await authenticator.tokenProvider.requiredToken(forceRefresh: true)
```

### 2. Screen views (previewable, vendor-free)

```swift
import SwiftUI
import Authentication
import AuthenticationUI

struct MainView: View {
    @Environment(\.authenticationStore) private var store
    let userID: String

    var body: some View {
        VStack {
            Text("Welcome, \(userID)")
            Button("Sign Out") { Task { try? await store?.signOut() } }
        }
    }
}

#Preview {
    MainView(userID: "preview")
        .authenticationStore(.previewUnauthenticated)
}
```

### State

`AuthenticationState` transitions:

- `.checking` — reading the stored session on launch
- `.unauthenticated` — no session
- `.authenticated(AuthUser)` — signed in
- `.error(any Error)` — an exchange failed

### Starting a session at launch

`establishSession()` decides what the device signs in as:

1. A stored session is used as it is, refreshed first when its access token has less than five minutes left. When the refresh cannot reach the server, the stored session is still used.
2. With none stored, a `LegacySessionSource` that still holds a session from an earlier version of the app has it exchanged at `/v1/auth/firebase` — `{ idToken }` or `{ refreshToken }`, whichever it holds. The person keeps their user id. **When the exchange fails in a way that may pass — no network, a 503 — no session is opened** (that would strand their records) and the call throws; call it again later. When the server says it can never succeed — 410 `account_deleted`, or 401 `legacy_credential_rejected` because Google refused the refresh token for good — the legacy session is discarded and step 3 follows.
3. Otherwise a new anonymous session is opened at `/v1/auth/anonymous`. With `SessionAuthenticator(…, anonymous: .disabled)` — an app where signing in is optional — none is opened: the call throws `AuthError.notAuthenticated` and the device stays signed out until the person signs in with Apple or Google.

`store.signIn(with: .anonymous)` goes through the same steps. Concurrent calls share one attempt.

### Tokens

`SessionTokenProvider` refreshes at `/v1/auth/refresh` before a token has less than five minutes left, joins refreshes that arrive at the same time into one, and always refreshes for `forceRefresh: true`. When the server rejects the refresh token, the session is removed from the device, `authStateChanges()` emits `nil`, and the call throws `AuthError.notAuthenticated`. A refresh that was only due early and cannot reach the server falls back to the token that still works. Requests time out after 20 seconds by default (`requestTimeout:`).

### Upgrading an anonymous account

`signIn` replaces the session, so an anonymous user who signs in with Apple gets a new user id and leaves the anonymous account's data behind. `link` attaches the credential to the account in hand and keeps the id:

```swift
do {
    try await store.link(using: .apple)
} catch AuthError.credentialAlreadyInUse(let collision) {
    // The person already has an account with this provider (typically from another device).
    // Switching to it changes the user id; ask before doing so.
    try await store.signIn(resolving: collision)
}
```

The collision carries the credential that collided. The server verifies the token by its signature, so `signIn(resolving:)` signs in to the owning account with the same token without showing Apple's sheet again. When the token has expired in the meantime, the store runs the provider's sheet for a fresh one. Switching to another user revokes the previous session's device on the server.

`unlink(_:)` removes a provider again (`DELETE /v1/auth/identities/:provider`) and keeps the user id.

### Signing in to an existing account

For a "sign in to my existing account" screen, `signInExisting` sends `mode: "sign_in_existing"`: it signs in to the account the credential belongs to, and when there is none it creates nothing, links nothing and leaves the session alone.

```swift
let found = try await store.signInExisting(using: .apple)
if !found { /* No account uses this Apple ID yet. */ }
```

To ask the person before the switch — and only when there is an account to switch to — use
`SessionAuthenticator.findExisting(with:)`. The device keeps its session until you commit:

```swift
guard let pending = try await authenticator.findExisting(with: credential) else { return /* not found */ }
if await confirmReplace(pending.user) {
    try await pending.commit()
} else {
    await pending.cancel()   // revokes the session the server issued for the switch
}
```

### Deleted accounts

The server answers 410 `account_deleted` for a deleted account; it arrives as `AuthError.accountDeleted`. A legacy session that belonged to a deleted account is forgotten and a new anonymous session opened in its place.

### Signing out

`signOut()` clears the keychain first and then asks the server to revoke the device at `/v1/auth/sign-out`, best effort — it works offline. A legacy session is forgotten too, so starting again opens a new anonymous user instead of exchanging the old one back.

### Deleting the account

`store.deleteAccount()` sends `DELETE /v1/account` (change it with `accountDeletionPath:`) with the bearer token, then clears the session once the server succeeded. For an account linked to Apple, it first runs Apple's sheet for a fresh authorization code and sends it as `{ "appleAuthorizationCode": … }`, so the server can revoke the person's Apple tokens as App Review guideline 5.1.1(v) requires. The code is single use and lasts about five minutes, which is why it is obtained at deletion time. Backing out of the sheet deletes nothing and throws `AuthError.cancelled`.

### Sharing the session with an extension

`KeychainSessionStore` keeps the session with `kSecAttrAccessibleAfterFirstUnlock`. Pass an access group to share it with a widget:

```swift
SessionAuthenticator(
    baseURL: apiURL,
    installID: { InstallID.current },
    store: KeychainSessionStore(accessGroup: "TEAMID.com.example.shared")
)
```

Keychain items survive deleting the app, so a reinstall on the same device comes back as the same user. An item that is not a session is reported as `KeychainSessionStore.UndecodableItem`, not removed behind the caller's back; `signOut()` removes it. Tests and previews use `InMemorySessionStore`.

While the device's protected data is unavailable — a prewarmed or background launch before the first unlock, or while locked — the keychain cannot be read and can even answer "not found" for an item that is there. `KeychainSessionStore` checks `ProtectedDataAvailability` (by default `KeychainProtectedDataProbe`, which needs no UIKit) before it reports no session, and `establishSession()` throws `ProtectedDataUnavailable` instead of opening a new account. Call it again after `UIApplication.protectedDataDidBecomeAvailableNotification`:

```swift
do {
    try await authenticator.establishSession()
} catch is ProtectedDataUnavailable {
    // Not signed out: the keychain is locked. Try again once it is not.
}
```

Until then `authStateChanges()` reports nobody, so `AuthenticationStore.state` is `.unauthenticated`; the call that finds the stored session after unlock emits its user, and the state follows. `ProtectedDataUnavailable` is never wrapped in another error — the store's `signIn`, `link`, `signOut` and `deleteAccount` throw it as it is and leave `state` alone.

### Moving off Firebase Authentication

Add [swift-authentication-firebase](https://github.com/no-problem-dev/swift-authentication-firebase) and pass its `FirebaseKeychainLegacySessionSource`. It reads the refresh token Firebase Authentication left in the keychain — without the Firebase SDK — and the server trades it at Google:

```swift
import AuthenticationFirebase

SessionAuthenticator(
    baseURL: apiURL,
    installID: { InstallID.current },
    legacySource: FirebaseKeychainLegacySessionSource(googleAppID: "1:1234567890:ios:abcdef")
)
```

The exchange happens once, the server keeps the Firebase uid as the user id, and the keychain item is removed afterwards. Apps that never used Firebase leave the package out.

### Custom providers

`AuthProviderID` is open-ended. Implement `CredentialProvider` or `Authenticator` to plug in anything else.

## Documentation

API reference for every module: the DocC catalog in each module under [`Sources/`](Sources).

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-authentication.git", from: "12.1.1")
]
```

Add only the products your target needs:

- Screen modules → `AuthenticationUI` (+ `Authentication`)
- Composition root (App target) → `AuthenticationSession` / `AuthenticationApple` / `AuthenticationGoogle`

Moving from 10.x: see [CHANGELOG.md](CHANGELOG.md).

## Requirements

| Swift | Platforms |
|---|---|
| 6.2 | iOS 17+ · macOS 14+ |

## License

MIT License. See [LICENSE](LICENSE) for details.
