# RecRadiko2 プロジェクト構造

## ディレクトリ構成
```
RecRadiko2/
├── RecRadiko2.xcodeproj/         # Xcodeプロジェクト設定
│   ├── project.pbxproj           # プロジェクト定義ファイル
│   ├── project.xcworkspace/      # ワークスペース設定
│   └── xcshareddata/             # 共有設定
│
├── RecRadiko2/                   # メインアプリケーションソース
│   ├── RecRadiko2App.swift       # @mainアプリエントリーポイント
│   ├── ContentView.swift         # メインUI画面
│   ├── Assets.xcassets/          # 画像、カラー、アプリアイコン
│   ├── RecRadiko2.entitlements   # アプリサンドボックス権限
│   │
│   ├── Models/                   # データモデル
│   │   ├── RadioStation.swift    # 放送局情報
│   │   ├── RadioProgram.swift    # 番組情報
│   │   ├── AuthInfo.swift        # 認証情報
│   │   └── Area.swift            # エリア情報
│   │
│   ├── Views/                    # SwiftUIビュー
│   │   ├── ContentView.swift     # メインビュー
│   │   ├── StationListView.swift # 放送局一覧
│   │   ├── ProgramScheduleView.swift # 番組表
│   │   ├── RecordingProgressView.swift # 録音進捗
│   │   ├── SettingsView.swift    # 設定画面
│   │   └── Components/           # 再利用可能なUIコンポーネント
│   │
│   ├── ViewModels/               # ビューモデル（MVVM）
│   │   ├── BaseViewModel.swift   # 基底ビューモデル
│   │   ├── StationListViewModel.swift
│   │   ├── ProgramScheduleViewModel.swift
│   │   ├── RecordingViewModel.swift
│   │   ├── ProgramListViewModel.swift
│   │   └── SettingsViewModel.swift
│   │
│   ├── Services/                 # サービス層
│   │   ├── RadikoAPIService.swift # Radiko API通信
│   │   ├── RadikoAuthService.swift # 認証処理
│   │   ├── RecordingManager.swift # 録音管理
│   │   ├── StreamingDownloader.swift # ストリーミングダウンロード
│   │   ├── HTTPClient.swift      # HTTPクライアントプロトコル
│   │   ├── RealHTTPClient.swift  # 実HTTPクライアント実装
│   │   ├── M3U8Parser.swift      # M3U8プレイリスト解析
│   │   ├── RadikoXMLParser.swift # XML解析
│   │   ├── CacheService.swift    # キャッシュ管理
│   │   ├── KeyboardShortcutManager.swift # キーボードショートカット
│   │   ├── AccessibilityManager.swift # アクセシビリティ
│   │   ├── ErrorRecoveryManager.swift # エラーリカバリー
│   │   ├── PerformanceAnalyzer.swift # パフォーマンス分析
│   │   ├── RadikoAPIError.swift  # APIエラー定義
│   │   ├── RecordingError.swift  # 録音エラー定義
│   │   └── UserDefaultsProtocol.swift # UserDefaultsプロトコル
│   │
│   ├── Protocols/                # プロトコル定義
│   │
│   └── Utilities/                # ユーティリティ
│
├── RecRadiko2Tests/              # ユニットテスト（Swift Testing）
│
├── RecRadiko2UITests/            # UIテスト（XCTest）
│
├── docs/                         # ドキュメント
│
├── CLAUDE.md                     # Claude Code用ガイドライン
├── .gitignore                    # Git除外設定
├── .mcp.json                     # MCP設定
├── TestRadikoAPI.swift           # API検証用スクリプト
└── DebugTest.swift               # デバッグ用スクリプト
```

## アーキテクチャ
- **パターン**: MVVM（Model-View-ViewModel）
- **View**: SwiftUIビュー
- **ViewModel**: ビジネスロジックとView状態管理
- **Model**: データ構造定義
- **Service**: 外部API通信、データ永続化等