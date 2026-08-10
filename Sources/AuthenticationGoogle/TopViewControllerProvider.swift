#if canImport(UIKit)
import UIKit

/// Finds the view controller Google Sign-In should present from.
///
/// Walks past anything already presented, so the consent screen is not put up behind a sheet
/// that is already on screen.
@MainActor
enum TopViewControllerProvider {
    static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
            ?? scenes.first as? UIWindowScene
        let keyWindow = windowScene?.windows.first { $0.isKeyWindow } ?? windowScene?.windows.first
        var top = keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
#endif
