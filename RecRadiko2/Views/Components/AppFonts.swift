//
//  AppFonts.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/24.
//  Updated for HIG compliance on 2025/08/11.
//

import SwiftUI

/// アプリケーション共通フォント定義 - Apple HIG準拠
/// Dynamic Type対応、アクセシビリティ考慮
extension Font {
    // MARK: - Title Hierarchy (タイトル階層)
    
    /// 大見出し（画面タイトル等）
    static let appLargeTitle = Font.largeTitle
    
    /// タイトル（セクションタイトル等）
    static let appTitle = Font.title
    
    /// タイトル2（サブセクション等）
    static let appTitle2 = Font.title2
    
    /// タイトル3（小見出し等）
    static let appTitle3 = Font.title3
    
    // MARK: - Text Hierarchy (テキスト階層)
    
    /// 見出し（リスト項目のタイトル等）
    static let appHeadline = Font.headline
    
    /// サブ見出し（補助的な見出し）
    static let appSubheadline = Font.subheadline
    
    /// 本文（通常のテキスト）
    static let appBody = Font.body
    
    /// コールアウト（注目テキスト）
    static let appCallout = Font.callout
    
    /// 脚注（補足説明等）
    static let appFootnote = Font.footnote
    
    /// キャプション（画像説明等）
    static let appCaption = Font.caption
    
    /// キャプション2（より小さな説明文）
    static let appCaption2 = Font.caption2
    
    // MARK: - Semantic Labels (セマンティックラベル)
    
    /// プライマリラベル（メインのラベル）
    static let appPrimaryLabel = Font.body
    
    /// セカンダリラベル（補助的なラベル）
    static let appSecondaryLabel = Font.callout
    
    /// ターシャリラベル（3次的なラベル）
    static let appTertiaryLabel = Font.footnote
    
    // MARK: - Monospaced Fonts (等幅フォント)
    
    /// 標準等幅フォント（時刻・コード表示用）
    static let appMonospacedRegular = Font.system(.body, design: .monospaced)
    
    /// 小さな等幅フォント
    static let appMonospacedSmall = Font.system(.caption, design: .monospaced)
    
    /// 数字用等幅フォント（時間表示等）
    static let appMonospacedDigit = Font.system(.body, design: .monospaced)
        .monospacedDigit()
    
    // MARK: - Emphasis Styles (強調スタイル)
    
    /// 太字強調
    static let appEmphasisBold = Font.body.bold()
    
    /// セミボールド強調
    static let appEmphasisSemibold = Font.body.weight(.semibold)
    
    /// イタリック強調
    static let appEmphasisItalic = Font.body.italic()
    
    // MARK: - Special Purpose (特殊用途)
    
    /// タイマー・カウンター表示用
    static let appTimerDisplay = Font.system(size: 24, weight: .medium, design: .monospaced)
        .monospacedDigit()
    
    /// ボタンテキスト
    static let appButtonText = Font.body.weight(.medium)
    
    /// エラーメッセージ
    static let appErrorMessage = Font.callout.weight(.medium)
    
    /// 成功メッセージ
    static let appSuccessMessage = Font.callout.weight(.medium)
    
    // MARK: - Accessibility (アクセシビリティ対応)
    
    /// 動的サイズ対応の本文フォント
    static let appScalableBody = Font.custom("", size: 14, relativeTo: .body)
    
    /// 動的サイズ対応の見出しフォント
    static let appScalableHeadline = Font.custom("", size: 17, relativeTo: .headline)
    
    // MARK: - Rounded Design (丸みを帯びたデザイン)
    
    /// 丸みを帯びたタイトル
    static let appRoundedTitle = Font.system(.title, design: .rounded)
    
    /// 丸みを帯びた本文
    static let appRoundedBody = Font.system(.body, design: .rounded)
}