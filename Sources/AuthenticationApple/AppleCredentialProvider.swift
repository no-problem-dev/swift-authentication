import Foundation
import AuthenticationServices
import Authentication

/// Runs Sign in with Apple and returns the credential it produced.
///
/// Presents `ASAuthorizationController` and handles the nonce the way Apple requires: the
/// request carries the SHA-256 hash while the credential carries the raw value, so the server
/// can match the two and reject a replayed identity token. Sending the pair the other way
/// round yields a token that cannot be verified.
public final class AppleCredentialProvider: CredentialProvider, @unchecked Sendable {
    public let providerID = AuthProviderID.apple
    private let requestedScopes: [ASAuthorization.Scope]

    /// Creates a provider.
    ///
    /// - Parameter requestedScopes: What to ask Apple for. Defaults to the full name and the
    ///   email address; narrow it if the app genuinely needs neither, since Apple returns the
    ///   name only once and never again for the same account.
    public init(requestedScopes: [ASAuthorization.Scope] = [.fullName, .email]) {
        self.requestedScopes = requestedScopes
    }

    public func acquireCredential() async throws -> AuthCredential {
        let rawNonce = Nonce.randomNonceString()
        let hashedNonce = Nonce.sha256(rawNonce)
        let scopes = requestedScopes
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                let driver = AppleAuthorizationDriver(rawNonce: rawNonce, continuation: continuation)
                driver.start(requestedScopes: scopes, hashedNonce: hashedNonce)
            }
        }
    }
}

/// Drives one `ASAuthorizationController` flow and resumes a continuation with its outcome.
///
/// It holds a reference to itself because the controller does not retain its delegate: without
/// that, the object would be deallocated before the callback and the continuation would never
/// resume. The reference is dropped the moment it does.
@MainActor
private final class AppleAuthorizationDriver: NSObject {
    private let rawNonce: String
    private var continuation: CheckedContinuation<AuthCredential, any Error>?
    private var retainSelf: AppleAuthorizationDriver?

    init(rawNonce: String, continuation: CheckedContinuation<AuthCredential, any Error>) {
        self.rawNonce = rawNonce
        self.continuation = continuation
    }

    func start(requestedScopes: [ASAuthorization.Scope], hashedNonce: String) {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = requestedScopes
        request.nonce = hashedNonce

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        retainSelf = self
        controller.performRequests()
    }

    private func finish(_ result: Result<AuthCredential, any Error>) {
        continuation?.resume(with: result)
        continuation = nil
        retainSelf = nil
    }
}

extension AppleAuthorizationDriver: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        MainActor.assumeIsolated {
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8)
            else {
                finish(.failure(AuthError.credentialAcquisitionFailed(
                    AppleAuthorizationError.missingIdentityToken
                )))
                return
            }
            let credentialValue = AuthCredential.apple(
                idToken: idToken,
                rawNonce: rawNonce,
                fullName: PersonName(components: credential.fullName)
            )
            finish(.success(credentialValue))
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: any Error
    ) {
        MainActor.assumeIsolated {
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                finish(.failure(AuthError.cancelled))
            } else {
                finish(.failure(AuthError.credentialAcquisitionFailed(error)))
            }
        }
    }
}

extension AppleAuthorizationDriver: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(
        for controller: ASAuthorizationController
    ) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            PresentationAnchorProvider.anchor()
        }
    }
}

enum AppleAuthorizationError: Error {
    case missingIdentityToken
}
