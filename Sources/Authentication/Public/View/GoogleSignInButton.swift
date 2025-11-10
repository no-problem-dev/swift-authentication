import SwiftUI

/// Googleアカウントでサインインするためのボタンコンポーネント
///
/// このボタンをタップすると、Googleの認証フローが開始されます。
/// 認証ロジックは環境値から取得した`AuthenticationUseCase`を使用します。
///
/// 使用例:
/// ```swift
/// VStack {
///     GoogleSignInButton { error in
///         print("エラー: \(error)")
///     }
/// }
/// .authenticationUseCase(authUseCase)
/// ```
public struct GoogleSignInButton: View {
    @Environment(\.authenticationUseCase) private var authUseCase
    @State private var isLoading = false

    /// エラーコールバック
    private let onError: ((Error) -> Void)?

    /// イニシャライザ
    /// - Parameter onError: サインイン失敗時に呼ばれるコールバック（オプション）
    public init(onError: ((Error) -> Void)? = nil) {
        self.onError = onError
    }

    public var body: some View {
        Button {
            Task { await signIn() }
        } label: {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .tint(.primary)
                        .frame(width: 20, height: 20)
                } else {
                    Image(.googleLogo)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                }
                Text("Googleでログイン")
                    .font(.system(size: 17, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
        }
        .buttonStyle(GoogleSignInButtonStyle())
        .disabled(isLoading || authUseCase == nil)
    }

    @MainActor
    private func signIn() async {
        guard let authUseCase = authUseCase else {
            onError?(NSError(
                domain: "GoogleSignInButton",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "AuthenticationUseCaseが設定されていません"]
            ))
            return
        }

        isLoading = true

        do {
            try await authUseCase.signInWithGoogle()
        } catch {
            onError?(error)
        }

        isLoading = false
    }
}

/// Googleサインインボタンのスタイル
///
/// シンプルなアウトラインスタイルで、Apple Sign-Inボタンと一貫性のあるデザイン。
/// タップ時のフィードバックとスムーズなアニメーションを提供します。
public struct GoogleSignInButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.primary.opacity(0.3), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemBackground))
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.6)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview("Google Sign-In Button") {
    VStack(spacing: 24) {
        Text("Google サインインボタン")
            .font(.headline)

        // 通常状態
        GoogleSignInButton { error in
            print("エラー: \(error)")
        }
        .padding(.horizontal, 32)

        // 無効状態
        GoogleSignInButton()
            .disabled(true)
            .padding(.horizontal, 32)

        Text("※ AuthenticationUseCaseが設定されていないため、タップしても動作しません")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
    }
    .padding()
}

#Preview("Light & Dark Mode") {
    VStack(spacing: 16) {
        GoogleSignInButton()
            .padding(.horizontal, 32)
            .preferredColorScheme(.light)

        GoogleSignInButton()
            .padding(.horizontal, 32)
            .preferredColorScheme(.dark)
    }
    .padding()
}

#Preview("Button Sizes") {
    VStack(spacing: 16) {
        GoogleSignInButton()
            .frame(width: 300)

        GoogleSignInButton()
            .frame(width: 250)

        GoogleSignInButton()
            .frame(width: 200)
    }
    .padding()
}
