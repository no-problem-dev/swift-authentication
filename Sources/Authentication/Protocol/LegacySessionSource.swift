import Foundation

/// What an earlier version of the app left on the device, for the session server to trade for a
/// session of its own.
public enum LegacyCredential: Sendable, Equatable {
    /// A Firebase ID token, obtained through the Firebase SDK. Sent as `{ idToken }`.
    case firebaseIDToken(String)
    /// The refresh token Firebase Authentication stored on the device, read without the SDK.
    /// Sent as `{ refreshToken }`; the server trades it at Google for an ID token, so the device
    /// never talks to Google itself.
    case firebaseRefreshToken(String)
}

/// A session an earlier version of the app left on the device, which the session server can
/// trade for one of its own.
///
/// An app that used to sign in through another service — Firebase Authentication, say — hands
/// one to `SessionAuthenticator`. When the device has no session yet, the authenticator asks
/// for the old session's credential and exchanges it at `/v1/auth/firebase`, so the person keeps
/// their user id and everything stored under it, instead of starting over.
/// `swift-authentication-firebase` ships the Firebase conformance, which reads the keychain
/// without the Firebase SDK. An app that never used another service passes none.
public protocol LegacySessionSource: Sendable {
    /// Returns the credential of the session the earlier version left, or `nil` when there is
    /// none on this device.
    ///
    /// - Throws: Whatever stopped the credential from being read — ``ProtectedDataUnavailable``
    ///   for a keychain that is locked, an item in a shape this version does not know. The
    ///   authenticator then fails rather than starting over, and tries again the next time it is
    ///   asked to establish a session. Do not return `nil` while the device's protected data is
    ///   not available: a locked keychain can answer "not found" for an item that is there.
    func legacyCredential() async throws -> LegacyCredential?

    /// Forgets the earlier session: once it has been exchanged, once the server said it can never
    /// be exchanged, or when the person signed out.
    ///
    /// Without this, signing out and starting again would find the old session still on the
    /// device and exchange it back into the account the person just left.
    func discard() async throws
}
