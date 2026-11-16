import Foundation
import Authentication

/// A switch to an existing account that the server has agreed to and the device has not made yet.
///
/// Returned by ``SessionAuthenticator/findExisting(with:)``. Call exactly one of ``commit()`` and
/// ``cancel()``.
public struct PendingAccountSwitch: Sendable {
    let session: AuthSession
    let deviceSession: DeviceSession

    /// The account the switch leads to.
    public var user: AuthUser { session.user.authUser }

    /// Makes the switch: the found session replaces the current one. When that changes the user,
    /// the previous session's device is revoked on the server, best effort — as
    /// ``SessionAuthenticator/signInExisting(with:)`` does.
    ///
    /// - Throws: ``KeychainSessionStore/Failure`` when the session could not be stored.
    @discardableResult
    public func commit() async throws -> AuthUser {
        try await deviceSession.commitSwitch(to: session)
        return user
    }

    /// Drops the switch. The device keeps its current session, and the session the server issued
    /// for the switch is revoked at `/v1/auth/sign-out`, best effort.
    public func cancel() async {
        await deviceSession.discardFound(session)
    }
}
