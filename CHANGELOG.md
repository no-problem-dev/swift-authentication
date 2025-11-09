# Changelog

このプロジェクトのすべての重要な変更は、このファイルに記録されます。

このフォーマットは [Keep a Changelog](https://keepachangelog.com/ja/1.0.0/) に基づいており、
このプロジェクトは [Semantic Versioning](https://semver.org/lang/ja/) に準拠しています。

## [未リリース]

なし

## [1.1.3] - 2025-11-09

### 修正
- 自動リリースワークフローのメッセージを完全に日本語に統一（PRディスクリプション、リリースノート、ログメッセージ）

## [1.1.2] - 2025-11-04

### 追加
- DocC ドキュメントの自動生成と GitHub Pages への公開機能を追加
  - Swift DocC Plugin を依存関係に追加
  - GitHub Actions ワークフローで自動的にドキュメントを生成・デプロイ
  - README に完全なドキュメントへのリンクを追加 (https://no-problem-dev.github.io/swift-authentication/documentation/authentication/)

### 変更
- ドキュメントへのアクセシビリティを向上

## [1.0.3] - 2025-02-11

### 追加
- README にバックエンド API 前提条件セクションを追加
  - 必須 POST `/auth/initialize` エンドポイントを文書化
  - 必須 JSON レスポンス形式を camelCase で明記
  - Firebase 認証とバックエンド統合の認証フローを説明
  - Authorization ヘッダーが自動的に Firebase ID トークンで設定されることを明記

## [1.0.2] - 2025-02-11

### 改善
- README を簡潔化し、重要な情報のみに絞る
  - トラブルシューティングセクションを削除（Google Sign-In、トークンリフレッシュ、ビルドエラー）
  - アーキテクチャセクションを削除（内部実装の詳細）
  - パッケージ利用者にとって必須の情報のみを保持

## [1.0.1] - 2025-02-11

### 改善
- README に包括的なセットアップガイドとバッジを追加
  - Swift 6.0、プラットフォーム、SPM、Firebase、ライセンスのバッジを追加
  - 包括的な前提条件セクションを追加（Firebase セットアップ、GoogleService-Info.plist、URL スキーム）
  - 4 ステップの実装ガイドを含むクイックスタートセクションを追加
  - 詳細なサインイン画面の実装例を追加
  - ユーザープロフィールへのアクセスとサインアウトの例を追加
  - カスタム認証フローの例を追加
  - FirebaseAuthTokenProvider を使用した API リクエスト統合の例を追加
  - 一般的な問題のトラブルシューティングセクションを追加
  - 内部構造の詳細を含むアーキテクチャセクションを拡張
  - LICENSE ファイルへの参照を追加

## [1.0.0] - 2024-12-XX

### 追加
- 初回リリース
- Firebase Authentication 統合
- Google Sign-In サポート
- モダンな async/await API
- SwiftUI Environment Values 対応
- 認証状態の管理
- iOS 17.0+ および macOS 14.0+ サポート

[未リリース]: https://github.com/no-problem-dev/swift-authentication/compare/v1.1.3...HEAD
[1.1.3]: https://github.com/no-problem-dev/swift-authentication/compare/v1.1.2...v1.1.3
[1.1.2]: https://github.com/no-problem-dev/swift-authentication/compare/v1.0.3...v1.1.2
