# ``Authentication``

vendor 非依存の認証抽象層 — プロトコル・モデル・ステートストアを提供するパッケージのコアモジュール。

## Overview

`Authentication` はサインインフローを **取得 → 交換 → ログイン後処理** の 3 層に分割し、
Firebase や Apple Sign In などの具体的な SDK に依存しないインターフェースを提供します。
アプリのほとんどのコードはこのモジュールにのみ依存し、SDK の詳細は別モジュールで注入します。

中核となるステートホルダは ``AuthenticationStore`` です。
`@Observable` な ``AuthenticationState`` を保持し、SwiftUI の View が認証状態に応じて画面を切り替えられます。

```swift
import Authentication

// 合成ルートで組み立て（具象は別モジュール）
let store = AuthenticationStore(
    authenticator: myAuthenticator,           // AuthenticationFirebase など
    postAuthentication: myPostAction,         // AuthenticationAPI など
    credentialProviders: [myAppleProvider, myGoogleProvider]
)

// サインイン（プロバイダ識別子で指定）
try await store.signIn(using: .apple)

// サインアウト
try await store.signOut()
```

``AuthenticationState`` は `.checking` → `.unauthenticated` → `.authenticatedPendingProvisioning` → `.authenticated(AuthUser)` の順に遷移します。
エラーが発生すると `.error(any Error)` に移行します。

### パッケージ構成

このパッケージは 6 つのモジュールで構成されています。アプリは合成ルートで必要な具象を組み合わせ、
ドメイン層は `Authentication` のみに依存させるアーキテクチャを想定しています。

- **Authentication**（このモジュール）: プロトコル・モデル・``AuthenticationStore`` を含むコア。ドメイン層はここにのみ依存します。
- **AuthenticationUI**: ``AuthenticatedRootView``・``AppleSignInButton``・``GoogleSignInButton`` など SwiftUI コンポーネントを提供します。
- **AuthenticationApple**: Sign in with Apple の資格情報取得を担う `AppleCredentialProvider` を提供します。
- **AuthenticationGoogle**: Google Sign-In の資格情報取得を担う `GoogleCredentialProvider` と URL ハンドリングの `GoogleURLHandler` を提供します。
- **AuthenticationFirebase**: Firebase Authentication によるセッション交換 `FirebaseAuthenticator` と ID トークン供給 `FirebaseTokenProvider`、初期化ユーティリティ `FirebaseConfigurator` を提供します。
- **AuthenticationAPI**: REST API を介したログイン後処理 `APIUserProvisioning` と、swift-api-client への橋渡し `APITokenProviderAdapter` を提供します。

## Topics

### ステートストア

- ``AuthenticationStore``

### プロトコル

- ``Authenticator``
- ``CredentialProvider``
- ``PostAuthenticationAction``
- ``AuthTokenProviding``

### 認証状態・ユーザー

- ``AuthenticationState``
- ``AuthUser``

### 資格情報・プロバイダ識別子

- ``AuthCredential``
- ``AuthProviderID``
- ``PersonName``

### ログイン後処理

- ``NoPostAuthentication``
- ``CompositePostAuthentication``

### エラー

- ``AuthError``
