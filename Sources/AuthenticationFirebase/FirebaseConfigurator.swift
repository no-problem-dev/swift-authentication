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

        let userDefaults = UserDefaults.standard
        let key = "com.noproblem.authentication.hasLaunchedBefore"

        if !userDefaults.bool(forKey: key) {
            try? Auth.auth().signOut()
            userDefaults.set(true, forKey: key)
        }
    }
}
