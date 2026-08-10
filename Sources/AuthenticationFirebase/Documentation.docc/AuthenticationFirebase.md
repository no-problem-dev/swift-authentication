# ``AuthenticationFirebase``

Session exchange, identity tokens and start-up, backed by Firebase Authentication.

## Overview

`AuthenticationFirebase` implements the `Authenticator` protocol on top of Firebase: it
converts a vendor-agnostic `AuthCredential` into Firebase's own credential
type and trades it for a session. It also supplies identity tokens through
`AuthTokenProviding` and configures Firebase at launch.

Only Firebase Authentication is pulled in — no Firestore, no Storage — so application data
stays behind your own API.

Call ``FirebaseConfigurator/configure(environment:enableDebugMode:)`` once at launch. During
development, `.emulator` points the app at the Firebase Local Emulator Suite; release builds
refuse it outright, because authenticating real users against an emulator would mean trusting
anyone who can reach it.

```swift
import AuthenticationFirebase

// Once, from the app's initializer or the app delegate.
FirebaseConfigurator.configure(environment: .production)

// During development, debug builds only.
// FirebaseConfigurator.configure(environment: .emulator(host: "localhost", port: 9099))
```

Configuring also signs out on the first launch after an install. Firebase keeps sessions in
the keychain, which survives deleting the app, so without that step a reinstall would silently
restore whoever was signed in before.

``FirebaseAuthenticator`` and ``FirebaseTokenProvider`` are injected into
`AuthenticationStore` at the composition root.

```swift
import Authentication
import AuthenticationFirebase

let authenticator = FirebaseAuthenticator()       // Uses the shared Auth instance.
let tokenProvider = FirebaseTokenProvider()

let store = AuthenticationStore(authenticator: authenticator)
```

``FirebaseConfigurator/googleClientID`` reads the client ID out of `GoogleService-Info.plist`,
so the composition root can hand it to `GoogleCredentialProvider` without importing
FirebaseCore itself.

## Topics

### Start-up

- ``FirebaseConfigurator``
- ``FirebaseConfigurator/Environment``

### Session exchange

- ``FirebaseAuthenticator``

### Tokens

- ``FirebaseTokenProvider``
