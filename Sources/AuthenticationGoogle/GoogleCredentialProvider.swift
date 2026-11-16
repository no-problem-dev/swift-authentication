import Foundation
import GoogleSignIn
import Authentication

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Runs Google Sign-In and returns the credential it produced.
///
/// The client ID is injected, typically read from the app's `Info.plist`. This is the only
/// target in the package that depends on an SDK, GoogleSignIn.
public final class GoogleCredentialProvider: CredentialProvider, @unchecked Sendable {
    public let providerID = AuthProviderID.google
    private let clientID: String

    /// Creates a provider.
    ///
    /// - Parameter clientID: The Google OAuth client ID, typically read from the app's
    ///   `Info.plist`.
    public init(clientID: String) {
        self.clientID = clientID
    }

    public func acquireCredential() async throws -> AuthCredential {
        try await acquireOnMain()
    }

    @MainActor
    private func acquireOnMain() async throws -> AuthCredential {
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        // Google puts the hash in the ID token's nonce claim; the server is sent the raw value
        // and checks the two match, as for Apple.
        let rawNonce = Nonce.randomNonceString()
        do {
            let result = try await Self.presentSignIn(nonce: Nonce.sha256(rawNonce))
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.credentialAcquisitionFailed(GoogleAuthError.missingIDToken)
            }
            let accessToken = result.user.accessToken.tokenString
            return AuthCredential(provider: .google, idToken: idToken, accessToken: accessToken, rawNonce: rawNonce)
        } catch let error as AuthError {
            throw error
        } catch {
            if Self.isCancellation(error) {
                throw AuthError.cancelled
            }
            throw AuthError.credentialAcquisitionFailed(error)
        }
    }

    @MainActor
    private static func presentSignIn(nonce: String) async throws -> GIDSignInResult {
        #if canImport(UIKit)
        guard let presenter = TopViewControllerProvider.topViewController() else {
            throw AuthError.configuration("Google Sign-In: no presenting UIViewController was found")
        }
        return try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter, hint: nil, additionalScopes: nil, nonce: nonce)
        #elseif canImport(AppKit)
        guard let window = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first else {
            throw AuthError.configuration("Google Sign-In: no presenting NSWindow was found")
        }
        return try await GIDSignIn.sharedInstance.signIn(withPresenting: window, hint: nil, additionalScopes: nil, nonce: nonce)
        #else
        throw AuthError.configuration("Google Sign-In: this platform is not supported")
        #endif
    }

    /// Whether the error is the user dismissing the consent screen.
    ///
    /// GoogleSignIn reports that as code -5 in its own error domain rather than as a distinct
    /// type, so matching it means matching the domain and the number.
    private static func isCancellation(_ error: any Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == "com.google.GIDSignIn" && nsError.code == -5
    }
}

enum GoogleAuthError: Error {
    case missingIDToken
}
