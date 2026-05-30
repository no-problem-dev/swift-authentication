import Foundation
import Observation

/// View が依存する認証セッションのステートホルダ。
///
/// 取得（``CredentialProvider``）→ 交換（``Authenticator``）→ ログイン後処理
/// （``PostAuthenticationAction``）を束ね、`@Observable` な ``state`` を公開します。
///
/// - 依存は init で注入され、具象（`FirebaseAuthenticator` など）はここで刺さります。
///   本型自体は vendor 非依存なので、SwiftUI プレビューやテストでは
///   スタブ/モックを注入して SDK 無しで生成できます。
/// - ``state`` と post-auth の冪等性は本型が単一の所有者です。認証状態の変化は
///   ``Authenticator/authStateChanges()`` を MainActor 上で逐次購読して反映し、
///   プロビジョニングは認証セッション中に同一ユーザーへ一度だけ実行します。
@MainActor
@Observable
public final class AuthenticationStore {
    public private(set) var state: AuthenticationState = .checking

    @ObservationIgnored private let authenticator: any Authenticator
    @ObservationIgnored private let postAuthentication: any PostAuthenticationAction
    @ObservationIgnored private let credentialProviders: [AuthProviderID: any CredentialProvider]

    /// プロビジョニング済みユーザーの ID。同一セッションでの重複実行を防ぐ。
    @ObservationIgnored private var provisionedUserID: String?
    @ObservationIgnored private var observationTask: Task<Void, Never>?

    public init(
        authenticator: any Authenticator,
        postAuthentication: any PostAuthenticationAction = NoPostAuthentication(),
        credentialProviders: [any CredentialProvider] = []
    ) {
        self.authenticator = authenticator
        self.postAuthentication = postAuthentication
        self.credentialProviders = Dictionary(
            credentialProviders.map { ($0.providerID, $0) },
            uniquingKeysWith: { _, latest in latest }
        )
        startObservingAuthState()
    }

    /// 状態観測を停止します（任意。通常は不要だが明示的に破棄したい場合に使用）。
    public func stopObserving() {
        observationTask?.cancel()
        observationTask = nil
    }

    // MARK: - Sign in

    /// 登録済みの ``CredentialProvider`` で資格情報を取得し、サインインします。
    public func signIn(using providerID: AuthProviderID) async throws {
        guard let provider = credentialProviders[providerID] else {
            throw AuthError.unsupportedProvider(providerID)
        }
        let credential = try await acquireCredential(from: provider)
        try await signIn(with: credential)
    }

    /// 取得済みの資格情報でサインインします。
    ///
    /// 成功すると ``Authenticator/authStateChanges()`` が新しいユーザーを流し、
    /// 本型がプロビジョニングと ``state`` 更新を行います。
    public func signIn(with credential: AuthCredential) async throws {
        do {
            _ = try await authenticator.signIn(with: credential)
        } catch {
            let authError = AuthError.sessionExchangeFailed(error)
            state = .error(authError)
            throw authError
        }
    }

    public func signOut() async throws {
        do {
            try await authenticator.signOut()
        } catch {
            throw AuthError.signOutFailed(error)
        }
    }

    public func deleteAccount() async throws {
        do {
            try await authenticator.deleteAccount()
        } catch {
            throw AuthError.deleteAccountFailed(error)
        }
    }

    // MARK: - Internals

    private func acquireCredential(from provider: any CredentialProvider) async throws -> AuthCredential {
        do {
            return try await provider.acquireCredential()
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.credentialAcquisitionFailed(error)
        }
    }

    private func startObservingAuthState() {
        let stream = authenticator.authStateChanges()
        // 観測は単一の MainActor タスクで逐次実行する。`await handle` により
        // emission は 1 件ずつ完結してから次に進むため、重複/競合が起きない。
        observationTask = Task { @MainActor [weak self] in
            for await user in stream {
                guard let self else { break }
                await self.handleAuthStateChange(user)
            }
        }
    }

    private func handleAuthStateChange(_ user: AuthUser?) async {
        guard let user else {
            provisionedUserID = nil
            state = .unauthenticated
            return
        }

        // 既にプロビジョニング済みなら即 authenticated（フリッカー防止）。
        if provisionedUserID == user.id {
            state = .authenticated(user)
            return
        }

        // `provisionedUserID` への代入は await の前（同期）なので、同一ユーザーの
        // 連続 emission が重複してプロビジョニングを起動しない。
        provisionedUserID = user.id
        state = .authenticatedPendingProvisioning
        do {
            try await postAuthentication.perform(for: user)
            // プロビジョニング中にサインアウト等で予約解除されていなければ確定。
            if provisionedUserID == user.id {
                state = .authenticated(user)
            }
        } catch {
            if provisionedUserID == user.id {
                provisionedUserID = nil   // 失敗時は再試行を許可する。
            }
            state = .error(AuthError.postAuthenticationFailed(error))
        }
    }
}
