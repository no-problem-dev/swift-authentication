# ``AuthenticationGoogle``

Google Sign-In の資格情報取得と URL ハンドリングを担う ``Authentication/CredentialProvider`` 実装。

## Overview

`AuthenticationGoogle` は GoogleSignIn SDK を用いてサインインフローを起動し、
ID トークンとアクセストークンを取得して vendor 非依存な ``Authentication/AuthCredential`` を生成します。
`clientID` は合成ルートから注入します（FirebaseCore に直接依存せず取得するため、
`AuthenticationFirebase` の `FirebaseConfigurator.googleClientID` を使うのが標準パターンです）。

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

Google Sign-In はリダイレクト URL を受け取る必要があります。
アプリの `onOpenURL` で ``GoogleURLHandler/handle(_:)`` を呼んでください。

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
