import Foundation
@preconcurrency import FirebaseAuth
import Authentication

/// Converts a Firebase user into the vendor-neutral user value the core deals in.
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
