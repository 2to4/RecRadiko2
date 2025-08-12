//
//  ButtonStylesTests.swift
//  RecRadiko2Tests
//
//  Created by Claude on 2025/08/11.
//

import Testing
import SwiftUI
@testable import RecRadiko2

@Suite("Button Styles Tests - HIG準拠のボタンスタイルテスト")
struct ButtonStylesTests {
    
    @Test("プライマリボタンスタイルの定義確認")
    func testPrimaryButtonStyle() {
        // プライマリアクション用ボタンスタイルの確認
        let primaryStyle = PrimaryButtonStyle()
        #expect(primaryStyle != nil)
    }
    
    @Test("セカンダリボタンスタイルの定義確認")
    func testSecondaryButtonStyle() {
        // セカンダリアクション用ボタンスタイルの確認
        let secondaryStyle = SecondaryButtonStyle()
        #expect(secondaryStyle != nil)
    }
    
    @Test("破壊的操作ボタンスタイルの定義確認")
    func testDestructiveButtonStyle() {
        // 削除・キャンセル等の破壊的操作用ボタンスタイルの確認
        let destructiveStyle = DestructiveButtonStyle()
        #expect(destructiveStyle != nil)
    }
    
    @Test("ボーダーレスボタンスタイルの定義確認")
    func testBorderlessButtonStyle() {
        // テキストリンク風ボタンスタイルの確認
        let borderlessStyle = RecRadiko2.BorderlessButtonStyle()
        #expect(borderlessStyle != nil)
    }
    
    @Test("ツールバーボタンスタイルの定義確認")
    func testToolbarButtonStyle() {
        // ツールバー用ボタンスタイルの確認
        let toolbarStyle = ToolbarButtonStyle()
        #expect(toolbarStyle != nil)
    }
}