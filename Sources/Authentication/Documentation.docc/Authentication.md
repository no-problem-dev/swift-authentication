# ``Authentication``

The vendor-agnostic core: the protocols, the value types, and the store that holds the session.

## Overview

`Authentication` splits signing in into three steps — **acquire, exchange, then finish
setting the user up** — and describes each one as a protocol that mentions no SDK. Nearly all
of an app's code depends on this module alone; the concrete implementations are injected at
the composition root.

``AuthenticationStore`` is the piece that holds everything together. It publishes an
observable ``AuthenticationState`` that SwiftUI views switch on.

```swift
import Authentication

// Assembled at the composition root; the concretions come from the other modules.
let store = AuthenticationStore(
    authenticator: myAuthenticator,           // e.g. AuthenticationFirebase
    postAuthentication: myPostAction,         // e.g. AuthenticationAPI
    credentialProviders: [myAppleProvider, myGoogleProvider]
)

// Sign in by provider identifier.
try await store.signIn(using: .apple)

// Sign out.
try await store.signOut()
```

``AuthenticationState`` moves from `.checking` to `.unauthenticated` to
`.authenticatedPendingProvisioning` to `.authenticated(AuthUser)`, and to
`.error(any Error)` when something along the way fails. Only the last of those means the
account is ready to use: while provisioning is pending the session exists but the app should
still be showing a loading state.

### Module layout

The package is six modules. An app combines the concretions it needs at the composition root
and keeps its domain layer depending on `Authentication` only.

- **Authentication** (this module): the protocols, the value types and ``AuthenticationStore``.
- **AuthenticationUI**: SwiftUI components — `AuthenticatedRootView`, `AppleSignInButton`,
  `GoogleSignInButton`.
- **AuthenticationApple**: `AppleCredentialProvider`, which runs Sign in with Apple.
- **AuthenticationGoogle**: `GoogleCredentialProvider` and the `GoogleURLHandler` that
  completes the browser round trip.
- **AuthenticationFirebase**: `FirebaseAuthenticator` for the exchange, `FirebaseTokenProvider`
  for bearer tokens, and `FirebaseConfigurator` for start-up.
- **AuthenticationAPI**: `APIUserProvisioning` for post-sign-in work over REST, and
  `APITokenProviderAdapter` for wiring tokens into swift-api-client.

## Topics

### The store

- ``AuthenticationStore``

### Protocols

- ``Authenticator``
- ``CredentialProvider``
- ``PostAuthenticationAction``
- ``AuthTokenProviding``

### State and the user

- ``AuthenticationState``
- ``AuthUser``

### Credentials and provider identifiers

- ``AuthCredential``
- ``AuthProviderID``
- ``PersonName``

### Post-authentication work

- ``NoPostAuthentication``
- ``CompositePostAuthentication``

### Errors

- ``AuthError``
