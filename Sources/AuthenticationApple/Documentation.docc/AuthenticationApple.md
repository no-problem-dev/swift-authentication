# ``AuthenticationApple``

Sign in with Apple, as a `CredentialProvider` the rest of the package can use.

## Overview

`AuthenticationApple` presents `ASAuthorizationController` and turns what comes back into a
vendor-agnostic `AuthCredential`. It owns the nonce handling that makes the result verifiable:
the request carries the SHA-256 hash, the credential carries the raw value, and the server
matches the two to rule out a replayed identity token.

Create a provider and hand it to the store's `credentialProviders`; the credential it produces
goes on to whatever implements the `Authenticator` protocol, normally `SessionAuthenticator`.

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

### Revoking tokens on account deletion

An app that offers Sign in with Apple must revoke the user's Apple tokens when the account is
deleted (App Review guideline 5.1.1(v)). That takes the authorization code Apple returns with
each authorization, which the credential carries as `authorizationCode`. The code is single use
and expires after about five minutes, so it has to come from a fresh authorization right before
deleting. `AuthenticationStore.deleteAccount()` does that when the account is linked to Apple
and an `AppleCredentialProvider` is registered, and passes the code on to the server:

```swift
try await store.deleteAccount()   // Shows Apple's sheet first for an Apple-linked account.
```

## Topics

### Credential provider

- ``AppleCredentialProvider``

### Factory

- ``Authentication/AuthCredential/apple(idToken:rawNonce:fullName:)``
- ``Authentication/AuthCredential/apple(idToken:rawNonce:fullName:authorizationCode:)``
