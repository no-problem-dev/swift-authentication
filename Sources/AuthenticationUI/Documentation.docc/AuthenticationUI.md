# ``AuthenticationUI``

SwiftUI components that follow the session: a root view that branches on it, and the two
sign-in buttons.

## Overview

`AuthenticationUI` reads the `AuthenticationStore` out of the SwiftUI environment and builds UI
from it declaratively. It depends on no third-party SDK — only SwiftUI and
AuthenticationServices — so screens built on it still render in previews.

``AuthenticatedRootView`` takes one builder per stage of the session. Checking and pending
provisioning share the loading branch, which is why there are four rather than five.

```swift
struct RootView: View {
    var body: some View {
        AuthenticatedRootView(
            loading: { SplashScreen() },
            unauthenticated: { SignInScreen() },
            error: { ErrorScreen(error: $0) },
            authenticated: { HomeScreen(user: $0) }
        )
    }
}
```

The store is injected once, at the composition root. Without it the root view renders a
configuration error rather than an empty screen, so a missed injection is visible immediately.

```swift
RootView()
    .authenticationStore(myStore)
```

``AppleSignInButton`` and ``GoogleSignInButton`` read the same store and call `signIn(using:)`
on tap. Failures arrive in `onError`; a cancelled sheet does not, because dismissing the
provider's UI is an ordinary outcome rather than an error worth showing.

```swift
AppleSignInButton(type: .continue, onError: { presentedError = $0 })
```

Both buttons also have a form that runs a closure instead of touching the store — for apps that
own their own session, such as linking an anonymous account, and still want the treatment Apple
and Google require.

```swift
GoogleSignInButton(title: "Continue with Google") {
    await session.linkGoogleAccount()
}
```

Match the Apple button's wording to whatever stands beside it: `.signIn`, `.continue` and
`.signUp` exist so a row of buttons reads as one choice rather than several.

## Topics

### Root view

- ``AuthenticatedRootView``

### Sign-in buttons

- ``AppleSignInButton``
- ``GoogleSignInButton``
- ``GoogleSignInButtonStyle``
