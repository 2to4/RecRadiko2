//
//  RadikoAuthServiceTests.swift
//  RecRadiko2Tests
//
//  Created by Claude on 2025/07/25.
//

import Testing
import Foundation
@testable import RecRadiko2

@Suite("RadikoAuthService Tests")
struct RadikoAuthServiceTests {
    
    // MARK: - 認証成功テスト
    
    @Test("認証成功 - auth1からauth2までの完全なフロー")
    @MainActor
    func authenticateSuccess() async throws {
        // Given
        let mockHTTPClient = MockHTTPClient()
        mockHTTPClient.setupAuth1Success()
        mockHTTPClient.setupAuth2Success()
        
        let authService = RadikoAuthService(httpClient: mockHTTPClient)
        
        // When
        let authInfo = try await authService.authenticate()
        
        // Then
        #expect(authInfo.authToken.isEmpty == false)
        #expect(authInfo.areaId == "JP13")
        #expect(authInfo.areaName == "東京都")
        #expect(authInfo.isValid == true)
        #expect(authService.currentAuthInfo != nil)
        #expect(mockHTTPClient.auth1RequestCount == 1)
        #expect(mockHTTPClient.auth2RequestCount == 1)
    }
    
    @Test("キャッシュされた認証情報の使用")
    @MainActor
    func useCachedAuthInfo() async throws {
        // Given
        let mockHTTPClient = MockHTTPClient()
        let authService = RadikoAuthService(httpClient: mockHTTPClient)
        
        // 有効な認証情報を事前に設定
        let cachedAuth = AuthInfo.create(
            authToken: "cached_token",
            areaId: "JP13",
            areaName: "東京都"
        )
        
        // UserDefaultsに直接保存（実際のキャッシュをシミュレート）
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(cachedAuth)
        UserDefaults.standard.set(data, forKey: "RadikoAuthInfo")
        
        // 新しいインスタンスを作成（キャッシュ読み込みをテスト）
        let newAuthService = RadikoAuthService(httpClient: mockHTTPClient)
        
        // When
        let authInfo = try await newAuthService.authenticate()
        
        // Then
        #expect(authInfo.authToken == "cached_token")
        #expect(mockHTTPClient.requestCount == 0) // HTTP呼び出しなし
        
        // クリーンアップ
        UserDefaults.standard.removeObject(forKey: "RadikoAuthInfo")
    }
    
    @Test("期限切れキャッシュの再認証")
    @MainActor
    func expiredCacheReauthentication() async throws {
        // Given
        let mockHTTPClient = MockHTTPClient()
        mockHTTPClient.setupAuth1Success()
        mockHTTPClient.setupAuth2Success()
        
        let authService = RadikoAuthService(httpClient: mockHTTPClient)
        
        // 期限切れの認証情報をキャッシュに保存
        let expiredAuth = AuthInfo(
            authToken: "expired_token",
            areaId: "JP13",
            areaName: "東京都",
            expiresAt: Date().addingTimeInterval(-3600) // 1時間前
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(expiredAuth)
        UserDefaults.standard.set(data, forKey: "RadikoAuthInfo")
        
        // 新しいインスタンスを作成
        let newAuthService = RadikoAuthService(httpClient: mockHTTPClient)
        
        // When
        let authInfo = try await newAuthService.authenticate()
        
        // Then
        #expect(authInfo.authToken != "expired_token")
        #expect(authInfo.isValid == true)
        #expect(mockHTTPClient.requestCount > 0) // 新しいHTTP呼び出しあり
        
        // クリーンアップ
        UserDefaults.standard.removeObject(forKey: "RadikoAuthInfo")
    }
    
    // MARK: - パーシャルキー抽出テスト
    
    @Test("パーシャルキーの正確な抽出")
    @MainActor
    func extractPartialKeyCorrectly() {
        // Given
        let authService = RadikoAuthService()
        
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
    @MainActor
    func extractPartialKeyBoundaryValues() {
        // Given
        let authService = RadikoAuthService()
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
    @MainActor
    func auth1NetworkError() async throws {
        // Given
        let mockHTTPClient = MockHTTPClient()
        mockHTTPClient.setupNetworkError()
        
        let authService = RadikoAuthService(httpClient: mockHTTPClient)
        
        // When & Then
        await #expect(throws: RadikoError.authenticationFailed) {
            try await authService.authenticate()
        }
        
        #expect(authService.currentAuthInfo == nil)
    }
    
    @Test("auth2通信失敗時のエラーハンドリング")
    @MainActor
    func auth2NetworkError() async throws {
        // Given
        let mockHTTPClient = MockHTTPClient()
        mockHTTPClient.setupAuth1Success()
        // auth2は失敗させる
        mockHTTPClient.setupNetworkError()
        
        let authService = RadikoAuthService(httpClient: mockHTTPClient)
        
        // When & Then
        await #expect(throws: RadikoError.authenticationFailed) {
            try await authService.authenticate()
        }
    }
    
    @Test("地域制限エラーの処理")
    @MainActor
    func areaRestrictedError() async throws {
        // Given
        let mockHTTPClient = MockHTTPClient()
        mockHTTPClient.setupAuth1Success()
        mockHTTPClient.setupAuth2AreaRestricted()
        
        let authService = RadikoAuthService(httpClient: mockHTTPClient)
        
        // When & Then
        await #expect(throws: RadikoError.areaRestricted) {
            try await authService.authenticate()
        }
    }
    
    // MARK: - 認証更新テスト
    
    @Test("認証更新機能")
    @MainActor
    func refreshAuthentication() async throws {
        // Given
        let mockHTTPClient = MockHTTPClient()
        mockHTTPClient.setupAuth1Success()
        mockHTTPClient.setupAuth2Success()
        
        let authService = RadikoAuthService(httpClient: mockHTTPClient)
        
        // 初回認証
        let firstAuth = try await authService.authenticate()
        let firstToken = firstAuth.authToken
        
        // When - 認証更新
        mockHTTPClient.resetRequestCount()
        let refreshedAuth = try await authService.refreshAuth()
        
        // Then
        #expect(refreshedAuth.authToken == firstToken) // モックでは同じトークンが返される
        #expect(refreshedAuth.isValid == true)
        #expect(mockHTTPClient.requestCount > 0) // 新しいリクエストが発生
        #expect(authService.currentAuthInfo?.authToken == refreshedAuth.authToken)
    }
    
    // MARK: - 認証状態管理テスト
    
    @Test("認証状態の確認")
    @MainActor
    func authenticationStatusCheck() async throws {
        // Given
        let mockHTTPClient = MockHTTPClient()
        mockHTTPClient.setupAuth1Success()
        mockHTTPClient.setupAuth2Success()
        
        let authService = RadikoAuthService(httpClient: mockHTTPClient)
        
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
    @MainActor
    func detailedAuthStatus() async throws {
        // Given
        let mockHTTPClient = MockHTTPClient()
        mockHTTPClient.setupAuth1Success()
        mockHTTPClient.setupAuth2Success()
        
        let authService = RadikoAuthService(httpClient: mockHTTPClient)
        
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
    @MainActor
    func expiredAuthDetailedStatus() async throws {
        // Given
        let mockHTTPClient = MockHTTPClient()
        let authService = RadikoAuthService(httpClient: mockHTTPClient)
        
        // 期限切れの認証情報を直接設定
        let expiredAuth = AuthInfo(
            authToken: "expired_token",
            areaId: "JP13",
            areaName: "東京都",
            expiresAt: Date().addingTimeInterval(-3600)
        )
        
        // プライベートプロパティに直接アクセスできないため、
        // UserDefaultsを通じて設定
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(expiredAuth)
        UserDefaults.standard.set(data, forKey: "RadikoAuthInfo")
        
        // 新しいインスタンスで期限切れキャッシュを読み込み
        let newAuthService = RadikoAuthService(httpClient: mockHTTPClient)
        
        // When
        let status = newAuthService.authStatus
        
        // Then
        #expect(status.isUsable == false)
        if case .notAuthenticated = status {
            // 期限切れキャッシュは自動的にクリアされるため未認証状態になる
            #expect(true)
        } else {
            #expect(Bool(false), "Expected notAuthenticated status for expired cache")
        }
        
        // クリーンアップ
        UserDefaults.standard.removeObject(forKey: "RadikoAuthInfo")
    }
    
    // MARK: - キャッシュ管理テスト
    
    @Test("キャッシュの保存と読み込み")
    @MainActor
    func cacheManagement() async throws {
        // Given
        let mockHTTPClient = MockHTTPClient()
        mockHTTPClient.setupAuth1Success()
        mockHTTPClient.setupAuth2Success()
        
        let authService = RadikoAuthService(httpClient: mockHTTPClient)
        
        // When - 認証実行（キャッシュに保存される）
        let authInfo = try await authService.authenticate()
        
        // 新しいインスタンスでキャッシュ読み込みを確認
        let newAuthService = RadikoAuthService(httpClient: mockHTTPClient)
        
        // Then
        #expect(newAuthService.currentAuthInfo?.authToken == authInfo.authToken)
        #expect(newAuthService.isAuthenticated() == true)
        
        // キャッシュクリア後の確認
        mockHTTPClient.reset()
        let refreshedAuth = try await newAuthService.refreshAuth()
        
        // refreshAuthはキャッシュをクリアしてから再認証する
        #expect(mockHTTPClient.requestCount > 0)
        
        // クリーンアップ
        UserDefaults.standard.removeObject(forKey: "RadikoAuthInfo")
    }
    
    @Test("破損したキャッシュの処理")
    @MainActor
    func corruptedCacheHandling() async throws {
        // Given
        let mockHTTPClient = MockHTTPClient()
        mockHTTPClient.setupAuth1Success()
        mockHTTPClient.setupAuth2Success()
        
        // 破損したキャッシュデータを設定
        let corruptedData = "{ invalid json }".data(using: .utf8)!
        UserDefaults.standard.set(corruptedData, forKey: "RadikoAuthInfo")
        
        let authService = RadikoAuthService(httpClient: mockHTTPClient)
        
        // When - 破損したキャッシュでも正常に認証できることを確認
        let authInfo = try await authService.authenticate()
        
        // Then
        #expect(authInfo.isValid == true)
        #expect(authService.isAuthenticated() == true)
        
        // クリーンアップ
        UserDefaults.standard.removeObject(forKey: "RadikoAuthInfo")
    }
    
    // MARK: - 並行性テスト
    
    @Test("並行認証リクエストの処理")
    @MainActor
    func concurrentAuthenticationRequests() async throws {
        // Given
        let mockHTTPClient = MockHTTPClient()
        mockHTTPClient.setupAuth1Success()
        mockHTTPClient.setupAuth2Success()
        
        let authService = RadikoAuthService(httpClient: mockHTTPClient)
        
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
        // 最初の認証以降はキャッシュから取得されるため、リクエスト数は最小限
        #expect(mockHTTPClient.requestCount >= 2) // auth1 + auth2の最小回数
    }
    
    // MARK: - テストのクリーンアップ
    
    func tearDown() {
        // 各テスト後にキャッシュをクリア
        UserDefaults.standard.removeObject(forKey: "RadikoAuthInfo")
    }
}