# RecRadiko2 🎵

**macOS向けRadiko録音アプリケーション**

RecRadiko2は、日本のインターネットラジオサービス「Radiko」の番組録音を目的とした、高品質なmacOS SwiftUIアプリケーションです。

## ✨ 主要機能

### 🎧 高品質録音
- **MP3直接保存**: 再エンコーディングなしによるロスレス品質録音
- **ID3タグ対応**: Radikoストリームの自動解析・最適化処理
- **リアルタイム録音**: 番組進行中でも安定した録音継続

### 🔧 技術的特徴
- **SwiftUI**: モダンなmacOSネイティブインターフェース
- **Swift 5.0**: 型安全性と高パフォーマンスを両立
- **テスト駆動開発**: t_wada手法による高品質コード保証

## 🚀 システム要件

- **OS**: macOS 15.5以上
- **開発環境**: Xcode 16.4以上
- **アーキテクチャ**: Apple Silicon (ARM64) / Intel (x86_64)

## 📦 インストール・実行

### 開発者向けビルド

```bash
# プロジェクトクローン
git clone https://github.com/yourusername/RecRadiko2.git
cd RecRadiko2

# Debugビルド
xcodebuild -project RecRadiko2.xcodeproj -scheme RecRadiko2 -configuration Debug build

# アプリケーション実行
open build/Debug/RecRadiko2.app
```

### テスト実行

```bash
# 全テストスイート実行
xcodebuild test -project RecRadiko2.xcodeproj -scheme RecRadiko2 -destination 'platform=macOS'
```

## 🎯 録音機能アーキテクチャ

### 音声処理エンジン

| コンポーネント | 役割 | 特徴 |
|---------------|------|------|
| **ID3MediaParser** | ID3タグ付きMP3解析 | Radikoストリーム最適化対応 |
| **TSParser** | TSストリーム処理 | 将来のADTS AAC形式対応 |
| **RecordingManager** | 録音統合管理 | MP3直接保存・品質保証 |
| **AppLogger** | 高性能ログシステム | デバッグ・診断情報出力 |

### 品質保証

- ✅ **包括テストカバレッジ**: ID3解析・TSストリーム処理
- ✅ **TDDリファクタリング**: デッドコード除去（763行削減）
- ✅ **ロスレス録音**: 再エンコーディング廃止による音質保持
- ✅ **エラー回復**: ネットワーク異常・ストリーム中断対応

## 🛠️ 開発・貢献

### 開発ルール

1. **日本語ベース開発**: コミット・コメント・ドキュメントは日本語
2. **テスト駆動開発**: t_wadaのTDD手法厳守
3. **品質第一**: 全テスト成功維持でのコード変更

### 貢献方法

1. Issueで問題報告・機能要望
2. Fork & Pull Requestで改善提案
3. テストカバレッジ維持での開発参加

## 📄 ライセンス

このプロジェクトは[MITライセンス](LICENSE)の下で公開されています。

## 🔗 関連リンク

- [Radiko公式サイト](https://radiko.jp/)
- [Swift公式ドキュメント](https://swift.org/documentation/)
- [SwiftUIガイド](https://developer.apple.com/swiftui/)

---

**注意**: このアプリケーションはRadikoサービスの個人利用範囲での録音を目的としています。著作権法・利用規約を遵守してご利用ください。