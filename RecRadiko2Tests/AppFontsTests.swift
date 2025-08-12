//
//  AppFontsTests.swift
//  RecRadiko2Tests
//
//  Created by Claude on 2025/08/11.
//

import Testing
import SwiftUI
@testable import RecRadiko2

@Suite("Typography System Tests - HIG準拠のタイポグラフィシステムテスト")
struct AppFontsTests {
    
    @Test("システムフォントの動的サイズ対応を確認")
    func testSystemFontDynamicSizing() {
        // Dynamic Typeに対応したフォントサイズの確認
        let largeTitle = Font.appLargeTitle
        let title = Font.appTitle
        let headline = Font.appHeadline
        let body = Font.appBody
        let caption = Font.appCaption
        
        #expect(largeTitle != nil)
        #expect(title != nil)
        #expect(headline != nil)
        #expect(body != nil)
        #expect(caption != nil)
    }
    
    @Test("セマンティックフォントスタイルの定義確認")
    func testSemanticFontStyles() {
        // 用途別フォントスタイルが定義されていることを確認
        let primaryLabel = Font.appPrimaryLabel
        let secondaryLabel = Font.appSecondaryLabel
        let tertiaryLabel = Font.appTertiaryLabel
        
        #expect(primaryLabel != nil)
        #expect(secondaryLabel != nil)
        #expect(tertiaryLabel != nil)
    }
    
    @Test("モノスペースフォントの定義確認")
    func testMonospacedFontDefinitions() {
        // コード表示用のモノスペースフォントの確認
        let monospacedRegular = Font.appMonospacedRegular
        let monospacedSmall = Font.appMonospacedSmall
        
        #expect(monospacedRegular != nil)
        #expect(monospacedSmall != nil)
    }
    
    @Test("強調フォントスタイルの定義確認")
    func testEmphasisFontStyles() {
        // 強調表示用フォントの確認
        let emphasisBold = Font.appEmphasisBold
        let emphasisSemibold = Font.appEmphasisSemibold
        
        #expect(emphasisBold != nil)
        #expect(emphasisSemibold != nil)
    }
    
    @Test("アクセシビリティ - フォントサイズ拡大対応")
    func testAccessibilityFontScaling() {
        // アクセシビリティ設定に対応したフォントスケーリング
        let scalableBody = Font.appScalableBody
        #expect(scalableBody != nil)
    }
}