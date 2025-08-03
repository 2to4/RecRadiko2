# RecRadiko2 コーディング規約・スタイルガイド

## 基本ルール
- すべてのコメントは日本語で記述
- ファイルヘッダーにはSwiftの標準フォーマットを使用
- `// MARK: -` を使用してコードセクションを分割

## ファイルヘッダー例
```swift
//
//  FileName.swift
//  RecRadiko2
//
//  Created by [作成者名] on [日付].
//
```

## 命名規則
- **型名（クラス、構造体、列挙型）**: PascalCase（例: RadioStation）
- **変数・定数**: camelCase（例: displayName）
- **関数名**: camelCase（例: fetchStationList）
- **定数**: 小文字のcamelCase（例: defaultTimeout）

## 構造体・クラスの定義
```swift
/// モデルの説明（日本語）
struct ModelName: Identifiable, Hashable, Codable {
    let id: String          // プロパティの説明
    let name: String        // プロパティの説明
    
    init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}
```

## テスト用拡張
```swift
// MARK: - Test Extensions
#if DEBUG
extension ModelName {
    /// テスト用モックデータ
    static let mockData = ModelName(
        id: "test",
        name: "テストデータ"
    )
}
#endif
```

## プロトコル分離
- HTTPクライアントなどの外部依存はプロトコルで抽象化
- Mock実装とReal実装を分離
- プロトコル名は`~Protocol`で終わる

## エラーハンドリング
- カスタムエラー型を定義
- エラーケースは詳細に分類
- エラーメッセージは日本語で記述

## その他の規約
- SwiftLintは未導入だが、将来的に導入予定
- 厳格なコンパイラ警告を有効化
- Optional型は適切に処理