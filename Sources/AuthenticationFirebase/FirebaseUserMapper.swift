import Foundation
@preconcurrency import FirebaseAuth
import Authentication

/// Firebase の `User` を vendor 非依存な ``AuthUser`` に変換する。
enum FirebaseUserMapper {
    static func map(_ user: User) -> AuthUser {
        AuthUser(
            id: user.uid,
            email: user.email,
            displayName: user.displayName,
            isAnonymous: user.isAnonymous,
            providerIDs: user.providerData.map { Authentication.AuthProviderID(rawValue: $0.providerID) }
        )
    }
}
