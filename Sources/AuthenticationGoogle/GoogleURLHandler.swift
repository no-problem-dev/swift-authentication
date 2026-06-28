import Foundation
import GoogleSignIn

/// Google Sign-In のリダイレクト URL を処理するヘルパー。
///
/// アプリの `onOpenURL` / `application(_:open:options:)` から呼ぶ。
public enum GoogleURLHandler {
    /// `url` を Google Sign-In SDK に転送する。
    ///
    /// - Parameter url: アプリが受け取ったリダイレクト URL。
    /// - Returns: Google Sign-In が処理した場合 `true`、対象外の URL なら `false`。
    @discardableResult
    public static func handle(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }
}
