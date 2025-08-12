//
//  AppColors.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/24.
//  Updated for HIG compliance on 2025/08/11.
//

import SwiftUI

/// アプリケーション共通カラーパレット - Apple HIG準拠
/// ライト/ダークモード自動対応、アクセシビリティ考慮
extension Color {
    // MARK: - Background Colors (ダイナミック対応)
    
    /// メイン背景色（システムの背景色に追従）
    static let appBackground = Color(NSColor.windowBackgroundColor)
    
    /// セカンダリ背景色（システムのセカンダリ背景色）
    static let appSecondaryBackground = Color(NSColor.controlBackgroundColor)
    
    /// UI要素背景色（コントロール用背景）
    static let appUIBackground = Color(NSColor.controlColor)
    
    /// 入力欄背景色（テキストフィールド背景）
    static let appInputBackground = Color(NSColor.textBackgroundColor)
    
    /// 選択状態背景色（選択時のハイライト）
    static let appSelectedBackground = Color(NSColor.selectedContentBackgroundColor)
    
    /// Material背景（ぼかし効果付き背景）
    static let appMaterialBackground = Color(NSColor.underPageBackgroundColor)
    
    // MARK: - Text Colors (アクセシビリティ対応)
    
    /// プライマリテキスト色（メインのラベル色）
    static let appPrimaryText = Color(NSColor.labelColor)
    
    /// セカンダリテキスト色（補助的なラベル色）
    static let appSecondaryText = Color(NSColor.secondaryLabelColor)
    
    /// ターシャリテキスト色（3次的なラベル色）
    static let appTertiaryText = Color(NSColor.tertiaryLabelColor)
    
    /// 無効状態テキスト色
    static let appDisabledText = Color(NSColor.disabledControlTextColor)
    
    /// プレースホルダーテキスト色
    static let appPlaceholderText = Color(NSColor.placeholderTextColor)
    
    // MARK: - Accent Colors (システムアクセント色対応)
    
    /// アクセント色（システム設定のアクセント色）
    static let appAccent = Color.accentColor
    
    /// 危険操作色（削除・キャンセル等）
    static let appDanger = Color(NSColor.systemRed)
    
    /// 成功色（完了・成功状態）
    static let appSuccess = Color(NSColor.systemGreen)
    
    /// 警告色（注意喚起）
    static let appWarning = Color(NSColor.systemOrange)
    
    /// 情報色（情報提示）
    static let appInfo = Color(NSColor.systemBlue)
    
    // MARK: - Border and Separator Colors
    
    /// 分割線色（セパレータ）
    static let appDivider = Color(NSColor.separatorColor)
    
    /// ボーダー色（枠線）
    static let appBorder = Color(NSColor.gridColor)
    
    /// フォーカスリング色
    static let appFocusRing = Color(NSColor.keyboardFocusIndicatorColor)
    
    // MARK: - Interactive State Colors
    
    /// ホバー状態の背景色
    static let appHoverBackground = Color(NSColor.selectedContentBackgroundColor).opacity(0.3)
    
    /// 押下状態の背景色
    static let appPressedBackground = Color(NSColor.selectedContentBackgroundColor).opacity(0.5)
    
    /// 無効状態の背景色
    static let appDisabledBackground = Color(NSColor.controlColor).opacity(0.5)
}