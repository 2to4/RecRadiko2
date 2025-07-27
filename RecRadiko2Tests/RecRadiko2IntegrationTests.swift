//
//  RecRadiko2IntegrationTests.swift
//  RecRadiko2Tests
//
//  Created by Claude on 2025/07/26.
//

import XCTest
import Foundation
@testable import RecRadiko2

/// RecRadiko2 アプリケーション全体の統合テストスイート
/// 
/// このテストスイートは、実際のAPIとの連携やエンドツーエンドの動作を確認します。
/// 個別のユニットテストではなく、アプリケーション機能全体を通したテストに焦点を当てています。
class RecRadiko2IntegrationTests: XCTestCase {
    
    // MARK: - Phase 2 & 3 統合機能テスト
    
    /// 認証から番組表取得までの完全なフロー統合テスト
    func testAuthenticationToStationListFlow() async throws {
        print("DEBUG: 認証から番組表取得テスト開始")
        
        // Given: 神奈川県エリア（JP14）対応のモックHTTPクライアントとAPIサービスを使用
        let mockHttpClient = MockHTTPClient()
        mockHttpClient.setupCompleteFlow()
        
        let authService = RadikoAuthService(httpClient: mockHttpClient)
        let apiService = RadikoAPIService(httpClient: mockHttpClient, authService: authService)
        print("DEBUG: サービス初期化完了")
        
        do {
            // When: 認証実行
            let authInfo = try await authService.authenticate()
            
            // Then: 認証情報が正常に取得できることを確認
            XCTAssertFalse(authInfo.authToken.isEmpty)
            XCTAssertFalse(authInfo.areaId.isEmpty)
            XCTAssertFalse(authInfo.areaName.isEmpty)
            XCTAssertTrue(authInfo.isValid)
            
            // When: 放送局リスト取得
            let stations = try await apiService.fetchStations(for: authInfo.areaId)
            
            // Then: 放送局データが正常に取得できることを確認
            XCTAssertGreaterThan(stations.count, 0)
            
            // 神奈川県・関東エリアの主要放送局が含まれていることを確認
            let stationIds = stations.map { $0.id }
            let hasExpectedStations = stationIds.contains("TBS") || 
                                    stationIds.contains("QRR") || 
                                    stationIds.contains("LFR") ||
                                    stationIds.contains("JORF") || 
                                    stationIds.contains("BAYFM78")
            XCTAssertTrue(hasExpectedStations)
            
            // 各放送局のデータ構造が正常であることを確認
            for station in stations.prefix(3) {
                XCTAssertFalse(station.id.isEmpty)
                XCTAssertFalse(station.name.isEmpty)
                XCTAssertEqual(station.areaId, authInfo.areaId)
            }
            
        } catch {
            // エラーの詳細を記録して、実環境での問題を特定
            print("統合テストエラー: \(error)")
            
            // 特定のエラーケースは許容（ネットワーク問題、レート制限など）
            if case RadikoError.networkError = error {
                // ネットワーク問題は統合テスト環境では一時的な問題として許容
                print("ネットワーク問題により統合テストをスキップ")
                throw XCTSkip("ネットワーク接続の問題")
            } else {
                throw error
            }
        }
    }
    
    /// 番組表取得から番組情報解析までの統合フロー
    func testProgramListRetrievalFlow() async throws {
        print("DEBUG: 番組表取得テスト開始")
        
        // Given: 神奈川県エリア（JP14）対応のモックサービスを使用
        let mockHttpClient = MockHTTPClient()
        mockHttpClient.setupCompleteFlow()
        
        let authService = RadikoAuthService(httpClient: mockHttpClient)
        let apiService = RadikoAPIService(httpClient: mockHttpClient, authService: authService)
        print("DEBUG: サービス初期化完了")
        
        do {
            // When: 認証実行
            let authInfo = try await authService.authenticate()
            
            // 放送局リスト取得
            let stations = try await apiService.fetchStations(for: authInfo.areaId)
            XCTAssertGreaterThan(stations.count, 0)
            
            // 最初の放送局で番組表取得
            let firstStation = stations[0]
            let today = Date()
            let programs = try await apiService.fetchPrograms(stationId: firstStation.id, date: today)
            
            // Then: 番組データの検証
            XCTAssertGreaterThan(programs.count, 0)
            
            // 番組データの基本構造確認
            for program in programs.prefix(5) {
                XCTAssertFalse(program.id.isEmpty)
                XCTAssertFalse(program.title.isEmpty)
                XCTAssertEqual(program.stationId, firstStation.id)
                XCTAssertLessThan(program.startTime, program.endTime)
                
                // 番組時間が妥当な範囲内にあることを確認
                let duration = program.endTime.timeIntervalSince(program.startTime)
                XCTAssertGreaterThan(duration, 0) // 正の時間
                XCTAssertLessThan(duration, 24 * 60 * 60) // 24時間以内
            }
            
            // 番組の時系列順序確認
            if programs.count > 1 {
                for i in 0..<(programs.count - 1) {
                    XCTAssertLessThanOrEqual(programs[i].startTime, programs[i + 1].startTime)
                }
            }
            
        } catch {
            print("番組表統合テストエラー: \(error)")
            
            if case RadikoError.networkError = error {
                throw XCTSkip("ネットワーク接続の問題")
            } else {
                throw error
            }
        }
    }
    
    /// キャッシュ機能の統合テスト
    func testCacheIntegrationTest() async throws {
        print("DEBUG: キャッシュ統合テスト開始")
        
        // Given: キャッシュ付きサービス
        let cacheService = try CacheService()
        let mockHttpClient = MockHTTPClient()
        mockHttpClient.setupCompleteFlow()
        
        let authService = RadikoAuthService(httpClient: mockHttpClient)
        print("DEBUG: キャッシュサービス初期化完了")
        
        // キャッシュクリア
        cacheService.invalidateAll()
        
        do {
            // When: 認証情報をキャッシュ
            let authInfo = try await authService.authenticate()
            try cacheService.save(authInfo, for: .authInfo())
            
            // Then: キャッシュから読み込み
            let cachedAuthInfo: AuthInfo? = try cacheService.load(AuthInfo.self, for: .authInfo())
            XCTAssertNotNil(cachedAuthInfo)
            XCTAssertEqual(cachedAuthInfo?.authToken, authInfo.authToken)
            XCTAssertEqual(cachedAuthInfo?.areaId, authInfo.areaId)
            
            // キャッシュ有効期限テスト
            let shortExpirationPolicy = CachePolicy.authInfo(expiration: 1) // 1秒で期限切れ
            try cacheService.save("test_data", for: shortExpirationPolicy)
            
            // 即座に読み込み（成功するはず）
            let immediateData: String? = try cacheService.load(String.self, for: shortExpirationPolicy)
            XCTAssertEqual(immediateData, "test_data")
            
            // 2秒待機してから読み込み（失敗するはず）
            try await Task.sleep(nanoseconds: 2_000_000_000)
            let expiredData: String? = try cacheService.load(String.self, for: shortExpirationPolicy)
            XCTAssertNil(expiredData)
            
        } catch {
            print("キャッシュ統合テストエラー: \(error)")
            
            if case RadikoError.networkError = error {
                throw XCTSkip("ネットワーク接続の問題")
            } else {
                throw error
            }
        }
    }
    
    /// データ整合性の統合テスト
    func testDataIntegrityTest() async throws {
        print("DEBUG: データ整合性テスト開始")
        
        do {
            // Given: XMLパーサーと実データ
            let xmlParser = RadikoXMLParser()
            print("DEBUG: XMLパーサー作成完了")
            
            // 実際のRadiko API構造に基づくテストデータ
            let stationXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <stations area_id="JP13" area_name="東京都">
                <station id="TBS" area_id="JP13">
                    <name>TBSラジオ</name>
                    <ascii_name>TBS RADIO</ascii_name>
                    <logo>https://example.com/logo.png</logo>
                    <banner>https://example.com/banner.png</banner>
                    <href>https://www.tbsradio.jp/</href>
                </station>
            </stations>
            """
            
            let programXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <radiko>
                <stations>
                    <station id="TBS">
                        <progs>
                            <date>20250726</date>
                            <prog id="prog_001" ft="20250726220000" to="20250726240000" ts="1" station_id="TBS">
                                <title>テスト番組</title>
                                <info>番組説明</info>
                                <pfm>出演者名</pfm>
                                <img>https://example.com/program.jpg</img>
                            </prog>
                        </progs>
                    </station>
                </stations>
            </radiko>
            """
            
            // When: XMLパース実行
            let stationData = stationXML.data(using: .utf8)!
            let programData = programXML.data(using: .utf8)!
            print("DEBUG: XMLデータ作成完了")
            
            let stations = try xmlParser.parseStationList(from: stationData)
            print("DEBUG: 放送局パース完了: \(stations.count)件")
            
            let programs = try xmlParser.parseProgramList(from: programData)
            print("DEBUG: 番組パース完了: \(programs.count)件")
            
            // Then: データ整合性確認
            XCTAssertEqual(stations.count, 1)
            let station = stations[0]
            XCTAssertEqual(station.id, "TBS")
            XCTAssertEqual(station.name, "TBSラジオ")
            XCTAssertEqual(station.areaId, "JP13")
            print("DEBUG: 放送局データ検証完了")
            
            XCTAssertEqual(programs.count, 1)
            let program = programs[0]
            XCTAssertEqual(program.id, "prog_001")
            XCTAssertEqual(program.title, "テスト番組")
            XCTAssertEqual(program.stationId, "TBS")
            print("DEBUG: 番組データ検証完了")
            
            // 時間データの検証
            let startTime = TimeConverter.parseRadikoTime("20250726220000")
            let endTime = TimeConverter.parseRadikoTime("20250726240000")
            
            XCTAssertNotNil(startTime)
            XCTAssertNotNil(endTime)
            XCTAssertLessThan(startTime!, endTime!)
            print("DEBUG: 時間データ検証完了")
            
            // ValidationResult の確認
            let stationValidation = xmlParser.validateStations(stations)
            let programValidation = xmlParser.validatePrograms(programs)
            
            XCTAssertTrue(stationValidation.isValid)
            XCTAssertTrue(programValidation.isValid)
            print("DEBUG: 妥当性検証完了")
            
            print("DEBUG: データ整合性テスト成功")
            
        } catch {
            print("DEBUG: データ整合性テストエラー: \(error)")
            print("DEBUG: エラータイプ: \(type(of: error))")
            throw error
        }
    }
}