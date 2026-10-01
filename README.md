English | [日本語](./README.ja.md)

# swift-authentication

A modular authentication package that wires Firebase / Apple / Google / REST concretions into a vendor-agnostic core — one target at a time.

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017+%20%7C%20macOS%2014+-blue.svg)
![SPM](https://img.shields.io/badge/SwiftPM-compatible-brightgreen.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

## Design

Authentication is split into three responsibilities, each defined as a vendor-agnostic protocol. Concrete implementations live in separate targets and are composed at the app's composition root.

| Responsibility | Protocol (core) | Concrete (separate target) |
|---|---|---|
| Credential acquisition | `CredentialProvider` | `AppleCredentialProvider` / `GoogleCredentialProvider` |
| Session exchange | `Authenticator` | `FirebaseAuthenticator` |
| Post-auth action (idempotent) | `PostAuthenticationAction` | `APIUserProvisioning` (REST) |

**`AuthenticationStore`** (`@Observable`, `@MainActor`) wires these together and exposes a `state` property that views observe.

### Target Layout

| Target | Role | External dependencies |
|---|---|---|
| **`Authentication`** | Core abstractions (protocols, value types, `AuthenticationStore`) | **None** |
| **`AuthenticationUI`** | SwiftUI views + Environment DI | SwiftUI (system) |
| **`AuthenticationApple`** | Apple credential acquisition | AuthenticationServices / CryptoKit (system) |
| **`AuthenticationGoogle`** | Google credential acquisition | GoogleSignIn |
| **`AuthenticationFirebase`** | Firebase session exchange and configuration | FirebaseAuth |
| **`AuthenticationAPI`** | REST post-authentication action | swift-api-client |

**The core (`Authentication`) and UI (`AuthenticationUI`) targets have zero vendor SDK dependencies.**
Views can depend on only these two, keeping SwiftUI Previews free of Firebase / GoogleSignIn.
Concrete implementations (Firebase, etc.) are imported only at the composition root.

## Usage

### 1. Compose `AuthenticationStore` at the composition root

```swift
import SwiftUI
import Authentication
import AuthenticationUI
import AuthenticationFirebase
import AuthenticationApple
import AuthenticationGoogle
import AuthenticationAPI
import APIClient

@main
struct MyApp: App {
    @State private var store: AuthenticationStore

    init() {
        FirebaseConfigurator.configure()   // Production. Use .configure(environment: .emulator()) for local dev.

        let apiClient = APIClientImpl(
            baseURL: URL(string: "https://api.example.com")!,
            authTokenProvider: APITokenProviderAdapter(FirebaseTokenProvider())
        )

        _store = State(initialValue: AuthenticationStore(
            authenticator: FirebaseAuthenticator(
                accountDeletion: APIAccountDeletion(apiClient: apiClient, path: "/v1/me")
            ),
            postAuthentication: APIUserProvisioning(apiClient: apiClient),
            credentialProviders: [
                AppleCredentialProvider(),
                GoogleCredentialProvider(clientID: FirebaseConfigurator.googleClientID ?? "")
            ]
        ))
    }

    var body: some Scene {
        WindowGroup {
            AuthenticatedRootView(
                loading: { ProgressView() },
                unauthenticated: {
                    VStack(spacing: 16) {
                        GoogleSignInButton()
                        AppleSignInButton()
                    }
                    .padding(.horizontal, 32)
                },
                error: { error in Text(error.localizedDescription) },
                authenticated: { user in MainView(userID: user.id) }
            )
            .authenticationStore(store)
        }
    }
}
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
    // No Firebase needed — uses a stub.
    MainView(userID: "preview")
        .authenticationStore(.previewUnauthenticated)
}
```

### State

`AuthenticationState` transitions:

- `.checking` — verifying stored session on launch
- `.unauthenticated` — no active session
- `.authenticatedPendingProvisioning` — session exchanged, post-auth action pending
- `.authenticated(AuthUser)` — fully authenticated
- `.error(any Error)` — an error occurred

Only `.authenticated` means the account is ready: while provisioning is pending the session exists but the app should still show a loading state.

### Post-authentication provisioning (optional)

`APIUserProvisioning` calls `POST <path>` (default `/auth/initialize`) once the session exists, with the Firebase ID token attached as `Authorization: Bearer`. The store calls it **once per authentication session**, but retries and reinstalls mean the endpoint has to be idempotent on the server too. Omit `postAuthentication` when there is nothing to provision.

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

Never exchange the credential that collided a second time: the nonce inside an Apple identity token is spent by the link, and Firebase answers "Duplicate credential received". `signIn(resolving:)` uses the replacement credential Firebase returned with the error and, when there is none, runs the provider's sheet again for a fresh one. Code that talks to Firebase directly can convert this package's credentials with `FirebaseCredentialMapper.makeCredential(from:)` rather than keeping its own copy.

### Deleting the account through your server

Deleting the Firebase account from the device is refused when the last sign-in is too old (`requiresRecentLogin`), and when the app first deletes its server data that refusal arrives after the data is gone. Give `FirebaseAuthenticator` an `AccountDeletion` — `APIAccountDeletion` sends `DELETE <path>` through swift-api-client — and `deleteAccount()` calls the server, then clears the local session only once the server succeeded. Without one, the account is deleted from the device as before. Either way, `deleteAccount()` now ends the local session itself.

### Forcing a token refresh

`AuthTokenProviding.token(forceRefresh:)` fetches a new token even when the cached one has not expired — what to do after a 401. A transport that takes a token closure gets one from `tokenSource`:

```swift
let token: @Sendable (_ forceRefresh: Bool) async throws -> String = FirebaseTokenProvider().tokenSource
```

### Deleting an account that used Sign in with Apple

App Review guideline 5.1.1(v) requires revoking the user's Apple tokens on account deletion. The credential from `AppleCredentialProvider` carries Apple's `authorizationCode`; it is single use and expires in about five minutes, so authorize again right before deleting, revoke, then delete:

```swift
let fresh = try await AppleCredentialProvider().acquireCredential()
if let code = fresh.authorizationCode {
    try await firebaseAuthenticator.revokeAppleToken(authorizationCode: code)
}
try await firebaseAuthenticator.deleteAccount()
```

### Custom providers

`AuthProviderID` is open-ended. Implement `CredentialProvider` / `Authenticator` / `PostAuthenticationAction` to plug in any backend — direct Firestore access, custom OIDC, anything else.

## Documentation

API reference for every module: [no-problem-dev.github.io/swift-authentication](https://no-problem-dev.github.io/swift-authentication/documentation/).

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-authentication.git", from: "10.0.0")
]
```

Add only the products your target needs:

- Screen modules → `AuthenticationUI` (+ `Authentication`)
- Composition root (App target) → `AuthenticationFirebase` / `AuthenticationApple` / `AuthenticationGoogle` / `AuthenticationAPI`

## Requirements

| Swift | Platforms |
|---|---|
| 6.2 | iOS 17+ · macOS 14+ |

## License

MIT License. See [LICENSE](LICENSE) for details.
