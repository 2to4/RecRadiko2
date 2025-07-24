//
//  AppFonts.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/24.
//

import SwiftUI

/// アプリケーション共通フォント定義
extension Font {
    // MARK: - Typography Scale
    /// タイトルフォント
    static let appTitle = Font.title2
    
    /// 見出しフォント
    static let appHeadline = Font.headline
    
    /// 本文フォント
    static let appBody = Font.system(size: 14)
    
    /// キャプションフォント
    static let appCaption = Font.caption
    
    /// 等幅フォント（時刻表示用）
    static let appMonospaced = Font.system(size: 14, design: .monospaced)
    
    /// 大きな等幅フォント（経過時間表示用）
    static let appMonospacedLarge = Font.system(size: 18, weight: .medium, design: .monospaced)
    
    // MARK: - Size Variations
    /// 小さな本文フォント
    static let appBodySmall = Font.system(size: 12)
    
    /// 大きな見出しフォント
    static let appHeadlineLarge = Font.system(size: 18, weight: .semibold)
}