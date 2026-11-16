# ``Authentication``

The vendor-agnostic core: the protocols, the value types, and the store that holds the session.

## Overview

`Authentication` splits signing in into two steps — **acquire a credential, then exchange it
for a session** — and describes each one as a protocol that mentions no SDK. Nearly all of an
app's code depends on this module alone; the concrete implementations are injected at the
composition root. What the app does once someone is signed in is the app's own business.

``AuthenticationStore`` is the piece that holds everything together. It publishes an
observable ``AuthenticationState`` that SwiftUI views switch on.

```swift
import Authentication

// Assembled at the composition root; the concretions come from the other modules.
let store = AuthenticationStore(
    authenticator: myAuthenticator,           // e.g. SessionAuthenticator
    credentialProviders: [myAppleProvider, myGoogleProvider]
)

// Sign in by provider identifier.
try await store.signIn(using: .apple)

// Upgrade an anonymous account, keeping its user id.
do {
    try await store.link(using: .apple)
} catch AuthError.credentialAlreadyInUse(let collision) {
    // Another account owns the credential. Switching to it changes the user id.
    try await store.signIn(resolving: collision)
}

// Sign out, or delete the account (an Apple-linked one shows Apple's sheet first).
try await store.signOut()
```

``AuthenticationState`` moves from `.checking` to `.unauthenticated` or
`.authenticated(AuthUser)`, and to `.error(any Error)` when an exchange fails.

### Module layout

An app combines the concretions it needs at the composition root and keeps its domain layer
depending on `Authentication` only.

- **Authentication** (this module): the protocols, the value types and ``AuthenticationStore``.
- **AuthenticationSession**: `SessionAuthenticator` and `SessionTokenProvider`, over sessions
  the app's own server issues. The default.
- **AuthenticationUI**: SwiftUI components — `AuthenticatedRootView`, `AppleSignInButton`,
  `GoogleSignInButton`.
- **AuthenticationApple**: `AppleCredentialProvider`, which runs Sign in with Apple.
- **AuthenticationGoogle**: `GoogleCredentialProvider` and the `GoogleURLHandler` that
  completes the browser round trip.

Firebase lives in a separate package, swift-authentication-firebase, for apps moving off it.

## Topics

### The store

- ``AuthenticationStore``

### Protocols

- ``Authenticator``
- ``CredentialProvider``
- ``AuthTokenProviding``
- ``AccountDeletion``
- ``LegacySessionSource``

### State and the user

- ``AuthenticationState``
- ``AuthUser``

### Credentials and provider identifiers

- ``AuthCredential``
- ``AuthProviderID``
- ``PersonName``

### Errors

- ``AuthError``
- ``CredentialCollision``
