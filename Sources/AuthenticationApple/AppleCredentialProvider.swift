import Foundation
import AuthenticationServices
import Authentication

/// Sign in with Apple の資格情報取得（取得層の具象）。
///
/// `ASAuthorizationController` を起動し、正しい nonce ハンドリング
/// （リクエストには SHA256 を設定し、生 nonce を資格情報へ載せる）で
/// vendor 非依存な ``AuthCredential`` を生成します。
public final class AppleCredentialProvider: CredentialProvider, @unchecked Sendable {
    public let providerID = AuthProviderID.apple
    private let requestedScopes: [ASAuthorization.Scope]

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

/// `ASAuthorizationController` の 1 回のフローを駆動するドライバ。
/// 自身を保持してコールバックまで生存し、完了時に継続を再開する。
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
