import Foundation
import Observation

/// Owns the authentication session and publishes the state that views render from.
///
/// It threads the two layers together — acquisition (``CredentialProvider``) and exchange
/// (``Authenticator``) — and exposes the result as an observable ``state``. What the app does
/// once someone is signed in is the app's business, not the store's.
///
/// Dependencies arrive through `init`, which is the only place a provider SDK enters the
/// picture. This type imports none of them, so previews and tests build one from stubs.
@MainActor
@Observable
public final class AuthenticationStore {
    /// The current stage of the session, starting at checking until the authenticator reports
    /// what it found. Reading it from a view sets up the observation that redraws on change.
    public private(set) var state: AuthenticationState = .checking

    @ObservationIgnored private let authenticator: any Authenticator
    @ObservationIgnored private let credentialProviders: [AuthProviderID: any CredentialProvider]

    @ObservationIgnored private var observationTask: Task<Void, Never>?

    /// Assembles a session from its layers and starts observing straight away.
    ///
    /// - Parameters:
    ///   - authenticator: The exchange layer, for example `SessionAuthenticator`.
    ///   - credentialProviders: The providers sign-in may be requested for. When two report
    ///     the same identifier the last one wins.
    public init(
        authenticator: any Authenticator,
        credentialProviders: [any CredentialProvider] = []
    ) {
        self.authenticator = authenticator
        self.credentialProviders = Dictionary(
            credentialProviders.map { ($0.providerID, $0) },
            uniquingKeysWith: { _, latest in latest }
        )
        startObservingAuthState()
    }

    /// Stops consuming auth-state changes.
    ///
    /// Rarely needed, since the observation dies with the store. Call it when a store must be
    /// torn down deterministically: afterwards ``state`` is frozen and cannot be resumed.
    public func stopObserving() {
        observationTask?.cancel()
        observationTask = nil
    }

    // MARK: - Sign in

    /// Runs a registered provider's sign-in UI and exchanges what it returns.
    ///
    /// - Parameter providerID: Which registered provider to use.
    /// - Throws: ``AuthError/unsupportedProvider(_:)`` when nothing was registered for that
    ///   identifier, ``AuthError/cancelled`` when the user backs out, and
    ///   ``AuthError/credentialAcquisitionFailed(_:)`` for anything else the provider raised.
    public func signIn(using providerID: AuthProviderID) async throws {
        guard let provider = credentialProviders[providerID] else {
            throw AuthError.unsupportedProvider(providerID)
        }
        let credential = try await acquireCredential(from: provider)
        try await signIn(with: credential)
    }

    /// Exchanges a credential you already hold for a session.
    ///
    /// The exchanged user is discarded on purpose. Success makes
    /// ``Authenticator/authStateChanges()`` emit, and that path — not this one — advances
    /// ``state``. On failure ``state`` becomes an error before throwing — except while the
    /// device's protected data is unavailable, which is a wait, not a failure.
    ///
    /// - Parameter credential: A credential from a provider, or ``AuthCredential/anonymous``.
    /// - Throws: ``ProtectedDataUnavailable`` unchanged, with ``state`` left as it was: the
    ///   keychain is locked, so call this again once it is not.
    ///   ``AuthError/accountExistsWithDifferentProvider(provider:email:)`` and
    ///   ``AuthError/accountDeleted`` unchanged when the authenticator raised them,
    ///   ``AuthError/sessionExchangeFailed(_:)`` otherwise.
    public func signIn(with credential: AuthCredential) async throws {
        do {
            _ = try await authenticator.signIn(with: credential)
        } catch let error as ProtectedDataUnavailable {
            throw error
        } catch {
            let authError = Self.exchangeFailure(error)
            state = .error(authError)
            throw authError
        }
    }

    // MARK: - Link

    /// Runs a registered provider's sign-in UI and links what it returns to the signed-in
    /// account, keeping its user id.
    ///
    /// The way to upgrade an anonymous account without losing what it holds.
    ///
    /// - Parameter providerID: Which registered provider to use.
    /// - Throws: ``AuthError/unsupportedProvider(_:)``, ``AuthError/cancelled`` and
    ///   ``AuthError/credentialAcquisitionFailed(_:)`` as for ``signIn(using:)``, then whatever
    ///   ``link(with:)`` throws.
    public func link(using providerID: AuthProviderID) async throws {
        guard let provider = credentialProviders[providerID] else {
            throw AuthError.unsupportedProvider(providerID)
        }
        let credential = try await acquireCredential(from: provider)
        try await link(with: credential)
    }

    /// Links a credential you already hold to the signed-in account, keeping its user id.
    ///
    /// ``state`` never becomes an error here: a failed link leaves the session exactly as it
    /// was. A successful one republishes the user, whose ``AuthUser/isAnonymous`` and
    /// ``AuthUser/providerIDs`` have changed — linking starts no new session, so the
    /// authenticator's stream has nothing to report.
    ///
    /// - Parameter credential: A provider credential.
    /// - Throws: ``AuthError/credentialAlreadyInUse(_:)`` when another account already owns
    ///   the credential — pass its payload to ``signIn(resolving:)`` if the person chooses to
    ///   switch to that account. ``AuthError/notAuthenticated`` when nobody is signed in,
    ///   ``ProtectedDataUnavailable`` unchanged while the keychain is locked, and
    ///   ``AuthError/linkFailed(_:)`` for anything else.
    public func link(with credential: AuthCredential) async throws {
        let linked: AuthUser
        do {
            linked = try await authenticator.link(with: credential)
        } catch let error as AuthError {
            throw error
        } catch let error as ProtectedDataUnavailable {
            throw error
        } catch {
            throw AuthError.linkFailed(error)
        }
        if case .authenticated(let current) = state, current.id == linked.id {
            state = .authenticated(linked)
        }
    }

    /// Removes a provider from the signed-in account, keeping its user id.
    ///
    /// Like ``link(with:)``, a success republishes the user and a failure leaves ``state``
    /// alone.
    ///
    /// - Throws: Whatever ``Authenticator/unlink(_:)`` threw.
    public func unlink(_ provider: AuthProviderID) async throws {
        let unlinked = try await authenticator.unlink(provider)
        if case .authenticated(let current) = state, current.id == unlinked.id {
            state = .authenticated(unlinked)
        }
    }

    // MARK: - Sign in to an existing account

    /// Runs a registered provider's sign-in UI and signs in to the account the credential
    /// already belongs to — without creating one or linking anything when there is none.
    ///
    /// For a "sign in to my existing account" screen. ``state`` follows through the
    /// authenticator's stream when the account changes.
    ///
    /// - Parameter providerID: Which registered provider to use.
    /// - Returns: `true` when an existing account was found and is now signed in, `false` when
    ///   the credential belongs to no account; the current session is then untouched.
    /// - Throws: ``AuthError/unsupportedProvider(_:)``, ``AuthError/cancelled`` and
    ///   ``AuthError/credentialAcquisitionFailed(_:)`` as for ``signIn(using:)``.
    ///   ``AuthError/accountExistsWithDifferentProvider(provider:email:)`` and
    ///   ``AuthError/accountDeleted`` unchanged, ``ProtectedDataUnavailable`` unchanged while the
    ///   keychain is locked, ``AuthError/sessionExchangeFailed(_:)`` for anything else.
    @discardableResult
    public func signInExisting(using providerID: AuthProviderID) async throws -> Bool {
        guard let provider = credentialProviders[providerID] else {
            throw AuthError.unsupportedProvider(providerID)
        }
        let credential = try await acquireCredential(from: provider)
        do {
            return try await authenticator.signInExisting(with: credential) != nil
        } catch {
            throw Self.exchangeFailure(error)
        }
    }

    /// Signs in to the account that owns a credential which failed to link.
    ///
    /// Hands the collided credential to the authenticator first, which signs in with it when
    /// its server accepts the same token twice — the session server does. When the
    /// authenticator cannot reuse it, this runs the provider's sign-in UI again for a fresh one.
    ///
    /// The user id changes to the owning account's; what the previous account held stays with
    /// it. ``state`` follows through the authenticator's stream, as for ``signIn(with:)``. A
    /// failure leaves the current session and ``state`` as they were.
    ///
    /// - Parameter collision: The payload of ``AuthError/credentialAlreadyInUse(_:)``.
    /// - Throws: ``AuthError/unsupportedProvider(_:)`` when a fresh credential is needed and no
    ///   provider is registered for ``CredentialCollision/provider``, ``AuthError/cancelled``
    ///   when the person backs out of the provider's sheet,
    ///   ``AuthError/accountExistsWithDifferentProvider(provider:email:)`` unchanged when the
    ///   authenticator raised it, ``ProtectedDataUnavailable`` unchanged while the keychain is
    ///   locked, and ``AuthError/sessionExchangeFailed(_:)`` when the exchange fails otherwise.
    public func signIn(resolving collision: CredentialCollision) async throws {
        do {
            _ = try await authenticator.signIn(resolving: collision)
            return
        } catch AuthError.credentialAlreadyInUse {
            // The collided credential cannot be used again: fall through to a fresh one.
        } catch {
            throw Self.exchangeFailure(error)
        }

        guard let provider = credentialProviders[collision.provider] else {
            throw AuthError.unsupportedProvider(collision.provider)
        }
        let fresh = try await acquireCredential(from: provider)
        do {
            _ = try await authenticator.signIn(with: fresh)
        } catch {
            throw Self.exchangeFailure(error)
        }
    }

    /// Wraps a failed exchange, except a refusal the person can act on, which keeps its name,
    /// and a locked keychain, which is a wait and not a failed exchange.
    private static func exchangeFailure(_ error: any Error) -> any Error {
        if error is ProtectedDataUnavailable { return error }
        if let authError = error as? AuthError,
           authError.code == .accountExistsWithDifferentProvider || authError.code == .accountDeleted {
            return authError
        }
        return AuthError.sessionExchangeFailed(error)
    }

    // MARK: - Sign out and delete

    /// Ends the session.
    ///
    /// ``state`` is not touched here; it follows once the authenticator reports the user as
    /// gone, which keeps sign-outs triggered elsewhere on the same path as this one.
    ///
    /// - Throws: ``ProtectedDataUnavailable`` unchanged while the keychain is locked, and
    ///   ``AuthError/signOutFailed(_:)`` otherwise. Either way stored credentials may still be on
    ///   the device.
    public func signOut() async throws {
        do {
            try await authenticator.signOut()
        } catch let error as ProtectedDataUnavailable {
            throw error
        } catch {
            throw AuthError.signOutFailed(error)
        }
    }

    /// Deletes the signed-in account. Irreversible.
    ///
    /// When the account is linked to Apple and an Apple ``CredentialProvider`` is registered,
    /// this first runs Apple's authorization sheet for a fresh authorization code and passes it
    /// on, so the server can revoke the person's Apple tokens as App Review requires (guideline
    /// 5.1.1(v)). Apple accepts each code once and for about five minutes, which is why it is
    /// obtained here and not kept from sign-in.
    ///
    /// The authenticator ends the session once the account is gone, and ``state`` follows
    /// through its stream.
    ///
    /// - Throws: ``AuthError/cancelled`` unchanged when the person backs out of the Apple
    ///   sheet — nothing was deleted. ``ProtectedDataUnavailable`` unchanged while the keychain
    ///   is locked. ``AuthError/deleteAccountFailed(_:)`` for everything else, including
    ///   ``AuthError/notAuthenticated`` when there was no session.
    public func deleteAccount() async throws {
        let appleAuthorizationCode = try await appleAuthorizationCodeForDeletion()
        do {
            try await authenticator.deleteAccount(appleAuthorizationCode: appleAuthorizationCode)
        } catch let error as ProtectedDataUnavailable {
            throw error
        } catch {
            throw AuthError.deleteAccountFailed(error)
        }
    }

    private func appleAuthorizationCodeForDeletion() async throws -> String? {
        guard let user = await authenticator.currentUser(),
              user.providerIDs.contains(.apple),
              let apple = credentialProviders[.apple] else { return nil }
        do {
            return try await apple.acquireCredential().authorizationCode
        } catch let error as AuthError where error.code == .cancelled {
            throw error
        } catch {
            throw AuthError.deleteAccountFailed(error)
        }
    }

    // MARK: - Internals

    private func acquireCredential(from provider: any CredentialProvider) async throws -> AuthCredential {
        do {
            return try await provider.acquireCredential()
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.credentialAcquisitionFailed(error)
        }
    }

    private func startObservingAuthState() {
        let stream = authenticator.authStateChanges()
        // A single main-actor task drains the stream, so emissions apply in order.
        observationTask = Task { @MainActor [weak self] in
            for await user in stream {
                guard let self else { break }
                self.handleAuthStateChange(user)
            }
        }
    }

    private func handleAuthStateChange(_ user: AuthUser?) {
        state = user.map(AuthenticationState.authenticated) ?? .unauthenticated
    }
}
