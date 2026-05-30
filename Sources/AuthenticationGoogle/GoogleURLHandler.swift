import Foundation
import GoogleSignIn

/// Google Sign-In のリダイレクト URL を処理するヘルパー。
///
/// アプリの `onOpenURL` / `application(_:open:options:)` から呼びます。
public enum GoogleURLHandler {
    @discardableResult
    public static func handle(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }
}
