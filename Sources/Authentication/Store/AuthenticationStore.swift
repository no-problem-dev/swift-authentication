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
    /// - Throws: ``AuthError/sessionExchangeFailed(_:)``.
    public func signIn(with credential: AuthCredential) async throws {
        do {
            _ = try await authenticator.signIn(with: credential)
        } catch {
            let authError = AuthError.sessionExchangeFailed(error)
            state = .error(authError)
            throw authError
        }
    }

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
