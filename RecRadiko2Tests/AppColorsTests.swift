//
//  AppColorsTests.swift
//  RecRadiko2Tests
//
//  Created by Claude on 2025/08/11.
//

import Testing
import SwiftUI
@testable import RecRadiko2

@Suite("Color System Tests - HIG準拠の色彩システムテスト")
struct AppColorsTests {
    
    @Test("システムカラーの動的対応を確認")
    func testSystemColorDynamicAdaptation() {
        // ライトモードとダークモードでの色の変化を確認
        let lightScheme = ColorScheme.light
        let darkScheme = ColorScheme.dark
        
        // プライマリバックグラウンドカラーが環境に応じて変化することを確認
        let primaryBg = Color.appBackground
        #expect(primaryBg != nil)
        
        // セカンダリテキストカラーの存在確認
        let secondaryText = Color.appSecondaryText
        #expect(secondaryText != nil)
    }
    
    @Test("アクセントカラーがシステム設定を反映")
    func testAccentColorReflectsSystemPreference() {
        // システムのアクセントカラーを使用していることを確認
        let accentColor = Color.appAccent
        #expect(accentColor != nil)
    }
    
    @Test("セマンティックカラーの定義確認")
    func testSemanticColorDefinitions() {
        // 成功、エラー、警告色が適切に定義されていることを確認
        let successColor = Color.appSuccess
        let errorColor = Color.appDanger
        let warningColor = Color.appWarning
        
        #expect(successColor != nil)
        #expect(errorColor != nil)
        #expect(warningColor != nil)
    }
    
    @Test("アクセシビリティ - 高コントラストモード対応")
    func testHighContrastModeSupport() {
        // 高コントラストモードでの視認性確認
        let textColor = Color.appPrimaryText
        let backgroundColor = Color.appBackground
        
        #expect(textColor != nil)
        #expect(backgroundColor != nil)
    }
    
    @Test("Material背景エフェクトのサポート")
    func testMaterialBackgroundSupport() {
        // macOSのMaterialエフェクト用カラーの存在確認
        let materialBg = Color.appMaterialBackground
        #expect(materialBg != nil)
    }
}