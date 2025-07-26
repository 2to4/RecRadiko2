//
//  BasicIntegrationTests.swift
//  RecRadiko2Tests
//
//  Created by Claude on 2025/07/26.
//

import XCTest
import Foundation
@testable import RecRadiko2

/// 基本的な統合テスト（最小限のテストから開始）
class BasicIntegrationTests: XCTestCase {
    
    /// 基本的なコンポーネント初期化テスト
    func testBasicComponentInitialization() {
        // Given & When: 基本コンポーネントの初期化
        let httpClient = HTTPClient()
        let xmlParser = RadikoXMLParser()
        
        // Then: 初期化が成功すること
        XCTAssertNotNil(httpClient)
        XCTAssertNotNil(xmlParser)
    }
    
    /// XMLパーサーの基本機能テスト
    func testXMLParserBasicFunctionality() throws {
        // Given: XMLパーサーとシンプルなテストデータ
        let xmlParser = RadikoXMLParser()
        
        let simpleStationXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <stations area_id="JP13">
            <station id="TEST" area_id="JP13">
                <name>テスト放送局</name>
                <ascii_name>TEST STATION</ascii_name>
            </station>
        </stations>
        """
        
        // When: XMLパース実行
        let xmlData = simpleStationXML.data(using: .utf8)!
        let stations = try xmlParser.parseStationList(from: xmlData)
        
        // Then: パースが成功し、期待通りのデータが取得できること
        XCTAssertEqual(stations.count, 1)
        XCTAssertEqual(stations[0].id, "TEST")
        XCTAssertEqual(stations[0].name, "テスト放送局")
        XCTAssertEqual(stations[0].areaId, "JP13")
    }
    
    /// TimeConverterの基本機能テスト
    func testTimeConverterBasicFunctionality() {
        // Given: TimeConverterとテスト用時刻文字列
        let testTimeString = "20250726220000"
        
        // When: 時刻変換実行
        let parsedDate = TimeConverter.parseRadikoTime(testTimeString)
        
        // Then: 変換が成功すること
        XCTAssertNotNil(parsedDate)
        
        // 変換された日付の妥当性確認
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: parsedDate!)
        
        XCTAssertEqual(components.year, 2025)
        XCTAssertEqual(components.month, 7)
        XCTAssertEqual(components.day, 26)
        XCTAssertEqual(components.hour, 22)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(components.second, 0)
    }
    
    /// AuthInfoの基本機能テスト
    func testAuthInfoBasicFunctionality() {
        // Given: AuthInfo作成
        let authInfo = AuthInfo.create(
            authToken: "test_token_12345",
            areaId: "JP13",
            areaName: "東京都"
        )
        
        // Then: 作成が成功し、期待通りの値が設定されていること
        XCTAssertEqual(authInfo.authToken, "test_token_12345")
        XCTAssertEqual(authInfo.areaId, "JP13")
        XCTAssertEqual(authInfo.areaName, "東京都")
        XCTAssertTrue(authInfo.isValid)
        
        // 有効期限の確認
        XCTAssertTrue(authInfo.expiresAt > Date())
    }
}