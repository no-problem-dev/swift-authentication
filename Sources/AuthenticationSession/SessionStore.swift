import Foundation

/// Where the device keeps its session between launches.
///
/// Synchronous on purpose: `SessionAuthenticator` reads and writes it from inside an actor, and
/// a store that suspended there would let another call slip in between a write and the
/// in-memory copy it keeps in step. ``KeychainSessionStore`` is the one to ship;
/// ``InMemorySessionStore`` is for tests and previews.
public protocol SessionStore: Sendable {
    /// Returns the stored session, or `nil` when there is none.
    ///
    /// - Throws: When the storage could not be read — ``ProtectedDataUnavailable`` for the
    ///   keychain before the first unlock or while locked, say. That is not the same as having
    ///   no session, and the authenticator does not start a new one over it. A store must not
    ///   return `nil` while it cannot tell whether a session is there.
    func load() throws -> AuthSession?

    /// Replaces the stored session.
    func save(_ session: AuthSession) throws

    /// Removes the stored session. Succeeds when there was none.
    func clear() throws
}

/// A ``SessionStore`` that lives only as long as the instance, for tests and previews.
public final class InMemorySessionStore: SessionStore, @unchecked Sendable {
    private let lock = NSLock()
    private var session: AuthSession?

    public init(_ session: AuthSession? = nil) {
        self.session = session
    }

    public func load() throws -> AuthSession? {
        lock.withLock { session }
    }

    public func save(_ session: AuthSession) throws {
        lock.withLock { self.session = session }
    }

    public func clear() throws {
        lock.withLock { session = nil }
    }
}
