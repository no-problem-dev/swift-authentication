import Foundation
import Authentication

public extension AuthCredential {
    /// Sign in with Apple 用の ``AuthCredential`` を生成するファクトリ。
    /// - Parameters:
    ///   - idToken: Apple の identityToken（JWT 文字列）。
    ///   - rawNonce: リクエストに使った生 nonce（SHA256 前の値）。
    ///   - fullName: 初回認証時に得られる氏名（任意）。
    static func apple(
        idToken: String,
        rawNonce: String,
        fullName: PersonName? = nil
    ) -> AuthCredential {
        AuthCredential(
            provider: .apple,
            idToken: idToken,
            accessToken: nil,
            rawNonce: rawNonce,
            fullName: fullName
        )
    }
}
