import Foundation
@preconcurrency import FirebaseCore

/// Firebase初期化ユーティリティ
///
/// アプリ起動時にFirebaseを初期化するためのユーティリティクラスです。
///
/// 使用例:
/// ```swift
/// @main
/// struct MyApp: App {
///     init() {
///         FirebaseConfigure.configure(enableDebugMode: false)
///     }
/// }
/// ```
public struct FirebaseConfigure {
    /// Firebase初期化
    /// - Parameter enableDebugMode: デバッグモードを有効にするか（デフォルト: false）
    public static func configure(enableDebugMode: Bool = false) {
        if enableDebugMode {
            // iOS 18での問題に対応するため、UserDefaultsも設定
            UserDefaults.standard.set(true, forKey: "/google/firebase/debug_mode")
            UserDefaults.standard.set(true, forKey: "/google/measurement/debug_mode")
            print("🔧 Firebase Analytics DebugView enabled for DEBUG build")
        }

        // Firebase初期化
        FirebaseApp.configure()
    }
}
