import Foundation
@preconcurrency import FirebaseCore
@preconcurrency import FirebaseAuth

/// Firebase Authentication の初期化ユーティリティ。
///
/// このパッケージは **Firebase Authentication のみ** を対象とする
/// （Firestore / Storage は含まない。データアクセスは REST API 経由）。
public enum FirebaseConfigurator {

    /// Firebase Authentication 実行環境。
    public enum Environment: Sendable {
        /// Firebase クラウドの本番環境。
        case production
        /// ローカルで起動した Firebase Emulator Suite。デバッグ・テスト用。
        case emulator(host: String = "localhost", port: Int = 9099)

        public static var defaultEmulator: Environment { .emulator() }
    }

    /// Firebase を初期化する。
    ///
    /// アプリ起動時に一度だけ呼ぶ。
    ///
    /// - Important: セキュリティのため、RELEASE ビルドでエミュレーター環境を指定すると
    ///   `fatalError` でクラッシュする。
    /// - Note: 初回起動（アプリインストール直後）には、キーチェーンに残った古いセッションを
    ///   クリアするため、自動的に `Auth.signOut()` が実行される。再インストール後の
    ///   意図しない自動ログインを防ぐための副作用。
    public static func configure(
        environment: Environment = .production,
        enableDebugMode: Bool = false
    ) {
        #if !DEBUG
        if case .emulator = environment {
            fatalError("⛔️ Firebase Emulator cannot be used in RELEASE builds for security reasons")
        }
        #endif

        if enableDebugMode {
            UserDefaults.standard.set(true, forKey: "/google/firebase/debug_mode")
            UserDefaults.standard.set(true, forKey: "/google/measurement/debug_mode")
        }

        FirebaseApp.configure()

        // エミュレーター設定は FirebaseApp.configure() の後に行う必要がある。
        if case .emulator(let host, let port) = environment {
            Auth.auth().useEmulator(withHost: host, port: port)
        }

        signOutOnFirstLaunchIfNeeded()
    }

    /// `GoogleService-Info.plist` 由来の Google OAuth クライアント ID。
    ///
    /// `GoogleCredentialProvider(clientID:)` に渡す用途。利用側が
    /// FirebaseCore に直接依存せず clientID を取得できる。
    public static var googleClientID: String? {
        FirebaseApp.app()?.options.clientID
    }

    /// 初回起動時の自動サインアウト。
    ///
    /// Firebase Auth はキーチェーンにログイン状態を永続化するため、アプリ削除後の
    /// 再インストールでも自動ログインが復元されてしまう。UserDefaults の初回起動フラグで
    /// 初回のみサインアウトし、クリーンな状態を保証する。
    private static func signOutOnFirstLaunchIfNeeded() {
        guard FirebaseApp.app() != nil else { return }

        let userDefaults = UserDefaults.standard
        let key = "com.noproblem.authentication.hasLaunchedBefore"

        if !userDefaults.bool(forKey: key) {
            try? Auth.auth().signOut()
            userDefaults.set(true, forKey: key)
        }
    }
}
