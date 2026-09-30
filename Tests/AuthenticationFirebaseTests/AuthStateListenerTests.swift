import Testing
import Foundation
import FirebaseCore
import FirebaseAuth
import Authentication
@testable import AuthenticationFirebase

/// Covers what `FirebaseAuthenticator` does with the `Auth` instance it was handed.
///
/// `init(auth:)` exists so an app can point the authenticator at a Firebase app of its own, and
/// every method has to stay on that instance. Reaching for the shared one instead is not a
/// degraded outcome: `Auth.auth()` traps when no default app has been configured, so the app dies
/// the moment the stream is released.
///
/// - Note: A regression here aborts the test run rather than reporting a failure, because the
///   wrong behaviour is a trap and not a wrong value. Reaching the end of the test is the
///   assertion.
@Suite("Auth state listener", .serialized)
struct AuthStateListenerTests {

    @Test("observing sign-in state uses the injected instance, not the shared one")
    func listenerStaysOnTheInjectedInstance() {
        let auth = Auth.auth(app: TestFirebaseApp.secondary)

        #expect(FirebaseApp.app() == nil, "the default app must stay unconfigured for this to mean anything")

        var iterator: AsyncStream<AuthUser?>.AsyncIterator?
        do {
            let authenticator = FirebaseAuthenticator(auth: auth)
            iterator = authenticator.authStateChanges().makeAsyncIterator()
        }

        // Dropping the last reference terminates the stream, which is where the listener is
        // removed. Doing that against the shared instance traps here.
        iterator = nil
        _ = iterator

        #expect(FirebaseApp.app() == nil, "removing the listener must not have configured a default app")
    }
}
