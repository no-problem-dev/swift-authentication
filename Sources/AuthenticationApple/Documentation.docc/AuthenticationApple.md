# ``AuthenticationApple``

Sign in with Apple の資格情報取得を担う ``Authentication/CredentialProvider`` 実装。

## Overview

`AuthenticationApple` は `ASAuthorizationController` を起動し、
nonce のハッシュ処理（SHA256）と生 nonce の保持を正しく行いながら
vendor 非依存な ``Authentication/AuthCredential`` を生成する。
生成した資格情報は `AuthenticationFirebase` の `FirebaseAuthenticator` など、
``Authentication/Authenticator`` を実装した交換層に渡される。

```swift
import Authentication
import AuthenticationApple
import AuthenticationFirebase

// 合成ルートでの組み立て例（clientID・APIキー等はダミー）
let store = AuthenticationStore(
    authenticator: FirebaseAuthenticator(),
    credentialProviders: [
        AppleCredentialProvider()                        // 氏名・メールを要求（既定）
        // AppleCredentialProvider(requestedScopes: [.email])  // メールのみ要求する場合
    ]
)

// サインイン（AuthenticationUI の AppleSignInButton が内部で呼び出す）
try await store.signIn(using: .apple)
```

``Authentication/AuthCredential`` を手動で組み立てる場合は、
このモジュールが提供する `AuthCredential.apple(idToken:rawNonce:fullName:)` ファクトリを使用する。

## Topics

### 資格情報プロバイダ

- ``AppleCredentialProvider``

### ファクトリ拡張

- ``Authentication/AuthCredential/apple(idToken:rawNonce:fullName:)``
