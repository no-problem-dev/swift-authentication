import Testing
import Foundation
@testable import AuthenticationFirebase

/// Covers the sign-out `FirebaseConfigurator` performs on the first launch after an install.
///
/// Firebase keeps its session in the keychain, which survives deleting the app, so this is what
/// stops a reinstall from restoring whoever owned the device before. User defaults are the only
/// signal that the install is fresh, and there is exactly one of them: spending it on an attempt
/// that failed means the session is never cleared again.
@Suite("First-launch sign-out")
struct FirstLaunchSignOutTests {

    /// A user defaults instance of its own, so the tests never touch the real one.
    private func makeDefaults() -> UserDefaults {
        let suite = "FirstLaunchSignOutTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test("a fresh install signs out and records the launch")
    func freshInstallSignsOut() {
        let defaults = makeDefaults()
        var signOutCount = 0

        FirebaseConfigurator.clearStoredSessionOnFirstLaunch(defaults: defaults) {
            signOutCount += 1
        }

        #expect(signOutCount == 1)
        #expect(defaults.bool(forKey: FirebaseConfigurator.firstLaunchKey))
    }

    @Test("a later launch leaves the session alone")
    func laterLaunchDoesNothing() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: FirebaseConfigurator.firstLaunchKey)
        var signOutCount = 0

        FirebaseConfigurator.clearStoredSessionOnFirstLaunch(defaults: defaults) {
            signOutCount += 1
        }

        #expect(signOutCount == 0)
    }

    /// The one that matters: the keychain refused, so the previous owner is still signed in.
    @Test("a failed sign-out is retried on the next launch instead of being recorded as done")
    func failedSignOutIsRetried() {
        let defaults = makeDefaults()
        var attempts = 0
        var keychainIsAvailable = false

        func launch() {
            FirebaseConfigurator.clearStoredSessionOnFirstLaunch(defaults: defaults) {
                attempts += 1
                if !keychainIsAvailable { throw KeychainUnavailable() }
            }
        }

        // First launch: the session could not be cleared, so this is still a fresh install.
        launch()
        #expect(attempts == 1)
        #expect(
            defaults.bool(forKey: FirebaseConfigurator.firstLaunchKey) == false,
            "recording the launch after a failed sign-out strands the previous owner's session"
        )

        // Second launch: the keychain is readable, and the stale session finally goes.
        keychainIsAvailable = true
        launch()
        #expect(attempts == 2)
        #expect(defaults.bool(forKey: FirebaseConfigurator.firstLaunchKey))

        // Third launch: nothing left to do.
        launch()
        #expect(attempts == 2)
    }

    @Test("signing out is what happens when nothing is chosen")
    func signOutIsTheDefault() {
        let defaults = makeDefaults()
        var withDefault = 0
        var withSignOut = 0

        FirebaseConfigurator.clearStoredSessionOnFirstLaunch(defaults: defaults) {
            withDefault += 1
        }
        let other = makeDefaults()
        FirebaseConfigurator.clearStoredSessionOnFirstLaunch(
            defaults: other,
            sessionAfterReinstall: .signOut
        ) {
            withSignOut += 1
        }

        #expect(withDefault == 1)
        #expect(withSignOut == 1)
    }
}

/// Covers ``FirebaseConfigurator/SessionAfterReinstall/keep``, for apps that sign in only
/// anonymously: signing out there would strand the uid and everything the server keeps under it.
@Suite("Keeping the session after a reinstall")
struct KeepSessionAfterReinstallTests {

    private func makeDefaults() -> UserDefaults {
        let suite = "KeepSessionAfterReinstallTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    /// Never invoked — configuring needs a real `GoogleService-Info.plist`. Compiling is the test:
    /// the call sites in the documentation must resolve to exactly one overload each, and leaving
    /// the choice out must still pick the one that signs out.
    @Test("the documented call sites resolve to one overload each")
    func callSitesCompile() {
        let _: () -> Void = { FirebaseConfigurator.configure() }
        let _: () -> Void = { FirebaseConfigurator.configure(environment: .defaultEmulator) }
        let _: () -> Void = { FirebaseConfigurator.configure(sessionAfterReinstall: .keep) }
        let _: () -> Void = {
            FirebaseConfigurator.configure(
                environment: .defaultEmulator,
                sessionAfterReinstall: .keep,
                enableDebugMode: true
            )
        }
    }

    @Test("a fresh install keeps the session and records the launch")
    func freshInstallKeepsSession() {
        let defaults = makeDefaults()
        var signOutCount = 0

        FirebaseConfigurator.clearStoredSessionOnFirstLaunch(
            defaults: defaults,
            sessionAfterReinstall: .keep
        ) {
            signOutCount += 1
        }

        #expect(signOutCount == 0)
        #expect(defaults.bool(forKey: FirebaseConfigurator.firstLaunchKey))
    }

    @Test("no launch ever signs out")
    func neverSignsOut() {
        let defaults = makeDefaults()
        var signOutCount = 0

        for _ in 0..<3 {
            FirebaseConfigurator.clearStoredSessionOnFirstLaunch(
                defaults: defaults,
                sessionAfterReinstall: .keep
            ) {
                signOutCount += 1
            }
        }

        #expect(signOutCount == 0)
    }

    /// Recording the launch is what makes switching back safe: without it, the first launch
    /// after the app changes to `.signOut` would look like a fresh install and sign out the
    /// anonymous user it had kept until then.
    @Test("switching back to signing out later does not sign out the kept user")
    func switchingBackDoesNotSignOut() {
        let defaults = makeDefaults()
        var signOutCount = 0

        FirebaseConfigurator.clearStoredSessionOnFirstLaunch(
            defaults: defaults,
            sessionAfterReinstall: .keep
        ) {
            signOutCount += 1
        }
        FirebaseConfigurator.clearStoredSessionOnFirstLaunch(
            defaults: defaults,
            sessionAfterReinstall: .signOut
        ) {
            signOutCount += 1
        }

        #expect(signOutCount == 0)
    }
}

private struct KeychainUnavailable: Error {}
