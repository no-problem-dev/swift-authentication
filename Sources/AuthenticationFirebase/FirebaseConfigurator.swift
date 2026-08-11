import Foundation
@preconcurrency import FirebaseCore
@preconcurrency import FirebaseAuth

/// Starts Firebase for authentication and nothing else.
///
/// The package deliberately pulls in **only Firebase Authentication** — no Firestore, no
/// Storage — because application data goes through your own REST API.
public enum FirebaseConfigurator {

    /// Which Firebase backend the app talks to.
    public enum Environment: Sendable {
        /// The live Firebase project: real accounts, real tokens.
        case production
        /// A locally running Firebase Emulator Suite, for development and tests.
        ///
        /// Refused in release builds — see ``configure(environment:enableDebugMode:)``.
        case emulator(host: String = "localhost", port: Int = 9099)

        public static var defaultEmulator: Environment { .emulator() }
    }

    /// Configures Firebase. Call once, at launch, before anything touches authentication.
    ///
    /// - Parameters:
    ///   - environment: Which backend to talk to. Defaults to the live project.
    ///   - enableDebugMode: Turns on Firebase's verbose diagnostics by writing its debug flags
    ///     to user defaults. Leave it off in shipping builds.
    ///
    /// - Important: Pointing a release build at the emulator would authenticate real users
    ///   against a server that trusts everyone, so it traps instead of starting.
    /// - Note: On the first launch after an install this signs out. Firebase keeps sessions in
    ///   the keychain, which survives deleting the app, so without this a reinstall would
    ///   silently restore the previous owner's session.
    public static func configure(
        environment: Environment = .production,
        enableDebugMode: Bool = false
    ) {
        #if !DEBUG
        if case .emulator = environment {
            fatalError("⛔️ Firebase Emulator cannot be used in RELEASE builds for security reasons")
        }
        #endif

        if enableDebugMode {
            UserDefaults.standard.set(true, forKey: "/google/firebase/debug_mode")
            UserDefaults.standard.set(true, forKey: "/google/measurement/debug_mode")
        }

        FirebaseApp.configure()

        // The emulator can only be selected after the app has been configured.
        if case .emulator(let host, let port) = environment {
            Auth.auth().useEmulator(withHost: host, port: port)
        }

        signOutOnFirstLaunchIfNeeded()
    }

    /// The Google OAuth client ID that came from `GoogleService-Info.plist`, or `nil` before
    /// Firebase has been configured.
    ///
    /// Feed it to `GoogleCredentialProvider(clientID:)`. It exists so the composition root can
    /// reach the value without importing FirebaseCore itself.
    public static var googleClientID: String? {
        FirebaseApp.app()?.options.clientID
    }

    /// Signs out on the first launch after an install.
    ///
    /// Firebase persists the session in the keychain, which is not removed when the app is
    /// deleted, so a reinstall would otherwise restore whoever was signed in before. User
    /// defaults are cleared by deletion, which makes their emptiness a reliable signal that
    /// this is a fresh install.
    private static func signOutOnFirstLaunchIfNeeded() {
        guard FirebaseApp.app() != nil else { return }
        clearStoredSessionOnFirstLaunch(defaults: .standard) {
            try Auth.auth().signOut()
        }
    }

    /// The user defaults key that records the first launch as handled.
    static let firstLaunchKey = "com.noproblem.authentication.hasLaunchedBefore"

    /// Clears the session left behind by a previous install, and records the launch as handled
    /// only once that has actually happened.
    ///
    /// Signing out writes to the keychain, which can refuse — most plausibly when the app is
    /// launched in the background before the device has been unlocked since boot. Recording the
    /// launch anyway would spend the one signal that says this is a fresh install on an attempt
    /// that failed, and the previous owner's session would then survive every later launch: the
    /// exact outcome this exists to prevent. So a failure leaves the key unset and the next
    /// launch tries again.
    ///
    /// - Parameters:
    ///   - defaults: Where the first-launch flag lives. Deleting the app clears it, which is what
    ///     makes its absence mean "fresh install".
    ///   - signOut: Clears the stored session. Throwing means the session is still there.
    static func clearStoredSessionOnFirstLaunch(
        defaults: UserDefaults,
        signOut: () throws -> Void
    ) {
        guard !defaults.bool(forKey: firstLaunchKey) else { return }

        do {
            try signOut()
            defaults.set(true, forKey: firstLaunchKey)
        } catch {
            // Deliberately leaves the key unset. The session is still on the device, so this is
            // still the first launch as far as the next one is concerned.
        }
    }
}
