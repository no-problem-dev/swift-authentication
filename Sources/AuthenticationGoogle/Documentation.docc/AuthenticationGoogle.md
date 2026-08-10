# ``AuthenticationGoogle``

Google Sign-In, as a `CredentialProvider`, plus the redirect handling it needs.

## Overview

`AuthenticationGoogle` drives the GoogleSignIn SDK, collects the identity and access tokens,
and returns them as a vendor-agnostic `AuthCredential`.

The client ID is injected rather than read from Firebase, which is what keeps this module clear
of FirebaseCore. Apps that already use Firebase can take it from
`FirebaseConfigurator.googleClientID`; otherwise it comes from the app's `Info.plist`.

```swift
import AuthenticationGoogle

let google = GoogleCredentialProvider(clientID: myGoogleClientID)
```

Google Sign-In finishes through a redirect back into the app, so the URL has to be forwarded.
Without this the browser round trip never completes and sign-in appears to hang with no error.

```swift
.onOpenURL { incoming in
    GoogleURLHandler.handle(incoming)
}
```

``GoogleURLHandler/handle(_:)`` reports whether Google consumed the URL, so an app that also
handles deep links can fall through to its own routing when it did not.

## Topics

### Credential provider

- ``GoogleCredentialProvider``

### Redirect handling

- ``GoogleURLHandler``
