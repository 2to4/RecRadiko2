//
//  RadikoAuthServiceTests.swift
//  RecRadiko2Tests
//
//  Created by Claude on 2025/07/25.
//

import Testing
import Foundation
@testable import RecRadiko2

// テスト環境での@MainActor除去のため、個別メソッドから@MainActorを削除

@Suite("RadikoAuthService Tests", .serialized)
struct RadikoAuthServiceTests {
    
    // MARK: - Test Utilities
    
    /// テスト専用AuthService作成
    private func createTestAuthService() -> (RadikoAuthService, MockHTTPClient, TestUserDefaults) {
        let mockHTTPClient = MockHTTPClient()
        let testUserDefaults = TestUserDefaults()
        let authService = RadikoAuthService(
            httpClient: mockHTTPClient,
            userDefaults: testUserDefaults
        )
        return (authService, mockHTTPClient, testUserDefaults)
    }
    
    /// 完全なクリーンアップ処理
    private func cleanup(authService: RadikoAuthService, mockClient: MockHTTPClient, userDefaults: TestUserDefaults) {
        authService.resetForTesting()
        mockClient.reset()
        userDefaults.clear()
    }
    
    // MARK: - 認証成功テスト
    
    @Test("認証成功 - auth1からauth2までの完全なフロー")
    func authenticateSuccess() async throws {
        // Given
        let (authService, mockHTTPClient, testUserDefaults) = createTestAuthService()
        defer { cleanup(authService: authService, mockClient: mockHTTPClient, userDefaults: testUserDefaults) }
        
        mockHTTPClient.setupAuth1Success()
        mockHTTPClient.setupAuth2Success()
        
        // When
        let authInfo = try await authService.authenticate()
        
        // Then
        let expectedToken = "test_auth_token_1234567890abcdef_padding_data".data(using: .utf8)!.base64EncodedString()
        #expect(authInfo.authToken == expectedToken)
        #expect(authInfo.areaId == "JP14")
        #expect(authInfo.areaName == "神奈川県")
        #expect(authInfo.isValid == true)
        #expect(authService.currentAuthInfo != nil)
        #expect(mockHTTPClient.auth1RequestCount == 1)
        #expect(mockHTTPClient.auth2RequestCount == 1)
    }
    
    @Test("キャッシュされた認証情報の使用")
    func useCachedAuthInfo() async throws {
        // Given
        let (firstAuthService, mockHTTPClient, testUserDefaults) = createTestAuthService()
        defer { cleanup(authService: firstAuthService, mockClient: mockHTTPClient, userDefaults: testUserDefaults) }
        
        // 有効な認証情報を事前に設定
        let cachedAuth = AuthInfo.create(
            authToken: "cached_token",
            areaId: "JP14",
            areaName: "神奈川県"
        )
        
        // TestUserDefaultsに保存（実際のキャッシュをシミュレート）
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(cachedAuth)
        testUserDefaults.set(data, forKey: "RadikoAuthInfo")
        
        // 新しいインスタンスを作成（キャッシュ読み込みをテスト）
        let newAuthService = RadikoAuthService(
            httpClient: mockHTTPClient,
            userDefaults: testUserDefaults
        )
        
        // When
        let authInfo = try await newAuthService.authenticate()
        
        // Then
        #expect(authInfo.authToken == "cached_token")
        #expect(mockHTTPClient.requestCount == 0) // HTTP呼び出しなし
    }
    
    @Test("期限切れキャッシュの再認証")
    func expiredCacheReauthentication() async throws {
        // Given
        let (authService, mockHTTPClient, testUserDefaults) = createTestAuthService()
        defer { cleanup(authService: authService, mockClient: mockHTTPClient, userDefaults: testUserDefaults) }
        
        mockHTTPClient.setupAuth1Success()
        mockHTTPClient.setupAuth2Success()
        
        // 期限切れの認証情報をキャッシュに保存
        let expiredAuth = AuthInfo(
            authToken: "expired_token",
            areaId: "JP14",
            areaName: "神奈川県",
            expiresAt: Date().addingTimeInterval(-3600) // 1時間前
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(expiredAuth)
        testUserDefaults.set(data, forKey: "RadikoAuthInfo")
        
        // 新しいインスタンスを作成
        let newAuthService = RadikoAuthService(httpClient: mockHTTPClient, userDefaults: testUserDefaults)
        
        // When
        let authInfo = try await newAuthService.authenticate()
        
        // Then
        #expect(authInfo.authToken != "expired_token")
        #expect(authInfo.isValid == true)
        #expect(mockHTTPClient.requestCount > 0) // 新しいHTTP呼び出しあり
    }
    
    // MARK: - パーシャルキー抽出テスト
    
    @Test("パーシャルキーの正確な抽出")
    func extractPartialKeyCorrectly() {
        // Given
        let (authService, mockHTTPClient, testUserDefaults) = createTestAuthService()
        defer { cleanup(authService: authService, mockClient: mockHTTPClient, userDefaults: testUserDefaults) }
        
        // テスト用のBase64エンコードされた認証トークン
        let testData = "abcdefghijklmnopqrstuvwxyz0123456789"
        let testToken = Data(testData.utf8).base64EncodedString()
        let offset = 8
        let length = 16
        
        // When
        let partialKey = authService.extractPartialKey(
            from: testToken,
            offset: offset,
            length: length
        )
        
        // Then
        #expect(partialKey.isEmpty == false)
        
        // 正しい部分が抽出されていることを確認
        let decodedToken = Data(base64Encoded: testToken)!
        let expectedRange = offset..<(offset + length)
        let expectedData = decodedToken.subdata(in: expectedRange)
        let expectedPartialKey = expectedData.base64EncodedString()
        
        #expect(partialKey == expectedPartialKey)
    }
    
    @Test("パーシャルキー抽出の境界値テスト")
    func extractPartialKeyBoundaryValues() {
        // Given
        let (authService, mockHTTPClient, testUserDefaults) = createTestAuthService()
        defer { cleanup(authService: authService, mockClient: mockHTTPClient, userDefaults: testUserDefaults) }
        
        let testToken = Data("test_token_data".utf8).base64EncodedString()
        
        // When & Then
        // 無効なオフセット
        #expect(authService.extractPartialKey(from: testToken, offset: -1, length: 8) == "")
        
        // 無効な長さ
        #expect(authService.extractPartialKey(from: testToken, offset: 0, length: -1) == "")
        #expect(authService.extractPartialKey(from: testToken, offset: 0, length: 0) == "")
        
        // 範囲外アクセス
        let tokenData = Data(base64Encoded: testToken)!
        let invalidOffset = tokenData.count
        #expect(authService.extractPartialKey(from: testToken, offset: invalidOffset, length: 8) == "")
        
        // 無効なBase64
        #expect(authService.extractPartialKey(from: "invalid_base64!", offset: 0, length: 8) == "")
    }
    
    // MARK: - エラーハンドリングテスト
    
    @Test("auth1通信失敗時のエラーハンドリング")
    func auth1NetworkError() async throws {
        // Given
        let (authService, mockHTTPClient, testUserDefaults) = createTestAuthService()
        defer { cleanup(authService: authService, mockClient: mockHTTPClient, userDefaults: testUserDefaults) }
        
        mockHTTPClient.setupNetworkError()
        
        // When & Then
        await #expect(throws: RadikoError.authenticationFailed) {
            try await authService.authenticate()
        }
        
        #expect(authService.currentAuthInfo == nil)
    }
    
    @Test("auth2通信失敗時のエラーハンドリング")
    func auth2NetworkError() async throws {
        // Given
        let (authService, mockHTTPClient, testUserDefaults) = createTestAuthService()
        defer { cleanup(authService: authService, mockClient: mockHTTPClient, userDefaults: testUserDefaults) }
        
        mockHTTPClient.setupAuth1Success()
        // auth2は失敗させる
        mockHTTPClient.setupNetworkError()
        
        // When & Then
        await #expect(throws: RadikoError.authenticationFailed) {
            try await authService.authenticate()
        }
    }
    
    @Test("地域制限エラーの処理")
    func areaRestrictedError() async throws {
        // Given
        let (authService, mockHTTPClient, testUserDefaults) = createTestAuthService()
        defer { cleanup(authService: authService, mockClient: mockHTTPClient, userDefaults: testUserDefaults) }
        
        // クリーンアップを確実に実行
        authService.resetForTesting()
        mockHTTPClient.reset()
        testUserDefaults.clear()
        
        mockHTTPClient.setupAuth1Success()
        mockHTTPClient.setupAuth2AreaRestricted()
        
        print("DEBUG: Swift Testing - テスト開始")
        
        // When & Then: エリア制限エラーが発生することを確認
        await #expect(throws: RadikoError.areaRestricted) {
            try await authService.authenticate()
        }
    }
    
    // MARK: - 認証更新テスト
    
    @Test("認証更新機能")
    func refreshAuthentication() async throws {
        // Given
        let (authService, mockHTTPClient, testUserDefaults) = createTestAuthService()
        defer { cleanup(authService: authService, mockClient: mockHTTPClient, userDefaults: testUserDefaults) }
        
        mockHTTPClient.setupAuth1Success()
        mockHTTPClient.setupAuth2Success()
        
        // 初回認証
        let firstAuth = try await authService.authenticate()
        let firstToken = firstAuth.authToken
        
        // When - 認証更新
        mockHTTPClient.resetRequestCount()
        let refreshedAuth = try await authService.refreshAuth()
        
        // Then
        let expectedToken = "test_auth_token_1234567890abcdef_padding_data".data(using: .utf8)!.base64EncodedString()
        #expect(refreshedAuth.authToken == expectedToken) // モックでは同じトークンが返される
        #expect(refreshedAuth.isValid == true)
        #expect(mockHTTPClient.requestCount > 0) // 新しいリクエストが発生
        #expect(authService.currentAuthInfo?.authToken == refreshedAuth.authToken)
    }
    
    // MARK: - 認証状態管理テスト
    
    @Test("認証状態の確認")
    func authenticationStatusCheck() async throws {
        // Given
        let (authService, mockHTTPClient, testUserDefaults) = createTestAuthService()
        defer { cleanup(authService: authService, mockClient: mockHTTPClient, userDefaults: testUserDefaults) }
        
        mockHTTPClient.setupAuth1Success()
        mockHTTPClient.setupAuth2Success()
        
        // 初期状態（未認証）
        #expect(authService.isAuthenticated() == false)
        #expect(authService.currentAuthInfo == nil)
        
        // 認証実行
        let authInfo = try await authService.authenticate()
        
        // 認証後
        #expect(authService.isAuthenticated() == true)
        #expect(authService.currentAuthInfo != nil)
        #expect(authService.currentAuthInfo?.authToken == authInfo.authToken)
    }
    
    @Test("認証ステータスの詳細情報")
    func detailedAuthStatus() async throws {
        // Given
        let (authService, mockHTTPClient, testUserDefaults) = createTestAuthService()
        defer { cleanup(authService: authService, mockClient: mockHTTPClient, userDefaults: testUserDefaults) }
        
        mockHTTPClient.setupAuth1Success()
        mockHTTPClient.setupAuth2Success()
        
        // 未認証状態
        var status = authService.authStatus
        if case .notAuthenticated = status {
            #expect(status.isUsable == false)
            #expect(status.authInfo == nil)
        } else {
            #expect(Bool(false), "Expected notAuthenticated status")
        }
        
        // 認証実行
        _ = try await authService.authenticate()
        
        // 認証済み状態
        status = authService.authStatus
        if case .authenticated(let authInfo) = status {
            #expect(status.isUsable == true)
            #expect(authInfo.isValid == true)
        } else {
            #expect(Bool(false), "Expected authenticated status")
        }
    }
    
    @Test("期限切れ認証の詳細ステータス")
    func expiredAuthDetailedStatus() async throws {
        // Given
        let (authService, mockHTTPClient, testUserDefaults) = createTestAuthService()
        defer { cleanup(authService: authService, mockClient: mockHTTPClient, userDefaults: testUserDefaults) }
        
        // 期限切れの認証情報を直接設定
        let expiredAuth = AuthInfo(
            authToken: "expired_token",
            areaId: "JP14",
            areaName: "神奈川県",
            expiresAt: Date().addingTimeInterval(-3600)
        )
        
        // TestUserDefaultsを通じて設定
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(expiredAuth)
        testUserDefaults.set(data, forKey: "RadikoAuthInfo")
        
        // 新しいインスタンスで期限切れキャッシュを読み込み
        let newAuthService = RadikoAuthService(httpClient: mockHTTPClient, userDefaults: testUserDefaults)
        
        // When
        let status = newAuthService.authStatus
        
        // Then
        #expect(status.isUsable == false)
        if case .notAuthenticated = status {
            // 期限切れキャッシュは自動的にクリアされるため未認証状態になる
            #expect(Bool(true))
        } else {
            #expect(Bool(false), "Expected notAuthenticated status for expired cache")
        }
    }
    
    // MARK: - キャッシュ管理テスト
    
    @Test("キャッシュの保存と読み込み")
    func cacheManagement() async throws {
        // Given
        let (authService, mockHTTPClient, testUserDefaults) = createTestAuthService()
        defer { cleanup(authService: authService, mockClient: mockHTTPClient, userDefaults: testUserDefaults) }
        
        mockHTTPClient.setupAuth1Success()
        mockHTTPClient.setupAuth2Success()
        
        // When - 認証実行（キャッシュに保存される）
        let authInfo = try await authService.authenticate()
        
        // 新しいインスタンスでキャッシュ読み込みを確認
        let newAuthService = RadikoAuthService(httpClient: mockHTTPClient, userDefaults: testUserDefaults)
        
        // Then
        #expect(newAuthService.currentAuthInfo?.authToken == authInfo.authToken)
        #expect(newAuthService.isAuthenticated() == true)
        
        // キャッシュクリア後の確認
        mockHTTPClient.reset()
        mockHTTPClient.setupAuth1Success()
        mockHTTPClient.setupAuth2Success()
        _ = try await newAuthService.refreshAuth()
        
        // refreshAuthはキャッシュをクリアしてから再認証する
        #expect(mockHTTPClient.requestCount > 0)
    }
    
    @Test("破損したキャッシュの処理")
    func corruptedCacheHandling() async throws {
        // Given
        let (authService, mockHTTPClient, testUserDefaults) = createTestAuthService()
        defer { cleanup(authService: authService, mockClient: mockHTTPClient, userDefaults: testUserDefaults) }
        
        mockHTTPClient.setupAuth1Success()
        mockHTTPClient.setupAuth2Success()
        
        // 破損したキャッシュデータを設定
        let corruptedData = "{ invalid json }".data(using: .utf8)!
        testUserDefaults.set(corruptedData, forKey: "RadikoAuthInfo")
        
        // When - 破損したキャッシュでも正常に認証できることを確認
        let authInfo = try await authService.authenticate()
        
        // Then
        #expect(authInfo.isValid == true)
        #expect(authService.isAuthenticated() == true)
    }
    
    // MARK: - 並行性テスト
    
    @Test("並行認証リクエストの処理")
    func concurrentAuthenticationRequests() async throws {
        // Given
        let (authService, mockHTTPClient, testUserDefaults) = createTestAuthService()
        defer { cleanup(authService: authService, mockClient: mockHTTPClient, userDefaults: testUserDefaults) }
        
        mockHTTPClient.setupAuth1Success()
        mockHTTPClient.setupAuth2Success()
        
        // When - 同時に複数の認証リクエストを実行
        async let auth1 = authService.authenticate()
        async let auth2 = authService.authenticate()
        async let auth3 = authService.authenticate()
        
        let results = try await [auth1, auth2, auth3]
        
        // Then - すべて同じ認証情報が返されることを確認
        #expect(results[0].authToken == results[1].authToken)
        #expect(results[1].authToken == results[2].authToken)
        #expect(results.allSatisfy { $0.isValid })
        
        // キャッシュが正しく機能していることを確認
        // 並行処理では最初の1つだけが実際の認証を行い、他はキャッシュを使用
        #expect(mockHTTPClient.auth1RequestCount == 1)
        #expect(mockHTTPClient.auth2RequestCount == 1)
    }
}