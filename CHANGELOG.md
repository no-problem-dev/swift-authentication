# Changelog

このプロジェクトのすべての重要な変更は、このファイルに記録されます。

このフォーマットは [Keep a Changelog](https://keepachangelog.com/ja/1.0.0/) に基づいており、
このプロジェクトは [Semantic Versioning](https://semver.org/lang/ja/) に準拠しています。

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
