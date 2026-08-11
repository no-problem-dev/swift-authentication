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
}

private struct KeychainUnavailable: Error {}
