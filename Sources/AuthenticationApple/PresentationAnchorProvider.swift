import Foundation
import AuthenticationServices

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Finds the window the system should anchor the Apple authorization sheet to.
///
/// Prefers the key window of the foreground scene and falls back to an empty anchor rather
/// than trapping, so a process with no visible window fails the sign-in instead of crashing.
@MainActor
enum PresentationAnchorProvider {
    static func anchor() -> ASPresentationAnchor {
        #if canImport(UIKit)
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
            ?? scenes.first as? UIWindowScene
        let window = windowScene?.windows.first { $0.isKeyWindow } ?? windowScene?.windows.first
        return window ?? ASPresentationAnchor()
        #elseif canImport(AppKit)
        return NSApplication.shared.keyWindow
            ?? NSApplication.shared.windows.first
            ?? ASPresentationAnchor()
        #else
        return ASPresentationAnchor()
        #endif
    }
}
