import SwiftUI
import AuthenticationServices

/// 認証画面
///
/// GoogleアカウントまたはApple IDでのサインインを提供します。
/// アプリ固有のロゴやタイトルは外部から注入してください。
///
/// 環境値から`AuthenticationUseCase`を取得して動作します。
///
/// 使用例:
/// ```swift
/// AuthenticationView {
///     VStack(spacing: 16) {
///         Image(systemName: "book.fill")
///             .font(.system(size: 80))
///         Text("マイアプリ")
///             .font(.largeTitle)
///     }
/// }
/// ```
public struct AuthenticationView<HeaderContent: View>: View {
    @Environment(\.authenticationUseCase) private var authUseCase

    @State private var isLoading = false
    @State private var errorMessage: String?

    private let headerContent: HeaderContent

    /// イニシャライザ
    /// - Parameter headerContent: アプリロゴやタイトルなどのヘッダーコンテンツ
    public init(
        @ViewBuilder headerContent: () -> HeaderContent
    ) {
        self.headerContent = headerContent()
    }

    public var body: some View {
        VStack(spacing: 32) {
            headerContent

            VStack(spacing: 16) {
                // Google Sign-In ボタン
                Button {
                    Task {
                        await signInWithGoogle()
                    }
                } label: {
                    HStack {
                        Image(systemName: "g.circle.fill")
                        Text("Googleでログイン")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)

                // Apple Sign-In ボタン
                SignInWithAppleButton { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    Task {
                        await handleAppleSignIn(result)
                    }
                }
                .frame(height: 50)
                .disabled(isLoading)
            }
            .padding(.horizontal, 32)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.2))
            }
        }
    }

    @MainActor
    private func signInWithGoogle() async {
        guard let authUseCase = authUseCase else {
            errorMessage = "認証設定エラー"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await authUseCase.signInWithGoogle()
        } catch {
            errorMessage = "ログインに失敗しました: \(error.localizedDescription)"
        }

        isLoading = false
    }

    @MainActor
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        guard let authUseCase = authUseCase else {
            errorMessage = "認証設定エラー"
            return
        }

        isLoading = true
        errorMessage = nil

        switch result {
        case .success(let authorization):
            do {
                try await authUseCase.signInWithApple(authorization: authorization)
            } catch {
                errorMessage = "ログインに失敗しました: \(error.localizedDescription)"
            }
        case .failure(let error):
            errorMessage = "ログインに失敗しました: \(error.localizedDescription)"
        }

        isLoading = false
    }
}
