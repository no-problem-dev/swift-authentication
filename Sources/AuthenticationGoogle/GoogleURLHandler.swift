import Foundation
import GoogleSignIn

/// Hands OAuth redirect URLs back to Google Sign-In.
///
/// Call it from `onOpenURL` or `application(_:open:options:)`. Without it the browser round
/// trip never completes and sign-in appears to hang with no error.
public enum GoogleURLHandler {
    /// Forwards a URL to the Google Sign-In SDK.
    ///
    /// - Parameter url: The URL the app was opened with.
    /// - Returns: `true` when Google Sign-In consumed it. `false` means the URL belongs to
    ///   something else and the app still has to handle it.
    @discardableResult
    public static func handle(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }
}
