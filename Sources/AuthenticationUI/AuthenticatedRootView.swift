import SwiftUI
import Authentication

/// 認証状態に基づいてコンテンツを出し分けるルートビュー。
///
/// Environment の ``AuthenticationStore`` の `state` を観測し、4 つの状態に対応する
/// ビューを切り替えます。状態管理は `AuthenticationStore`（`@Observable`）が行うため、
/// 本ビューは宣言的に分岐するだけです。
public struct AuthenticatedRootView<
    LoadingView: View,
    UnauthenticatedView: View,
    ErrorView: View,
    AuthenticatedView: View
>: View {
    @Environment(\.authenticationStore) private var store

    private let loadingView: () -> LoadingView
    private let unauthenticatedView: () -> UnauthenticatedView
    private let errorView: (any Error) -> ErrorView
    private let authenticatedView: (AuthUser) -> AuthenticatedView

    /// - Parameters:
    ///   - loading: 確認中・プロビジョニング中の表示。
    ///   - unauthenticated: 未認証時の表示（サインイン画面）。
    ///   - error: エラー時の表示。
    ///   - authenticated: 認証完了後の表示（認証済みユーザーを受け取る）。
    public init(
        @ViewBuilder loading: @escaping () -> LoadingView,
        @ViewBuilder unauthenticated: @escaping () -> UnauthenticatedView,
        @ViewBuilder error: @escaping (any Error) -> ErrorView,
        @ViewBuilder authenticated: @escaping (AuthUser) -> AuthenticatedView
    ) {
        self.loadingView = loading
        self.unauthenticatedView = unauthenticated
        self.errorView = error
        self.authenticatedView = authenticated
    }

    public var body: some View {
        if let store {
            content(for: store.state)
        } else {
            ConfigurationErrorView()
        }
    }

    @ViewBuilder
    private func content(for state: AuthenticationState) -> some View {
        switch state {
        case .checking, .authenticatedPendingProvisioning:
            loadingView()
        case .unauthenticated:
            unauthenticatedView()
        case .authenticated(let user):
            authenticatedView(user)
        case .error(let error):
            errorView(error)
        }
    }
}

private struct ConfigurationErrorView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(.red)
            Text("認証設定エラー")
                .font(.title)
            Text("AuthenticationStore が Environment に設定されていません")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview("Unauthenticated") {
    AuthenticatedRootView(
        loading: { ProgressView() },
        unauthenticated: {
            VStack(spacing: 16) {
                Text("サインイン").font(.title)
                GoogleSignInButton()
                AppleSignInButton()
            }
            .padding(.horizontal, 32)
        },
        error: { Text("エラー: \($0.localizedDescription)") },
        authenticated: { user in Text("ようこそ \(user.id)") }
    )
    .authenticationStore(.previewUnauthenticated)
}
