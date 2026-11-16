# ``AuthenticationSession``

Sign-in with sessions the app's own server issues, kept in the keychain and refreshed before
they expire.

## Overview

The app's Worker (`@studio/app-auth`) issues the user id, an access token that lives 24 hours,
and a refresh token for the device. Apple and Google only prove who the person is: the device
sends their token, and the server verifies it with the provider's public keys. Every request
goes to a domain the app owns, so nothing depends on reaching a third-party authentication
service.

``SessionAuthenticator`` is the `Authenticator`; its ``SessionAuthenticator/tokenProvider`` is
the `AuthTokenProviding` an API client takes its bearer token from. Both share one session.

```swift
import Authentication
import AuthenticationSession
import AuthenticationApple

let authenticator = SessionAuthenticator(
    baseURL: URL(string: "https://api.example.com")!,
    installID: { InstallID.current }
)
let store = AuthenticationStore(
    authenticator: authenticator,
    credentialProviders: [AppleCredentialProvider()]
)

// At launch: the stored session, else a new anonymous one.
try await authenticator.establishSession()

// In the API client.
let token = try await authenticator.tokenProvider.requiredToken()
```

### At launch

``SessionAuthenticator/establishSession()`` uses the stored session, refreshing it when its
access token has less than five minutes left. With none stored it opens an anonymous session —
unless a `LegacySessionSource` still holds a session from an earlier version of the app, which
is exchanged instead so the person keeps their user id. A failed exchange throws and opens
nothing; call it again once the network is back.

### Tokens

``SessionTokenProvider`` refreshes ahead of expiry, joins concurrent refreshes into one, and
refreshes unconditionally for `forceRefresh: true` — what to do once after a 401. When the server
rejects the refresh token, the session is removed and the authenticator's stream emits `nil`.

### Endpoints

| Call | Request |
|---|---|
| Anonymous | `POST /v1/auth/anonymous` `{ installId }` |
| Refresh | `POST /v1/auth/refresh` `{ refreshToken }` |
| Apple | `POST /v1/auth/apple` `{ identityToken, installId, mode }`, with a bearer to link |
| Google | `POST /v1/auth/google` `{ idToken, installId, mode }`, with a bearer to link |
| Unlink | `DELETE /v1/auth/identities/:provider`, bearer |
| Legacy exchange | `POST /v1/auth/firebase` `{ idToken, installId }` |
| Sign-out | `POST /v1/auth/sign-out`, bearer |
| Deletion | `DELETE /v1/account` (`accountDeletionPath:`) `{ appleAuthorizationCode? }`, bearer |

`mode` is `link_or_sign_in`, except for ``SessionAuthenticator/signInExisting(with:)`` and
``SessionAuthenticator/signIn(resolving:)``, which send `sign_in_existing`: the server signs in
to the account the token belongs to and creates nothing when there is none (404, returned as
`nil`). A 409 while linking becomes `AuthError.credentialAlreadyInUse`; a 410 becomes
`AuthError.accountDeleted`. Switching to another user revokes the previous session's device.

## Topics

### Signing in

- ``SessionAuthenticator``
- ``SessionTokenProvider``

### The session

- ``AuthSession``
- ``SessionStore``
- ``KeychainSessionStore``
- ``InMemorySessionStore``

### Errors

- ``SessionServerError``
- ``SessionCredentialError``
