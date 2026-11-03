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

    /// What happens to the Firebase session a previous install left in the keychain.
    ///
    /// Deleting the app removes its user defaults but not its keychain items, so after a
    /// reinstall Firebase finds the old session and restores it. Whether that is a leak or the
    /// whole point depends on what the session stands for.
    public enum SessionAfterReinstall: Sendable {
        /// Sign out on the first launch after an install, as
        /// ``configure(environment:enableDebugMode:)`` does.
        ///
        /// Choose this when people sign in with an identity of their own — Apple, Google, email.
        /// The device may have changed hands, and the person who reinstalls can sign in again,
        /// so restoring the previous session silently would hand one person's account to
        /// another.
        case signOut

        /// Keep the session, so a reinstall comes back as the same user.
        ///
        /// Choose this when the app signs in **only anonymously**. An anonymous user has no
        /// credential to sign in with again: once signed out, the uid — and every record your
        /// server keeps under it — is unreachable for good. Keeping the session lets a reinstall
        /// read those records again. The trade-off is that whoever holds the device inherits the
        /// anonymous account, which is acceptable only because it carries no identity.
        ///
        /// The keychain does not survive everything: restoring a backup onto a different device
        /// or erasing the device still starts a new anonymous user.
        case keep
    }

    /// Configures Firebase, signing out on the first launch after an install. Call once, at
    /// launch, before anything touches authentication.
    ///
    /// The same as ``configure(environment:sessionAfterReinstall:enableDebugMode:)`` with
    /// ``SessionAfterReinstall/signOut`` — the right choice for any app where people sign in
    /// with an identity of their own.
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
        configure(
            environment: environment,
            sessionAfterReinstall: .signOut,
            enableDebugMode: enableDebugMode
        )
    }

    /// Configures Firebase, choosing what happens to the session a previous install left
    /// behind. Call once, at launch, before anything touches authentication.
    ///
    /// ```swift
    /// // An app with Apple / Google sign-in: a reinstall starts signed out.
    /// FirebaseConfigurator.configure()
    ///
    /// // An app that only ever signs in anonymously: a reinstall keeps the same user.
    /// FirebaseConfigurator.configure(sessionAfterReinstall: .keep)
    /// ```
    ///
    /// - Parameters:
    ///   - environment: Which backend to talk to. Defaults to the live project.
    ///   - sessionAfterReinstall: What to do with the session a previous install left in the
    ///     keychain. Pass ``SessionAfterReinstall/keep`` only for an app whose sign-in is
    ///     anonymous alone; see ``SessionAfterReinstall`` for why.
    ///   - enableDebugMode: Turns on Firebase's verbose diagnostics by writing its debug flags
    ///     to user defaults. Leave it off in shipping builds.
    ///
    /// - Important: Pointing a release build at the emulator would authenticate real users
    ///   against a server that trusts everyone, so it traps instead of starting.
    public static func configure(
        environment: Environment = .production,
        sessionAfterReinstall: SessionAfterReinstall,
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

        signOutOnFirstLaunchIfNeeded(sessionAfterReinstall)
    }

    /// The Google OAuth client ID that came from `GoogleService-Info.plist`, or `nil` before
    /// Firebase has been configured.
    ///
    /// Feed it to `GoogleCredentialProvider(clientID:)`. It exists so the composition root can
    /// reach the value without importing FirebaseCore itself.
    public static var googleClientID: String? {
        FirebaseApp.app()?.options.clientID
    }

    /// Signs out on the first launch after an install, unless the app asked to keep the session.
    ///
    /// Firebase persists the session in the keychain, which is not removed when the app is
    /// deleted, so a reinstall would otherwise restore whoever was signed in before. User
    /// defaults are cleared by deletion, which makes their emptiness a reliable signal that
    /// this is a fresh install.
    private static func signOutOnFirstLaunchIfNeeded(
        _ sessionAfterReinstall: SessionAfterReinstall
    ) {
        guard FirebaseApp.app() != nil else { return }
        clearStoredSessionOnFirstLaunch(
            defaults: .standard,
            sessionAfterReinstall: sessionAfterReinstall
        ) {
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
    /// With ``SessionAfterReinstall/keep`` it never signs out, but still records the launch. An
    /// app that later switches back to ``SessionAfterReinstall/signOut`` would otherwise read its
    /// next launch as a fresh install and sign out the user it had been keeping.
    ///
    /// - Parameters:
    ///   - defaults: Where the first-launch flag lives. Deleting the app clears it, which is what
    ///     makes its absence mean "fresh install".
    ///   - sessionAfterReinstall: Whether a fresh install clears the session or keeps it.
    ///   - signOut: Clears the stored session. Throwing means the session is still there.
    static func clearStoredSessionOnFirstLaunch(
        defaults: UserDefaults,
        sessionAfterReinstall: SessionAfterReinstall = .signOut,
        signOut: () throws -> Void
    ) {
        guard !defaults.bool(forKey: firstLaunchKey) else { return }

        if case .keep = sessionAfterReinstall {
            defaults.set(true, forKey: firstLaunchKey)
            return
        }

        do {
            try signOut()
            defaults.set(true, forKey: firstLaunchKey)
        } catch {
            // Deliberately leaves the key unset. The session is still on the device, so this is
            // still the first launch as far as the next one is concerned.
        }
    }
}
