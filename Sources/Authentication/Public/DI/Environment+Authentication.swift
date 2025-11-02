import SwiftUI

/// AuthenticationUseCase用の環境値キー
///
/// SwiftUIの環境値システムで認証ユースケースを伝播させるためのキーです。
public struct AuthenticationUseCaseKey: EnvironmentKey {
    public static var defaultValue: AuthenticationUseCase? {
        nil
    }
}

public extension EnvironmentValues {
    /// 認証ユースケースの環境値
    ///
    /// 使用例:
    /// ```swift
    /// @Environment(\.authenticationUseCase) private var authenticationUseCase
    /// ```
    var authenticationUseCase: AuthenticationUseCase? {
        get { self[AuthenticationUseCaseKey.self] }
        set { self[AuthenticationUseCaseKey.self] = newValue }
    }
}

/// AuthenticationUseCaseを注入するためのViewModifier
///
/// パッケージ境界を越えて環境値を確実に伝播させます。
/// 通常は`View.authenticationUseCase(_:)`メソッド経由で使用します。
public struct AuthenticationUseCaseModifier: ViewModifier {
    private let authenticationUseCase: AuthenticationUseCase

    public init(authenticationUseCase: AuthenticationUseCase) {
        self.authenticationUseCase = authenticationUseCase
    }

    public func body(content: Content) -> some View {
        content
            .environment(\.authenticationUseCase, authenticationUseCase)
    }
}

public extension View {
    /// AuthenticationUseCaseを注入する
    ///
    /// - Parameter authenticationUseCase: 使用するAuthenticationUseCaseインスタンス
    /// - Returns: AuthenticationUseCaseが注入されたView
    ///
    /// 使用例:
    /// ```swift
    /// let authUseCase = AuthenticationUseCaseImpl(
    ///     apiClient: apiClient,
    ///     authenticationPath: "/api/v1/auth/initialize"
    /// )
    /// ContentView()
    ///     .authenticationUseCase(authUseCase)
    /// ```
    func authenticationUseCase(_ authenticationUseCase: AuthenticationUseCase) -> some View {
        modifier(AuthenticationUseCaseModifier(authenticationUseCase: authenticationUseCase))
    }
}
