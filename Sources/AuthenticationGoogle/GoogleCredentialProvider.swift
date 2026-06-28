import Foundation
import GoogleSignIn
import Authentication

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Google Sign-In の資格情報取得（取得層の具象）。
///
/// `clientID` は合成ルートから注入する（FirebaseCore に依存しないため、
/// `FirebaseApp.app()?.options.clientID` をアプリ側から渡す想定）。
public final class GoogleCredentialProvider: CredentialProvider, @unchecked Sendable {
    public let providerID = AuthProviderID.google
    private let clientID: String

    /// Google 資格情報プロバイダを生成する。
    ///
    /// - Parameter clientID: Google OAuth クライアント ID。
    ///   `FirebaseConfigurator.googleClientID` から取得するか、アプリの `Info.plist` から直接渡す。
    public init(clientID: String) {
        self.clientID = clientID
    }

    public func acquireCredential() async throws -> AuthCredential {
        try await acquireOnMain()
    }

    @MainActor
    private func acquireOnMain() async throws -> AuthCredential {
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        do {
            let result = try await Self.presentSignIn()
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.credentialAcquisitionFailed(GoogleAuthError.missingIDToken)
            }
            let accessToken = result.user.accessToken.tokenString
            return AuthCredential(provider: .google, idToken: idToken, accessToken: accessToken)
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
    private static func presentSignIn() async throws -> GIDSignInResult {
        #if canImport(UIKit)
        guard let presenter = TopViewControllerProvider.topViewController() else {
            throw AuthError.configuration("Google Sign-In: 表示元の UIViewController が見つかりません")
        }
        return try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        #elseif canImport(AppKit)
        guard let window = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first else {
            throw AuthError.configuration("Google Sign-In: 表示元の NSWindow が見つかりません")
        }
        return try await GIDSignIn.sharedInstance.signIn(withPresenting: window)
        #else
        throw AuthError.configuration("Google Sign-In: このプラットフォームは未対応です")
        #endif
    }

    /// GIDSignInError のキャンセル（domain "com.google.GIDSignIn", code -5）を判定する。
    private static func isCancellation(_ error: any Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == "com.google.GIDSignIn" && nsError.code == -5
    }
}

enum GoogleAuthError: Error {
    case missingIDToken
}
