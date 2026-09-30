# ``AuthenticationAPI``

Post-sign-in provisioning over REST, and the adapter that gives an API client its bearer token.

## Overview

`AuthenticationAPI` is the seam between this package and swift-api-client. It does three things.

**1. Provisioning the user after sign-in**

``APIUserProvisioning`` conforms to `PostAuthenticationAction` and posts to
the backend's initialization endpoint — `/auth/initialize` unless you say otherwise — as soon
as a session exists. `AuthenticationStore` calls it once per user per
session, but retries and reinstalls mean the endpoint itself has to be idempotent.

```swift
import Authentication
import AuthenticationAPI
import AuthenticationFirebase

// At the composition root.
// myAPIClient is any swift-api-client APIExecutable.
let store = AuthenticationStore(
    authenticator: FirebaseAuthenticator(),
    postAuthentication: APIUserProvisioning(
        apiClient: myAPIClient,
        path: "/auth/initialize"      // Point it anywhere your backend expects.
    )
)
```

**2. Supplying the token**

``APITokenProviderAdapter`` bridges `AuthTokenProviding` to the
`AuthTokenProvider` protocol swift-api-client expects. That is what lets a
`FirebaseTokenProvider` reach an API client while `AuthenticationFirebase` stays free of any
swift-api-client dependency — and the other way round.

```swift
import AuthenticationAPI
import AuthenticationFirebase

let tokenProvider = FirebaseTokenProvider()
let adapter = APITokenProviderAdapter(tokenProvider)
// Hand the adapter to the API client's initializer.
```

**3. Deleting the account on the server**

``APIAccountDeletion`` conforms to `AccountDeletion` and sends `DELETE <path>`. Hand it to
`FirebaseAuthenticator(accountDeletion:)`; the server then deletes the data and the
authentication account in one request, and the device clears its session only after that
succeeded.

```swift
let authenticator = FirebaseAuthenticator(
    accountDeletion: APIAccountDeletion(apiClient: myAPIClient, path: "/v1/me")
)
```

## Topics

### Provisioning

- ``APIUserProvisioning``
- ``UserProvisioningContract``

### Account deletion

- ``APIAccountDeletion``
- ``AccountDeletionContract``

### Token adapter

- ``APITokenProviderAdapter``
