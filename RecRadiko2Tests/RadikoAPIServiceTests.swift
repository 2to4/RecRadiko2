//
//  RadikoAPIServiceTests.swift
//  RecRadiko2Tests
//
//  Created by Claude on 2025/07/26.
//

import Testing
import Foundation
@testable import RecRadiko2

/// RadikoAPIService統合テスト
@Suite("RadikoAPIService Tests", .serialized)
struct RadikoAPIServiceTests {
    
    // MARK: - Setup and Teardown
    
    /// テスト前処理：依存性注入を使用するため、shared UserDefaultsは使用しない
    init() {
        // テストは個別のTestUserDefaultsを使用するため、ここでの初期化は不要
    }
    
    // MARK: - Test Properties
    
    /// テスト用サービス作成
    func createTestService() -> (RadikoAPIService, MockHTTPClient, TestUserDefaults, RadikoAuthService) {
        let mockHTTPClient = MockHTTPClient()
        let testUserDefaults = TestUserDefaults()
        let authService = RadikoAuthService(httpClient: mockHTTPClient, userDefaults: testUserDefaults)
        let apiService = RadikoAPIService(
            httpClient: mockHTTPClient,
            authService: authService,
            userDefaults: testUserDefaults
        )
        return (apiService, mockHTTPClient, testUserDefaults, authService)
    }
    
    /// 完全なクリーンアップ処理
    private func cleanup(apiService: RadikoAPIService, mockClient: MockHTTPClient, userDefaults: TestUserDefaults, authService: RadikoAuthService) {
        authService.resetForTesting()
        mockClient.reset()
        userDefaults.clear()
    }
    
    // MARK: - 1.1 番組表取得機能テスト
    
    /// テスト: 番組表XML取得の成功パターン
    @Test("番組表XML取得の成功パターン")
    func testFetchProgramScheduleSuccess() async throws {
        // Given: テストサービスとモックHTTPクライアント
        let (apiService, mockHTTPClient, testUserDefaults, authService) = createTestService()
        defer { cleanup(apiService: apiService, mockClient: mockHTTPClient, userDefaults: testUserDefaults, authService: authService) }
        
        // モックレスポンス設定：認証とプログラムリストの両方を設定
        mockHTTPClient.setupCompleteFlow()
        
        // When: 番組表取得実行（当日の日付を使用）
        let today = Date()
        let programs = try await apiService.fetchPrograms(stationId: "TBS", date: today)
        
        // Then: 取得成功確認
        #expect(programs.count >= 1) // MockHTTPClientが返すプログラム数
        
        // 最初のプログラムの詳細確認
        let firstProgram = programs[0]
        #expect(!firstProgram.id.isEmpty)
        #expect(!firstProgram.title.isEmpty)
        #expect(firstProgram.stationId == "TBS")
    }
    
    /// テスト: 番組表XMLパース処理の正常系
    @Test("番組表XMLパース処理の正常系")
    func testParseProgramScheduleXMLSuccess() async throws {
        // Given: テストサービスとモックHTTPクライアント
        let (apiService, mockHTTPClient, testUserDefaults, authService) = createTestService()
        defer { cleanup(apiService: apiService, mockClient: mockHTTPClient, userDefaults: testUserDefaults, authService: authService) }
        
        // モックレスポンス設定
        mockHTTPClient.setupCompleteFlow()
        
        // When: 番組表取得実行
        let today = Date()
        let programs = try await apiService.fetchPrograms(stationId: "TBS", date: today)
        
        // Then: パース結果確認（MockHTTPClientのデフォルトデータを使用）
        #expect(programs.count >= 1)
        
        // 最初の番組の詳細確認
        let firstProgram = programs[0]
        #expect(!firstProgram.title.isEmpty)
        #expect(!firstProgram.personalities.isEmpty)
        #expect(firstProgram.stationId == "TBS")
    }
    
    /// テスト: ネットワークエラー時の処理
    @Test("ネットワークエラー時の処理")
    func testNetworkErrorHandling() async throws {
        // Given: テストサービスとエラーを発生させるモック
        let (apiService, mockHTTPClient, testUserDefaults, authService) = createTestService()
        defer { cleanup(apiService: apiService, mockClient: mockHTTPClient, userDefaults: testUserDefaults, authService: authService) }
        
        // ネットワークエラー設定
        mockHTTPClient.setupNetworkError()
        
        // When & Then: ネットワークエラーが適切に処理されることを確認
        do {
            let today = Date()
            _ = try await apiService.fetchPrograms(stationId: "TBS", date: today)
            #expect(Bool(false), "エラーが発生すべきでした")
        } catch let error as RadikoError {
            // ネットワークエラーまたは認証失敗エラーを許容
            switch error {
            case .networkError, .authenticationFailed:
                // 期待通り
                break
            default:
                #expect(Bool(false), "予期しないエラーが発生しました: \(error)")
            }
        } catch {
            #expect(Bool(false), "RadikoError以外のエラーが発生しました: \(error)")
        }
    }
    
    /// テスト: 放送局リスト取得の成功パターン
    @Test("放送局リスト取得の成功パターン")
    func testFetchStationsSuccess() async throws {
        // Given: テストサービスとモックHTTPクライアント
        let (apiService, mockHTTPClient, testUserDefaults, authService) = createTestService()
        defer { cleanup(apiService: apiService, mockClient: mockHTTPClient, userDefaults: testUserDefaults, authService: authService) }
        
        // モックレスポンス設定
        mockHTTPClient.setupCompleteFlow()
        
        // When: 放送局リスト取得実行（神奈川県エリア）
        let stations = try await apiService.fetchStations(for: "JP14")
        
        // Then: 取得成功確認
        #expect(stations.count >= 1)
        
        // 最初の放送局の詳細確認
        let firstStation = stations[0]
        #expect(!firstStation.id.isEmpty)
        #expect(!firstStation.name.isEmpty)
        #expect(firstStation.areaId == "JP14")
    }
}

// MARK: - Test Helper Extensions