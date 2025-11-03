import SwiftUI

/// 認証状態に基づいてコンテンツを出し分けるルートビュー
///
/// 認証状態を監視し、以下の画面を自動的に切り替えます：
/// - 未認証: ログイン画面
/// - 認証済み: メインコンテンツ
///
/// 環境値から`AuthenticationUseCase`を取得して動作します。
///
/// 使用例:
/// ```swift
/// AuthenticatedRootView(
///     authenticationHeader: {
///         VStack {
///             Image(systemName: "book.fill")
///             Text("マイアプリ")
///         }
///     },
///     authenticatedContent: { MainTabView() }
/// )
/// .authenticationUseCase(authUseCase)
/// ```
public struct AuthenticatedRootView<AuthHeaderContent: View, AuthenticatedContent: View>: View {
    @Environment(\.authenticationUseCase) private var authUseCase
    private let authenticationHeader: AuthHeaderContent
    private let authenticatedContent: () -> AuthenticatedContent

    @State private var authState: AuthenticationState = .checking

    /// イニシャライザ
    /// - Parameters:
    ///   - authenticationHeader: 認証画面のヘッダーコンテンツ（ロゴやタイトル）
    ///   - authenticatedContent: 認証済みの場合に表示するコンテンツ
    public init(
        @ViewBuilder authenticationHeader: () -> AuthHeaderContent,
        @ViewBuilder authenticatedContent: @escaping () -> AuthenticatedContent
    ) {
        self.authenticationHeader = authenticationHeader()
        self.authenticatedContent = authenticatedContent
    }

    public var body: some View {
        Group {
            if authUseCase == nil {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundStyle(.red)
                    Text("認証設定エラー")
                        .font(.title)
                    Text("AuthenticationUseCaseが設定されていません")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                authContent
            }
        }
        .task {
            guard authUseCase != nil else { return }
            await checkInitialAuth()
        }
        .task {
            guard let authUseCase = authUseCase else { return }
            for await state in authUseCase.observeAuthState() {
                await MainActor.run {
                    authState = state
                }
            }
        }
    }

    @ViewBuilder
    private var authContent: some View {
        switch authState {
        case .checking:
            ProgressView("認証確認中...")

        case .unauthenticated:
            AuthenticationView {
                authenticationHeader
            }

        case .firebaseAuthenticatedOnly:
            ProgressView("初期化中...")

        case .authenticated:
            authenticatedContent()

        case .error(let error):
            VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundStyle(.red)
                    Text("認証エラー")
                        .font(.title)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("再試行") {
                        Task {
                            await retry()
                        }
                    }
                }
            }
        }

    @MainActor
    private func checkInitialAuth() async {
        guard let authUseCase = authUseCase else { return }
        if await authUseCase.isAuthenticated() {
            authState = .firebaseAuthenticatedOnly
        } else {
            authState = .unauthenticated
        }
    }

    @MainActor
    private func retry() async {
        authState = .checking
        await checkInitialAuth()
    }
}
