import SwiftUI
import AuthenticationServices

/// Appleアカウントでサインインするためのボタンコンポーネント
///
/// このボタンをタップすると、Appleの認証フローが開始されます。
/// 認証ロジックは環境値から取得した`AuthenticationUseCase`を使用します。
///
/// 使用例:
/// ```swift
/// VStack {
///     AppleSignInButton { error in
///         print("エラー: \(error)")
///     }
/// }
/// .authenticationUseCase(authUseCase)
/// ```
///
/// - Note: Apple Sign-InはiOSでのみ利用可能です。macOSでは使用できません。
public struct AppleSignInButton: View {
    @Environment(\.authenticationUseCase) private var authUseCase
    @State private var isLoading = false

    /// エラーコールバック
    private let onError: ((Error) -> Void)?

    /// ボタンのスタイル（.black または .white）
    private let buttonStyle: SignInWithAppleButton.Style

    /// イニシャライザ
    /// - Parameters:
    ///   - style: ボタンのスタイル（デフォルト: .black）
    ///   - onError: サインイン失敗時に呼ばれるコールバック（オプション）
    public init(
        style: SignInWithAppleButton.Style = .black,
        onError: ((Error) -> Void)? = nil
    ) {
        self.buttonStyle = style
        self.onError = onError
    }

    public var body: some View {
        #if os(iOS)
        SignInWithAppleButton { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            Task {
                await handleSignIn(result)
            }
        }
        .frame(height: 56)
        .signInWithAppleButtonStyle(buttonStyle)
        .disabled(isLoading || authUseCase == nil)
        .overlay {
            if isLoading {
                // ローディング中はオーバーレイを表示
                RoundedRectangle(cornerRadius: 8)
                    .fill(.black.opacity(0.3))
                    .overlay {
                        ProgressView()
                            .tint(.white)
                    }
            }
        }
        #else
        // macOSではApple Sign-Inは利用不可
        UnsupportedPlatformView()
        #endif
    }

    @MainActor
    private func handleSignIn(_ result: Result<ASAuthorization, Error>) async {
        guard let authUseCase = authUseCase else {
            onError?(NSError(
                domain: "AppleSignInButton",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "AuthenticationUseCaseが設定されていません"]
            ))
            return
        }

        isLoading = true

        switch result {
        case .success(let authorization):
            do {
                try await authUseCase.signInWithApple(authorization: authorization)
            } catch {
                onError?(error)
            }
        case .failure(let error):
            onError?(error)
        }

        isLoading = false
    }
}

#if os(macOS)
/// macOS用の非サポート表示ビュー
private struct UnsupportedPlatformView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Apple Sign-InはmacOSでは利用できません")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 56)
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}
#endif

// MARK: - Preview

#Preview("Apple Sign-In Button") {
    VStack(spacing: 24) {
        Text("Apple サインインボタン")
            .font(.headline)

        #if os(iOS)
        // 黒スタイル（デフォルト）
        AppleSignInButton(style: .black) { error in
            print("エラー: \(error)")
        }
        .padding(.horizontal, 32)

        // 白アウトラインスタイル
        AppleSignInButton(style: .whiteOutline) { error in
            print("エラー: \(error)")
        }
        .padding(.horizontal, 32)

        Text("※ AuthenticationUseCaseが設定されていないため、タップしても動作しません")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
        #else
        // macOS用の非サポート表示
        AppleSignInButton()
            .padding(.horizontal, 32)

        Text("※ macOSではApple Sign-Inは利用できません")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
        #endif
    }
    .padding()
}

#if os(iOS)
#Preview("Light & Dark Mode") {
    VStack(spacing: 16) {
        AppleSignInButton(style: .black)
            .padding(.horizontal, 32)
            .preferredColorScheme(.light)

        AppleSignInButton(style: .black)
            .padding(.horizontal, 32)
            .preferredColorScheme(.dark)
    }
    .padding()
}

#Preview("Button Sizes") {
    VStack(spacing: 16) {
        AppleSignInButton()
            .frame(width: 300)

        AppleSignInButton()
            .frame(width: 250)

        AppleSignInButton()
            .frame(width: 200)
    }
    .padding()
}
#endif
