//
//  RadikoAuthServiceXCTests.swift
//  RecRadiko2Tests
//
//  Created by Claude on 2025/07/26.
//

import XCTest
@testable import RecRadiko2

/// XCTest版のRadikoAuthServiceテスト（比較検証用）
class RadikoAuthServiceXCTests: XCTestCase {
    
    var authService: RadikoAuthService!
    var mockHTTPClient: MockHTTPClient!
    var testUserDefaults: TestUserDefaults!
    
    override func setUp() {
        super.setUp()
        mockHTTPClient = MockHTTPClient()
        testUserDefaults = TestUserDefaults()
        authService = RadikoAuthService(
            httpClient: mockHTTPClient,
            userDefaults: testUserDefaults
        )
    }
    
    override func tearDown() {
        authService.resetForTesting()
        mockHTTPClient.reset()
        testUserDefaults.clear()
        authService = nil
        mockHTTPClient = nil
        testUserDefaults = nil
        super.tearDown()
    }
    
    /// XCTest版: エリア制限エラーテスト
    func testAreaRestrictedError() async throws {
        // Given: クリーンな状態から開始
        authService.resetForTesting()
        mockHTTPClient.reset()
        testUserDefaults.clear()
        
        // エリア制限設定
        mockHTTPClient.setupAuth1Success()
        mockHTTPClient.setupAuth2AreaRestricted()
        
        // MockHTTPClientの設定確認
        // MockHTTPClient設定確認（privateプロパティのため直接アクセス不可）
        
        print("DEBUG: テスト開始 - MockHTTPClient設定完了")
        
        // When & Then: エリア制限エラーが発生することを確認
        do {
            print("DEBUG: 認証開始")
            let result = try await authService.authenticate()
            print("DEBUG: 予期しない成功: \(result)")
            XCTFail("エリア制限エラーが発生すべきでした")
        } catch {
            print("DEBUG: キャッチしたエラー: \(error)")
            print("DEBUG: エラータイプ: \(type(of: error))")
            
            if case RadikoError.areaRestricted = error {
                print("DEBUG: 期待通りのareaRestrictedエラー")
                // 期待通り
            } else {
                print("DEBUG: 予期しないエラータイプ")
                XCTFail("RadikoError.areaRestricted以外のエラーが発生しました: \(error)")
            }
        }
    }
    
    /// XCTest版: 認証状態確認テスト
    func testAuthenticationStatusCheck() async throws {
        // Given: モック設定
        mockHTTPClient.setupCompleteFlow()
        
        // 初期状態（未認証）
        XCTAssertFalse(authService.isAuthenticated())
        XCTAssertNil(authService.currentAuthInfo)
        
        // 認証実行
        let authInfo = try await authService.authenticate()
        
        // 認証後
        XCTAssertTrue(authService.isAuthenticated())
        XCTAssertNotNil(authService.currentAuthInfo)
        XCTAssertEqual(authService.currentAuthInfo?.authToken, authInfo.authToken)
    }
    
    /// XCTest版: 認証更新テスト
    func testRefreshAuthentication() async throws {
        // Given: 初回認証
        mockHTTPClient.setupCompleteFlow()
        let firstAuth = try await authService.authenticate()
        
        // When: 認証更新
        mockHTTPClient.reset()
        mockHTTPClient.setupCompleteFlow()
        let refreshedAuth = try await authService.refreshAuth()
        
        // Then: 新しい認証情報が取得されることを確認
        XCTAssertNotEqual(firstAuth.expiresAt, refreshedAuth.expiresAt)
        XCTAssertTrue(authService.isAuthenticated())
    }
}