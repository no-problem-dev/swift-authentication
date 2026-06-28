# ``AuthenticationGoogle``

Google Sign-In の資格情報取得と URL ハンドリングを担う ``Authentication/CredentialProvider`` 実装。

## Overview

`AuthenticationGoogle` は GoogleSignIn SDK を用いてサインインフローを起動し、
ID トークンとアクセストークンを取得して vendor 非依存な ``Authentication/AuthCredential`` を生成する。
`clientID` は合成ルートから注入する（FirebaseCore に直接依存せず取得するため、
`AuthenticationFirebase` の `FirebaseConfigurator.googleClientID` を使うのが標準パターン）。

```swift
import Authentication
import AuthenticationGoogle
import AuthenticationFirebase

// 合成ルートでの組み立て例
// "YOUR_GOOGLE_CLIENT_ID" はダミー — 実際には GoogleService-Info.plist の値を使用
let clientID = FirebaseConfigurator.googleClientID ?? "YOUR_GOOGLE_CLIENT_ID"
let store = AuthenticationStore(
    authenticator: FirebaseAuthenticator(),
    credentialProviders: [
        GoogleCredentialProvider(clientID: clientID)
    ]
)
```

Google Sign-In はリダイレクト URL を受け取る必要がある。
アプリの `onOpenURL` で ``GoogleURLHandler/handle(_:)`` を呼ぶ。

```swift
.onOpenURL { url in
    GoogleURLHandler.handle(url)
}
```

## Topics

### 資格情報プロバイダ

- ``GoogleCredentialProvider``

### URL ハンドリング

- ``GoogleURLHandler``
