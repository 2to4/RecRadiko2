//
//  RecRadiko2Tests.swift
//  RecRadiko2Tests
//
//  Created by 吉田太 on 2025/07/24.
//  Updated by Claude on 2025/07/25.
//

import Testing
import Foundation
@testable import RecRadiko2

enum NetworkError: Error {
    case connectionLost
}

/// Phase 2 API連携・データ管理の統合テスト
@Suite("RecRadiko2 Phase 2 Integration Tests")
struct RecRadiko2Tests {

    @Test("Phase 2 コンポーネント統合テスト")
    @MainActor
    func phase2IntegrationTest() async throws {
        // Given - Phase 2の主要コンポーネントが正常に初期化できることを確認
        let cacheService = try CacheService()
        let xmlParser = RadikoXMLParser()
        
        // When & Then - 各コンポーネントが正常に動作することを確認
        
        // 1. TimeConverterのテスト
        let testTimeString = "20250725220000"
        let parsedDate = TimeConverter.parseRadikoTime(testTimeString)
        #expect(parsedDate != nil)
        
        // 2. AuthInfoのテスト
        let authInfo = AuthInfo.create(authToken: "test_token", areaId: "JP13", areaName: "東京都")
        #expect(authInfo.isValid == true)
        
        // 3. CacheServiceのテスト
        let testData = ["integration_test_data"]
        try cacheService.save(testData, for: .stationList())
        let cachedData: [String]? = try cacheService.load([String].self, for: .stationList())
        #expect(cachedData == testData)
        
        // 4. XMLParserのテスト
        let xmlString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <stations area_id="JP13">
            <station id="TBS">
                <name>TBSラジオ</name>
                <ascii_name>TBS</ascii_name>
            </station>
        </stations>
        """
        let xmlData = xmlString.data(using: .utf8)!
        let stations = try xmlParser.parseStationList(from: xmlData)
        #expect(stations.count == 1)
        #expect(stations[0].id == "TBS")
        
        // クリーンアップ
        cacheService.invalidateAll()
    }
    
    @Test("Phase 2 エラーハンドリング統合テスト")
    func errorHandlingIntegrationTest() throws {
        // Given
        let cacheService = try CacheService()
        let xmlParser = RadikoXMLParser()
        
        // When & Then - エラーケースが適切に処理されることを確認
        
        // 1. 無効なXMLの処理
        let invalidXML = "invalid xml data".data(using: .utf8)!
        do {
            _ = try xmlParser.parseStationList(from: invalidXML)
            Issue.record("Expected ParsingError.invalidXML but no error was thrown")
        } catch {
            #expect(error is ParsingError)
        }
        
        // 2. 存在しないキャッシュの読み込み
        let nonExistentData: [String]? = try cacheService.load([String].self, for: .programList())
        #expect(nonExistentData == nil)
        
        // 3. HTTPErrorの種類確認
        let networkError = HTTPError.networkError(NetworkError.connectionLost)
        #expect(networkError.errorDescription?.contains("ネットワークエラー") == true)
        
        let unauthorizedError = HTTPError.unauthorized
        #expect(unauthorizedError.errorDescription == "認証に失敗しました")
        
        // 4. RadikoErrorの種類確認
        let authError = RadikoError.authenticationFailed
        #expect(authError.errorDescription?.contains("認証に失敗しました") == true)
        
        let areaError = RadikoError.areaRestricted
        #expect(areaError.recoverySuggestion?.contains("ラジコプレミアム") == true)
    }
}
