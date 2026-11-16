import Foundation

/// A session an earlier version of the app left on the device, which the session server can
/// trade for one of its own.
///
/// An app that used to sign in through another service — Firebase Authentication, say — hands
/// one to `SessionAuthenticator`. When the device has no session yet, the authenticator asks
/// for the old one's ID token and exchanges it, so the person keeps their user id and
/// everything stored under it, instead of starting over as a new anonymous user.
/// `swift-authentication-firebase` ships the Firebase conformance. An app that never used
/// another service passes none.
public protocol LegacySessionSource: Sendable {
    /// Returns an ID token for the session the earlier version left, or `nil` when there is
    /// none on this device.
    ///
    /// - Throws: Whatever stopped the token from being obtained — no network, say. The
    ///   authenticator then fails rather than starting a new anonymous user, and tries again
    ///   the next time it is asked to establish a session.
    func legacyIDToken() async throws -> String?

    /// Forgets the earlier session, once it has been exchanged or the person signed out.
    ///
    /// Without this, signing out and starting again would find the old session still on the
    /// device and exchange it back into the account the person just left.
    func discardLegacySession() async throws
}
