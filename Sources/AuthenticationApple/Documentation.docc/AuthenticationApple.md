# ``AuthenticationApple``

Sign in with Apple, as a `CredentialProvider` the rest of the package can use.

## Overview

`AuthenticationApple` presents `ASAuthorizationController` and turns what comes back into a
vendor-agnostic `AuthCredential`. It owns the nonce handling that makes the result verifiable:
the request carries the SHA-256 hash, the credential carries the raw value, and the server
matches the two to rule out a replayed identity token.

Create a provider and hand it to the store's `credentialProviders`; the credential it produces
goes on to whatever implements the `Authenticator` protocol, normally `FirebaseAuthenticator`.

```swift
import AuthenticationApple

// Asks for the full name and the email address.
let apple = AppleCredentialProvider()

// Ask for less when the app has no use for the rest.
let emailOnly = AppleCredentialProvider(requestedScopes: [.email])
```

Apple returns the user's name only on the very first authorization for an account. An app that
wants it has to persist it during that sign-in — asking again later yields nothing.

To assemble a credential by hand, when linking accounts for instance, use the factory this
module adds:

```swift
let credential = AuthCredential.apple(
    idToken: identityToken,
    rawNonce: nonce,          // The value before hashing, not what went on the request.
    fullName: name
)
```

## Topics

### Credential provider

- ``AppleCredentialProvider``

### Factory

- ``Authentication/AuthCredential/apple(idToken:rawNonce:fullName:)``
