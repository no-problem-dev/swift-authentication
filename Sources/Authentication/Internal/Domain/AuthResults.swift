import Foundation

enum SignInResult {
    case success
    case failure(AuthError)
}

enum SignOutResult {
    case success
    case failure(AuthError)
}

enum DeleteAccountResult {
    case success
    case failure(AuthError)
}

enum AuthError: Error {
    case notAuthenticated
    case googleSignInFailed(Error)
    case appleSignInFailed(Error)
    case signOutFailed(Error)
    case deleteAccountFailed(Error)
    case apiAuthFailed(Error)
    case unknown(Error)
}
