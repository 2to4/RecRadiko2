//
//  AppColors.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/24.
//

import SwiftUI

/// アプリケーション共通カラーパレット
extension Color {
    // MARK: - Background Colors
    /// メイン背景色（黒）
    static let appBackground = Color.black
    
    /// セカンダリ背景色（ダークグレー）
    static let appSecondaryBackground = Color(white: 0.15)
    
    /// UI要素背景色
    static let appUIBackground = Color(white: 0.2)
    
    /// 入力欄背景色
    static let appInputBackground = Color(white: 0.3)
    
    /// 選択状態背景色
    static let appSelectedBackground = Color(white: 0.25)
    
    // MARK: - Text Colors
    /// プライマリテキスト色（白）
    static let appPrimaryText = Color.white
    
    /// セカンダリテキスト色（グレー）
    static let appSecondaryText = Color.gray
    
    /// 無効状態テキスト色
    static let appDisabledText = Color(white: 0.5)
    
    // MARK: - Accent Colors
    /// アクセント色（青）
    static let appAccent = Color.blue
    
    /// 危険操作色（赤）
    static let appDanger = Color.red
    
    /// 成功色（緑）
    static let appSuccess = Color.green
    
    /// 警告色（オレンジ）
    static let appWarning = Color.orange
    
    // MARK: - Border Colors
    /// 分割線色
    static let appDivider = Color(white: 0.3)
    
    /// ボーダー色
    static let appBorder = Color(white: 0.4)
}