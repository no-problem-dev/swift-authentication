import Foundation
import Observation

/// Owns the authentication session and publishes the state that views render from.
///
/// It threads the three layers together — acquisition (``CredentialProvider``), exchange
/// (``Authenticator``), post-authentication work (``PostAuthenticationAction``) — and exposes
/// the result as an observable ``state``.
///
/// - Dependencies arrive through `init`, which is the only place a provider SDK enters the
///   picture. This type imports none of them, so previews and tests build one from stubs.
/// - It is the single owner of ``state`` and of the guarantee that provisioning runs once per
///   user per session. Auth-state changes are consumed serially on the main actor, so a
///   provider that reports the same user repeatedly still provisions once.
@MainActor
@Observable
public final class AuthenticationStore {
    /// The current stage of the session, starting at checking until the authenticator reports
    /// what it found. Reading it from a view sets up the observation that redraws on change.
    public private(set) var state: AuthenticationState = .checking

    @ObservationIgnored private let authenticator: any Authenticator
    @ObservationIgnored private let postAuthentication: any PostAuthenticationAction
    @ObservationIgnored private let credentialProviders: [AuthProviderID: any CredentialProvider]

    /// The user whose post-authentication work has been claimed, so a repeated emission does
    /// not run it twice. Cleared on sign-out and on failure, which is what allows a retry.
    @ObservationIgnored private var provisionedUserID: String?
    @ObservationIgnored private var observationTask: Task<Void, Never>?

    /// Assembles a session from its three layers and starts observing straight away.
    ///
    /// - Parameters:
    ///   - authenticator: The exchange layer, for example `FirebaseAuthenticator`.
    ///   - postAuthentication: Work to run after sign-in. Defaults to doing nothing.
    ///   - credentialProviders: The providers sign-in may be requested for. When two report
    ///     the same identifier the last one wins.
    public init(
        authenticator: any Authenticator,
        postAuthentication: any PostAuthenticationAction = NoPostAuthentication(),
        credentialProviders: [any CredentialProvider] = []
    ) {
        self.authenticator = authenticator
        self.postAuthentication = postAuthentication
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
    /// ``Authenticator/authStateChanges()`` emit, and that path — not this one — provisions
    /// the user and advances ``state``. On failure ``state`` becomes an error before throwing.
    ///
    /// - Parameter credential: A credential from a provider, or ``AuthCredential/anonymous``.
    /// - Throws: ``AuthError/accountExistsWithDifferentProvider(provider:email:)`` unchanged
    ///   when the authenticator raised it, ``AuthError/sessionExchangeFailed(_:)`` otherwise.
    public func signIn(with credential: AuthCredential) async throws {
        do {
            _ = try await authenticator.signIn(with: credential)
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
    ///   switch to that account. ``AuthError/notAuthenticated`` when nobody is signed in, and
    ///   ``AuthError/linkFailed(_:)`` for anything else.
    public func link(with credential: AuthCredential) async throws {
        let linked: AuthUser
        do {
            linked = try await authenticator.link(with: credential)
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.linkFailed(error)
        }
        if case .authenticated(let current) = state, current.id == linked.id {
            state = .authenticated(linked)
        }
    }

    /// Signs in to the account that owns a credential which failed to link.
    ///
    /// Uses the replacement credential the server issued with the rejection. When there is
    /// none, it runs the provider's sign-in UI again for a fresh one — the credential that
    /// collided is never exchanged a second time, because an Apple identity token's nonce is
    /// spent by the attempted link.
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
    ///   authenticator raised it, and ``AuthError/sessionExchangeFailed(_:)`` when the exchange
    ///   fails otherwise.
    public func signIn(resolving collision: CredentialCollision) async throws {
        do {
            _ = try await authenticator.signIn(resolving: collision)
            return
        } catch AuthError.credentialAlreadyInUse {
            // No replacement this authenticator can use: fall through to a fresh credential.
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

    /// Wraps a failed exchange, except a refusal the person can act on, which keeps its name.
    private static func exchangeFailure(_ error: any Error) -> AuthError {
        if let authError = error as? AuthError, authError.code == .accountExistsWithDifferentProvider { return authError }
        return .sessionExchangeFailed(error)
    }

    // MARK: - Sign out and delete

    /// Ends the session.
    ///
    /// ``state`` is not touched here; it follows once the authenticator reports the user as
    /// gone, which keeps sign-outs triggered elsewhere on the same path as this one.
    ///
    /// - Throws: ``AuthError/signOutFailed(_:)``, after which stored credentials may still be
    ///   on the device.
    public func signOut() async throws {
        do {
            try await authenticator.signOut()
        } catch {
            throw AuthError.signOutFailed(error)
        }
    }

    /// Deletes the signed-in account. Irreversible.
    ///
    /// The authenticator ends the session once the account is gone, and ``state`` follows
    /// through its stream.
    ///
    /// - Throws: ``AuthError/deleteAccountFailed(_:)``. Everything the authenticator raised
    ///   arrives wrapped in that case, including ``AuthError/notAuthenticated`` when there was
    ///   no session, and a provider's refusal when the last sign-in is too old to authorise
    ///   deletion.
    public func deleteAccount() async throws {
        do {
            try await authenticator.deleteAccount()
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
        // A single main-actor task drains the stream serially: awaiting each handler means one
        // emission finishes before the next begins, so nothing interleaves.
        observationTask = Task { @MainActor [weak self] in
            for await user in stream {
                guard let self else { break }
                await self.handleAuthStateChange(user)
            }
        }
    }

    private func handleAuthStateChange(_ user: AuthUser?) async {
        guard let user else {
            provisionedUserID = nil
            state = .unauthenticated
            return
        }

        // Already provisioned: go straight through, so the UI never flashes a loading state.
        if provisionedUserID == user.id {
            state = .authenticated(user)
            return
        }

        // Claim the user synchronously, before any await, so back-to-back emissions for the
        // same user cannot both start provisioning.
        provisionedUserID = user.id
        state = .authenticatedPendingProvisioning
        do {
            try await postAuthentication.perform(for: user)
            // Commit only if the claim still stands; a sign-out during provisioning drops it.
            if provisionedUserID == user.id {
                state = .authenticated(user)
            }
        } catch {
            if provisionedUserID == user.id {
                provisionedUserID = nil   // Release the claim so a later attempt can provision.
            }
            // An action that already named its failure keeps that name. Wrapping an
            // `AuthError.notPermitted` in `postAuthenticationFailed` would put the caller back
            // where it started: one case for a refusal to re-authenticate against and a refusal
            // to stop asking about, told apart only by unwrapping.
            state = .error(error as? AuthError ?? AuthError.postAuthenticationFailed(error))
        }
    }
}
