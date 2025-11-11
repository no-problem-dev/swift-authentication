import Foundation
@preconcurrency import FirebaseCore

/// Firebase Authentication 初期化ユーティリティ
///
/// アプリ起動時にFirebase Authenticationを初期化するためのユーティリティです。
///
/// ## 使用例
///
/// ### 本番環境
/// ```swift
/// FirebaseConfigure.configure(environment: .production)
/// ```
///
/// ### エミュレーター環境
/// ```swift
/// FirebaseConfigure.configure(environment: .emulator())
/// ```
///
/// ### 条件分岐
/// ```swift
/// #if DEBUG
/// FirebaseConfigure.configure(environment: .emulator(), enableDebugMode: true)
/// #else
/// FirebaseConfigure.configure(environment: .production)
/// #endif
/// ```
///
/// ## 注意事項
/// - このライブラリは **Firebase Authentication のみ** を対象としています
/// - Firestore、Storage などは含まれません（バックエンド側の責務）
/// - iOS側からのデータアクセスは REST API 経由で行います
public struct FirebaseConfigure {

    /// Firebase Authentication 実行環境
    public enum Environment {
        /// 本番環境
        case production

        /// エミュレーター環境（Authentication のみ）
        /// - Parameters:
        ///   - host: Auth Emulator のホスト（デフォルト: "localhost"）
        ///   - port: Auth Emulator のポート（デフォルト: 9099）
        case emulator(host: String = "localhost", port: Int = 9099)

        /// デフォルトのエミュレーター設定
        public static var defaultEmulator: Environment {
            return .emulator()
        }
    }

    /// Firebase Authentication 初期化
    ///
    /// - Parameters:
    ///   - environment: 実行環境（デフォルト: .production）
    ///   - enableDebugMode: Firebase Analytics のデバッグモードを有効にするか（デフォルト: false）
    ///
    /// ## セキュリティ
    /// RELEASEビルドではエミュレーター環境の使用が禁止されています。
    /// エミュレーター環境を指定した場合、アプリはクラッシュします。
    public static func configure(
        environment: Environment = .production,
        enableDebugMode: Bool = false
    ) {
        // RELEASEビルドでエミュレーター使用を禁止
        #if !DEBUG
        if case .emulator = environment {
            fatalError("⛔️ Firebase Emulator cannot be used in RELEASE builds for security reasons")
        }
        #endif

        // デバッグモード設定
        if enableDebugMode {
            // iOS 18での問題に対応するため、UserDefaultsも設定
            UserDefaults.standard.set(true, forKey: "/google/firebase/debug_mode")
            UserDefaults.standard.set(true, forKey: "/google/measurement/debug_mode")
            print("🔧 Firebase Analytics DebugView enabled")
        }

        // Authentication エミュレーター環境変数設定
        if case .emulator(let host, let port) = environment {
            let authEmulatorHost = "\(host):\(port)"

            // 環境変数設定（Firebase SDK が自動認識）
            setenv("FIREBASE_AUTH_EMULATOR_HOST", authEmulatorHost, 1)

            print("🔥 Firebase Authentication Emulator Mode")
            print("  🔐 Auth Emulator: \(authEmulatorHost)")
            print("  📝 Note: Firestore, Storage は使用しません（REST API経由）")
        }

        // Firebase初期化
        FirebaseApp.configure()

        // 環境確認ログ
        switch environment {
        case .production:
            print("🚀 Firebase Authentication: Production Mode")
        case .emulator:
            print("🧪 Firebase Authentication: Emulator Mode Active")
        }
    }
}
