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
/// 認証状態に基づいてコンテンツを出し分けるルートビュー
///
/// 認証状態を監視し、以下の画面を自動的に切り替えます：
/// - **loading**: 認証確認中またはバックエンド初期化中（スプラッシュ画面など）
/// - **unauthenticated**: 未認証（サインイン画面）
/// - **error**: 認証エラー発生時
/// - **authenticated**: 認証完了（メインコンテンツ）
///
/// 環境値から`AuthenticationUseCase`を取得して動作します。
///
/// 使用例:
/// ```swift
/// AuthenticatedRootView(
///     loading: {
///         MySplashScreen()
///     },
///     unauthenticated: {
///         VStack {
///             MyAppLogo()
///             GoogleSignInButton()
///             AppleSignInButton()
///         }
///     },
///     error: { error in
///         MyErrorScreen(error: error)
///     },
///     authenticated: {
///         MainTabView()
///     }
/// )
/// .authenticationUseCase(authUseCase)
/// ```
/// 認証状態に基づいてコンテンツを出し分けるルートビュー
///
/// 認証状態を監視し、以下の画面を自動的に切り替えます：
/// - **loading**: 認証確認中またはバックエンド初期化中（スプラッシュ画面など）
/// - **unauthenticated**: 未認証（サインイン画面）
/// - **error**: 認証エラー発生時
/// - **authenticated**: 認証完了（メインコンテンツ）
///
/// 環境値から`AuthenticationUseCase`を取得して動作します。
///
/// 使用例:
/// ```swift
/// AuthenticatedRootView(
///     loading: {
///         MySplashScreen()
///     },
///     unauthenticated: {
///         VStack {
///             MyAppLogo()
///             GoogleSignInButton()
///             AppleSignInButton()
///         }
///     },
///     error: { error in
///         MyErrorScreen(error: error)
///     },
///     authenticated: {
///         MainTabView()
///     }
/// )
/// .authenticationUseCase(authUseCase)
/// ```
public struct AuthenticatedRootView<
    LoadingView: View,
    UnauthenticatedView: View,
    ErrorView: View,
    AuthenticatedView: View
>: View {
    @Environment(\.authenticationUseCase) private var authUseCase
    @State private var authState: AuthenticationState = .checking

    private let loadingView: () -> LoadingView
    private let unauthenticatedView: () -> UnauthenticatedView
    private let errorView: (Error) -> ErrorView
    private let authenticatedView: () -> AuthenticatedView

    /// イニシャライザ
    /// - Parameters:
    ///   - loading: 認証確認中またはバックエンド初期化中に表示するビュー（スプラッシュ画面など）
    ///   - unauthenticated: 未認証時に表示するビュー（サインイン画面）
    ///   - error: エラー発生時に表示するビュー
    ///   - authenticated: 認証完了後に表示するビュー（メインコンテンツ）
    public init(
        @ViewBuilder loading: @escaping () -> LoadingView,
        @ViewBuilder unauthenticated: @escaping () -> UnauthenticatedView,
        @ViewBuilder error: @escaping (Error) -> ErrorView,
        @ViewBuilder authenticated: @escaping () -> AuthenticatedView
    ) {
        self.loadingView = loading
        self.unauthenticatedView = unauthenticated
        self.errorView = error
        self.authenticatedView = authenticated
    }

    public var body: some View {
        Group {
            if authUseCase == nil {
                // AuthenticationUseCaseが設定されていない場合のエラー表示
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
        case .checking, .firebaseAuthenticatedOnly:
            // 認証確認中と初期化中は同じローディング画面を表示
            loadingView()

        case .unauthenticated:
            // 未認証時はユーザー提供のサインイン画面を表示
            unauthenticatedView()

        case .authenticated:
            // 認証完了時はメインコンテンツを表示
            authenticatedView()

        case .error(let error):
            // エラー発生時はユーザー提供のエラー画面を表示
            errorView(error)
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
}

// MARK: - Preview

#Preview("Loading State") {
    AuthenticatedRootView(
        loading: {
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                Text("読み込み中...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        },
        unauthenticated: {
            Text("Unauthenticated")
        },
        error: { _ in
            Text("Error")
        },
        authenticated: {
            Text("Authenticated")
        }
    )
}

#Preview("Unauthenticated State") {
    AuthenticatedRootView(
        loading: {
            ProgressView()
        },
        unauthenticated: {
            VStack(spacing: 32) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text("マイアプリ")
                    .font(.largeTitle.bold())

                Text("サインインしてください")
                    .font(.body)
                    .foregroundStyle(.secondary)

                VStack(spacing: 16) {
                    GoogleSignInButton()
                    AppleSignInButton()
                }
                .padding(.horizontal, 32)
            }
        },
        error: { _ in
            Text("Error")
        },
        authenticated: {
            Text("Authenticated")
        }
    )
}

#Preview("Error State") {
    AuthenticatedRootView(
        loading: {
            ProgressView()
        },
        unauthenticated: {
            Text("Unauthenticated")
        },
        error: { error in
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.red)

                VStack(spacing: 8) {
                    Text("エラーが発生しました")
                        .font(.title2.bold())

                    Text(error.localizedDescription)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button("再試行") {
                    // 再試行ロジック
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(32)
        },
        authenticated: {
            Text("Authenticated")
        }
    )
}

#Preview("Authenticated State") {
    AuthenticatedRootView(
        loading: {
            ProgressView()
        },
        unauthenticated: {
            Text("Unauthenticated")
        },
        error: { _ in
            Text("Error")
        },
        authenticated: {
            VStack(spacing: 16) {
                Text("ようこそ！")
                    .font(.largeTitle.bold())

                Text("認証が完了しました")
                    .font(.body)
                    .foregroundStyle(.secondary)

                Button("サインアウト") {
                    // サインアウトロジック
                }
                .buttonStyle(.bordered)
            }
        }
    )
}

#Preview("Complete Sign-In Flow") {
    AuthenticatedRootView(
        loading: {
            VStack(spacing: 16) {
                Image(systemName: "hourglass")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
                ProgressView()
                Text("初期化中...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        },
        unauthenticated: {
            VStack(spacing: 40) {
                VStack(spacing: 16) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.blue)

                    VStack(spacing: 8) {
                        Text("セキュアアプリ")
                            .font(.title.bold())

                        Text("安全にログインしてください")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(spacing: 16) {
                    GoogleSignInButton { error in
                        print("Google Sign-In エラー: \(error)")
                    }

                    #if os(iOS)
                    AppleSignInButton { error in
                        print("Apple Sign-In エラー: \(error)")
                    }
                    #endif
                }
                .padding(.horizontal, 32)

                Text("サインインすることで、利用規約とプライバシーポリシーに同意したものとみなされます")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        },
        error: { error in
            VStack(spacing: 24) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.red)

                VStack(spacing: 12) {
                    Text("認証エラー")
                        .font(.title.bold())

                    Text(error.localizedDescription)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                VStack(spacing: 12) {
                    Button("再試行") {
                        // 再試行
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button("キャンセル") {
                        // キャンセル
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(32)
        },
        authenticated: {
            NavigationStack {
                VStack(spacing: 24) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.green)

                    VStack(spacing: 8) {
                        Text("認証完了")
                            .font(.title.bold())

                        Text("ようこそ！")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    Divider()
                        .padding(.vertical)

                    VStack(spacing: 16) {
                        NavigationLink("プロフィール") {
                            Text("プロフィール画面")
                        }
                        .buttonStyle(.borderedProminent)

                        NavigationLink("設定") {
                            Text("設定画面")
                        }
                        .buttonStyle(.bordered)

                        Button("サインアウト") {
                            // サインアウト
                        }
                        .buttonStyle(.bordered)
                        .foregroundStyle(.red)
                    }
                }
                .padding(32)
                .navigationTitle("メイン画面")
            }
        }
    )
}
