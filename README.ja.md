[English](./README.md) | 日本語

# swift-authentication

vendor 非依存なコア抽象に、Firebase / Apple / Google / REST の具象を**ターゲット単位で差し込む**認証パッケージ。

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017+%20%7C%20macOS%2014+-blue.svg)
![SPM](https://img.shields.io/badge/SwiftPM-compatible-brightgreen.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

## 設計

認証を 3 つの責務に分離し、それぞれを vendor 非依存なプロトコルとして規定する。具象は
別ターゲットで実装し、合成ルート（アプリ起動時）で差し込む。

| 責務 | プロトコル（コア） | 具象（別ターゲット） |
|---|---|---|
| 資格情報の取得 | `CredentialProvider` | `AppleCredentialProvider` / `GoogleCredentialProvider` |
| セッション交換 | `Authenticator` | `FirebaseAuthenticator` |
| ログイン後処理（冪等） | `PostAuthenticationAction` | `APIUserProvisioning`（REST） |

これらを束ねる `@Observable` な **`AuthenticationStore`**（`@MainActor`）が `state` を公開し、
画面はこれを観測する。

### ターゲット構成

| ターゲット | 役割 | 外部依存 |
|---|---|---|
| **`Authentication`** | コア抽象（プロトコル・値型・`AuthenticationStore`） | **なし** |
| **`AuthenticationUI`** | SwiftUI ビュー + Environment DI | SwiftUI（システム） |
| **`AuthenticationApple`** | Apple 資格情報取得 | AuthenticationServices / CryptoKit（システム） |
| **`AuthenticationGoogle`** | Google 資格情報取得 | GoogleSignIn |
| **`AuthenticationFirebase`** | Firebase でのセッション交換・設定 | FirebaseAuth |
| **`AuthenticationAPI`** | REST でのログイン後処理 | swift-api-client |

**コア（`Authentication`）とUI（`AuthenticationUI`）はベンダー SDK に依存しない。**
画面はこの 2 つだけに依存できるため、SwiftUI プレビューで Firebase / GoogleSignIn を
読み込まない。具象（Firebase 等）は合成ルートでのみ import する。

## インストール

```swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-authentication.git", from: "2.0.0")
]
```

利用側ターゲットでは必要な product だけを依存に追加する。

- 画面モジュール → `AuthenticationUI`（+ `Authentication`）
- 合成ルート（App 本体）→ `AuthenticationFirebase` / `AuthenticationApple` / `AuthenticationGoogle` / `AuthenticationAPI`

## 使い方

### 1. 合成ルートで `AuthenticationStore` を組み立てる

```swift
import SwiftUI
import Authentication
import AuthenticationUI
import AuthenticationFirebase
import AuthenticationApple
import AuthenticationGoogle
import AuthenticationAPI
import APIClient
import FirebaseCore

@main
struct MyApp: App {
    @State private var store: AuthenticationStore

    init() {
        FirebaseConfigurator.configure()   // 本番。エミュレータは .configure(environment: .emulator())

        let tokenProvider = FirebaseTokenProvider()
        let apiClient = APIClient(
            baseURL: URL(string: "https://api.example.com")!,
            authTokenProvider: APITokenProviderAdapter(tokenProvider)
        )

        let clientID = FirebaseConfigurator.googleClientID ?? ""

        _store = State(initialValue: AuthenticationStore(
            authenticator: FirebaseAuthenticator(),
            postAuthentication: APIUserProvisioning(apiClient: apiClient, path: "/auth/initialize"),
            credentialProviders: [
                AppleCredentialProvider(),
                GoogleCredentialProvider(clientID: clientID)
            ]
        ))
    }

    var body: some Scene {
        WindowGroup {
            AuthenticatedRootView(
                loading: { ProgressView() },
                unauthenticated: {
                    VStack(spacing: 16) {
                        GoogleSignInButton()
                        AppleSignInButton()
                    }
                    .padding(.horizontal, 32)
                },
                error: { error in Text(error.localizedDescription) },
                authenticated: { user in MainView(userID: user.id) }
            )
            .authenticationStore(store)
        }
    }
}
```

### 2. 画面（プレビュー可能・ベンダー非依存）

```swift
import SwiftUI
import Authentication
import AuthenticationUI

struct MainView: View {
    @Environment(\.authenticationStore) private var store
    let userID: String

    var body: some View {
        VStack {
            Text("ようこそ \(userID)")
            Button("サインアウト") { Task { try? await store?.signOut() } }
        }
    }
}

#Preview {
    // Firebase 不要。スタブで生成。
    MainView(userID: "preview")
        .authenticationStore(.previewUnauthenticated)
}
```

### 状態

`AuthenticationState`:

- `.checking` — 確認中
- `.unauthenticated` — 未認証
- `.authenticatedPendingProvisioning` — 交換済み・ログイン後処理待ち
- `.authenticated(AuthUser)` — 完全に認証済み
- `.error(any Error)` — エラー

## バックエンド API（任意）

`APIUserProvisioning` を使う場合、`POST <path>`（既定 `/auth/initialize`）を用意する。
Firebase ID トークンが `Authorization: Bearer` で自動付与される。プロビジョニングは
認証セッション中に **1 回だけ** 呼ばれるが、サーバ側でも冪等にすること。
プロビジョニング不要なら `postAuthentication` を省略（`NoPostAuthentication`）できる。

## 独自プロバイダ

`AuthProviderID` は拡張可能で、`CredentialProvider` / `Authenticator` /
`PostAuthenticationAction` を実装すれば任意のバックエンド（Firestore 直叩き、独自 OIDC 等）を
差し込める。

## ライセンス

MIT License. 詳細は [LICENSE](LICENSE) を参照。
