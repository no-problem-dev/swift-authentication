# ``AuthenticationAPI``

REST API を介したログイン後処理とトークンアダプターを提供するバックエンド連携モジュール。

## Overview

`AuthenticationAPI` は swift-api-client との橋渡しを担う 2 つの役割を提供します。

**1. ログイン後処理（ユーザープロビジョニング）**

``APIUserProvisioning`` は ``Authentication/PostAuthenticationAction`` を実装し、
認証成功後にバックエンドの初期化エンドポイント（既定 `POST /auth/initialize`）を呼びます。
``Authentication/AuthenticationStore`` はセッション中に同一ユーザーへ一度だけ呼び出します。

```swift
import Authentication
import AuthenticationAPI
import AuthenticationFirebase

// 合成ルートでの組み立て例
// apiClient は swift-api-client の APIExecutable 実装
let store = AuthenticationStore(
    authenticator: FirebaseAuthenticator(),
    postAuthentication: APIUserProvisioning(
        apiClient: myAPIClient,
        path: "/auth/initialize"      // エンドポイントパスをカスタマイズ可能
    )
)
```

**2. トークンアダプター**

``APITokenProviderAdapter`` は ``Authentication/AuthTokenProviding`` を
swift-api-client の `AuthTokenProvider` プロトコルに橋渡しします。
これにより `AuthenticationFirebase` の `FirebaseTokenProvider` を
APIClient に注入でき、`AuthenticationFirebase` は swift-api-client に依存しません。

```swift
import AuthenticationAPI
import AuthenticationFirebase

let tokenProvider = FirebaseTokenProvider()
let adapter = APITokenProviderAdapter(tokenProvider)
// adapter を swift-api-client のイニシャライザに渡す
```

## Topics

### ログイン後処理

- ``APIUserProvisioning``
- ``UserProvisioningContract``
- ``UserProvisioningResponse``

### トークンアダプター

- ``APITokenProviderAdapter``
