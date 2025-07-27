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
        <stations area_id="JP14">
            <station id="TEST" area_id="JP14">
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
        XCTAssertEqual(stations[0].areaId, "JP14")
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
            areaId: "JP14",
            areaName: "神奈川県"
        )
        
        // Then: 作成が成功し、期待通りの値が設定されていること
        XCTAssertEqual(authInfo.authToken, "test_token_12345")
        XCTAssertEqual(authInfo.areaId, "JP14")
        XCTAssertEqual(authInfo.areaName, "神奈川県")
        XCTAssertTrue(authInfo.isValid)
        
        // 有効期限の確認
        XCTAssertTrue(authInfo.expiresAt > Date())
    }
    
    /// 番組表XMLパースの基本機能テスト
    func testProgramListXMLParsing() throws {
        // Given: XMLパーサーとシンプルな番組表XML
        let xmlParser = RadikoXMLParser()
        
        let simpleProgramXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <radiko>
            <stations>
                <station id="TBS">
                    <name>TBSラジオ</name>
                    <progs>
                        <prog id="20250726220000" ft="20250726220000" to="20250727000000" station_id="TBS" ts="1">
                            <title>テスト番組</title>
                            <info>テスト番組の説明</info>
                            <pfm>テストパーソナリティ</pfm>
                        </prog>
                    </progs>
                </station>
            </stations>
        </radiko>
        """
        
        // When: XMLパース実行
        let xmlData = simpleProgramXML.data(using: .utf8)!
        let programs = try xmlParser.parseProgramList(from: xmlData)
        
        // Then: パースが成功し、期待通りのデータが取得できること
        XCTAssertEqual(programs.count, 1)
        XCTAssertEqual(programs[0].id, "20250726220000")
        XCTAssertEqual(programs[0].title, "テスト番組")
        XCTAssertEqual(programs[0].description, "テスト番組の説明")
        XCTAssertEqual(programs[0].personalities.first, "テストパーソナリティ")
        XCTAssertEqual(programs[0].stationId, "TBS")
    }
    
    /// 番組表ViewModelの基本動作テスト
    func testProgramScheduleViewModelBasicFunctionality() async throws {
        // Given: モックAPIサービスとViewModel
        class TestAPIService: RadikoAPIServiceProtocol {
            func fetchStations(for areaId: String) async throws -> [RadioStation] {
                return []
            }
            
            func fetchPrograms(stationId: String, date: Date) async throws -> [RadioProgram] {
                // テスト用番組データを返す
                return [
                    RadioProgram(
                        id: "test_prog_1",
                        title: "テスト番組1",
                        description: "説明1",
                        startTime: Date(),
                        endTime: Date().addingTimeInterval(3600),
                        personalities: ["パーソナリティ1"],
                        stationId: stationId
                    ),
                    RadioProgram(
                        id: "test_prog_2",
                        title: "テスト番組2",
                        description: "説明2",
                        startTime: Date().addingTimeInterval(3600),
                        endTime: Date().addingTimeInterval(7200),
                        personalities: ["パーソナリティ2"],
                        stationId: stationId
                    )
                ]
            }
        }
        
        let viewModel = await ProgramScheduleViewModel(apiService: TestAPIService())
        
        // When: 番組表読み込み
        await viewModel.loadPrograms(for: "TBS", date: Date())
        
        // Then: 番組が正しく読み込まれること
        let programs = await viewModel.programs
        XCTAssertEqual(programs.count, 2)
        XCTAssertEqual(programs[0].title, "テスト番組1")
        XCTAssertEqual(programs[1].title, "テスト番組2")
        
        // 読み込み状態が正しいこと
        let isLoading = await viewModel.isLoading
        XCTAssertFalse(isLoading)
        
        let error = await viewModel.error
        XCTAssertNil(error)
    }
    
    /// M3U8パーサーの基本機能テスト
    func testM3U8ParserBasicFunctionality() throws {
        // Given: M3U8パーサーとテストデータ
        let parser = M3U8Parser()
        let m3u8Content = """
        #EXTM3U
        #EXT-X-VERSION:3
        #EXT-X-TARGETDURATION:10
        #EXT-X-MEDIA-SEQUENCE:0
        #EXTINF:10.0,
        https://radiko.jp/segment0.aac
        #EXTINF:10.0,
        https://radiko.jp/segment1.aac
        """
        
        // When: M3U8解析実行
        let playlist = try parser.parse(m3u8Content)
        
        // Then: 解析結果が正しいこと
        XCTAssertEqual(playlist.version, 3)
        XCTAssertEqual(playlist.targetDuration, 10)
        XCTAssertEqual(playlist.segments.count, 2)
        XCTAssertEqual(playlist.segments[0].url, "https://radiko.jp/segment0.aac")
        XCTAssertEqual(playlist.segments[0].duration, 10.0)
    }
    
    /// StreamingDownloaderの基本機能テスト
    func testStreamingDownloaderBasicFunctionality() async throws {
        // Given: MockHTTPClientとStreamingDownloader
        let mockClient = MockHTTPClient()
        let testData = "AAC音声データ".data(using: .utf8)!
        mockClient.dataToReturn = testData
        
        let downloader = StreamingDownloader(httpClient: mockClient)
        
        // When: セグメントダウンロード実行
        let downloadedData = try await downloader.downloadSegment(from: "https://radiko.jp/segment0.aac")
        
        // Then: ダウンロードが成功すること
        XCTAssertEqual(downloadedData, testData)
        XCTAssertEqual(mockClient.requestCount, 1)
    }
    
    /// ストリーミングURL構築テスト
    func testStreamingURLConstruction() throws {
        // Given: StreamingDownloader
        let downloader = StreamingDownloader()
        
        // When: ストリーミングURL構築
        let url = try downloader.buildStreamingURL(
            stationId: "TBS",
            ft: "20250726220000",
            to: "20250727000000"
        )
        
        // Then: 正しいURLが構築されること
        XCTAssertTrue(url.contains("radiko.jp"))
        XCTAssertTrue(url.contains("TBS"))
        XCTAssertTrue(url.contains("20250726220000"))
        XCTAssertTrue(url.contains("20250727000000"))
    }
    
    /// RecordingManagerの基本機能テスト
    @MainActor 
    func testRecordingManagerBasicFunctionality() async throws {
        // Given: RecordingManager初期化
        let recordingManager = RecordingManager()
        
        // Then: 初期状態が正しいこと
        XCTAssertNotNil(recordingManager)
        XCTAssertNil(recordingManager.currentProgress)
        XCTAssertTrue(recordingManager.activeRecordings.isEmpty)
    }
    
    /// 録音設定の基本機能テスト
    func testRecordingSettingsBasicFunctionality() {
        // Given: 録音設定パラメータ
        let stationId = "TBS"
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(3600)
        let outputDirectory = FileManager.default.temporaryDirectory
        
        // When: 録音設定作成
        let settings = RecordingSettings(
            stationId: stationId,
            startTime: startTime,
            endTime: endTime,
            outputDirectory: outputDirectory
        )
        
        // Then: 設定が正しく作成されること
        XCTAssertEqual(settings.stationId, stationId)
        XCTAssertEqual(settings.startTime, startTime)
        XCTAssertEqual(settings.endTime, endTime)
        XCTAssertEqual(settings.outputDirectory, outputDirectory)
        XCTAssertEqual(settings.outputFormat, "aac")
        XCTAssertEqual(settings.maxConcurrentDownloads, 3)
        XCTAssertEqual(settings.retryCount, 3)
    }
    
    /// 録音進捗の基本機能テスト
    func testRecordingProgressBasicFunctionality() {
        // Given: 録音進捗作成
        let progress = RecordingProgress(
            state: .downloading,
            downloadedSegments: 3,
            totalSegments: 10,
            downloadedBytes: 1536,
            estimatedTotalBytes: 5120,
            currentProgram: nil
        )
        
        // Then: 進捗計算が正しいこと
        XCTAssertEqual(progress.progressPercentage, 0.3)
        XCTAssertFalse(progress.isCompleted)
        XCTAssertFalse(progress.isFailed)
    }
}