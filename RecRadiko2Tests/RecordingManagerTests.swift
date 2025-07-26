//
//  RecordingManagerTests.swift
//  RecRadiko2Tests
//
//  Created by Claude on 2025/07/26.
//

import XCTest
@testable import RecRadiko2

/// 録音管理のテスト
class RecordingManagerTests: XCTestCase {
    
    var recordingManager: RecordingManager!
    var mockAuthService: MockRadikoAuthService!
    var mockAPIService: MockRadikoAPIService!
    var mockStreamingDownloader: MockStreamingDownloader!
    var tempDirectory: URL!
    
    @MainActor 
    override func setUp() {
        super.setUp()
        
        // テスト用一時ディレクトリ
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RecRadiko2Tests")
            .appendingPathComponent(UUID().uuidString)
        
        // モックサービス
        mockAuthService = MockRadikoAuthService()
        mockAPIService = MockRadikoAPIService()
        mockStreamingDownloader = MockStreamingDownloader()
        
        recordingManager = RecordingManager(
            authService: mockAuthService,
            apiService: mockAPIService,
            m3u8Parser: M3U8Parser(),
            streamingDownloader: mockStreamingDownloader
        )
    }
    
    override func tearDown() {
        // 一時ディレクトリ削除
        try? FileManager.default.removeItem(at: tempDirectory)
        
        recordingManager = nil
        mockAuthService = nil
        mockAPIService = nil
        mockStreamingDownloader = nil
        tempDirectory = nil
        super.tearDown()
    }
    
    // MARK: - Recording Settings Tests
    
    func testRecordingSettingsInitialization() {
        // Given
        let stationId = "TBS"
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(3600)
        let outputDirectory = tempDirectory!
        
        // When
        let settings = RecordingSettings(
            stationId: stationId,
            startTime: startTime,
            endTime: endTime,
            outputDirectory: outputDirectory
        )
        
        // Then
        XCTAssertEqual(settings.stationId, stationId)
        XCTAssertEqual(settings.startTime, startTime)
        XCTAssertEqual(settings.endTime, endTime)
        XCTAssertEqual(settings.outputDirectory, outputDirectory)
        XCTAssertEqual(settings.outputFormat, "aac")
        XCTAssertEqual(settings.maxConcurrentDownloads, 3)
        XCTAssertEqual(settings.retryCount, 3)
    }
    
    // MARK: - Recording Progress Tests
    
    func testRecordingProgressCalculation() {
        // Given
        let progress = RecordingProgress(
            state: .downloading,
            downloadedSegments: 5,
            totalSegments: 10,
            downloadedBytes: 1024,
            estimatedTotalBytes: 2048,
            currentProgram: nil
        )
        
        // When & Then
        XCTAssertEqual(progress.progressPercentage, 0.5)
        XCTAssertFalse(progress.isCompleted)
        XCTAssertFalse(progress.isFailed)
    }
    
    func testRecordingProgressCompletedState() {
        // Given
        let progress = RecordingProgress(
            state: .completed,
            downloadedSegments: 10,
            totalSegments: 10,
            downloadedBytes: 2048,
            estimatedTotalBytes: 2048,
            currentProgram: nil
        )
        
        // When & Then
        XCTAssertTrue(progress.isCompleted)
        XCTAssertFalse(progress.isFailed)
        XCTAssertEqual(progress.progressPercentage, 1.0)
    }
    
    func testRecordingProgressFailedState() {
        // Given
        let error = RecordingError.networkError(NSError(domain: "Test", code: -1))
        let progress = RecordingProgress(
            state: .failed(error),
            downloadedSegments: 3,
            totalSegments: 10,
            downloadedBytes: 512,
            estimatedTotalBytes: 2048,
            currentProgram: nil
        )
        
        // When & Then
        XCTAssertFalse(progress.isCompleted)
        XCTAssertTrue(progress.isFailed)
        XCTAssertEqual(progress.progressPercentage, 0.3)
    }
    
    // MARK: - Recording Manager Basic Tests
    
    @MainActor
    func testRecordingManagerInitialization() {
        // Given & When & Then
        XCTAssertNotNil(recordingManager)
        XCTAssertNil(recordingManager.currentProgress)
        XCTAssertTrue(recordingManager.activeRecordings.isEmpty)
    }
    
    @MainActor
    func testStopAllRecordings() async {
        // Given
        let settings = createTestRecordingSettings()
        mockAuthService.setupAuthenticated()
        mockAPIService.setupProgramsSuccess()
        mockStreamingDownloader.setupStreamingSuccess()
        
        // When
        let recordingId = try! await recordingManager.startRecording(with: settings)
        recordingManager.stopAllRecordings()
        
        // Then
        XCTAssertTrue(recordingManager.activeRecordings.isEmpty)
        XCTAssertNil(recordingManager.currentProgress)
    }
    
    // MARK: - Error Handling Tests
    
    func testRecordingErrorDescriptions() {
        // Given & When & Then
        XCTAssertEqual(
            RecordingError.playlistFetchFailed.errorDescription,
            "プレイリストの取得に失敗しました"
        )
        XCTAssertEqual(
            RecordingError.streamingFailed.errorDescription,
            "ストリーミングに失敗しました"
        )
        XCTAssertEqual(
            RecordingError.saveFailed.errorDescription,
            "録音データの保存に失敗しました"
        )
        XCTAssertEqual(
            RecordingError.insufficientStorage.errorDescription,
            "ストレージ容量が不足しています"
        )
        XCTAssertEqual(
            RecordingError.authenticationError.errorDescription,
            "認証エラーが発生しました"
        )
        
        let networkError = NSError(domain: "Test", code: -1, userInfo: [NSLocalizedDescriptionKey: "テストエラー"])
        XCTAssertEqual(
            RecordingError.networkError(networkError).errorDescription,
            "ネットワークエラー: テストエラー"
        )
    }
    
    // MARK: - Helper Methods
    
    private func createTestRecordingSettings() -> RecordingSettings {
        return RecordingSettings(
            stationId: "TBS",
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            outputDirectory: tempDirectory,
            outputFormat: "aac",
            maxConcurrentDownloads: 2,
            retryCount: 1
        )
    }
}

// MARK: - Mock Services

/// モック認証サービス
class MockRadikoAuthService: AuthServiceProtocol {
    private var _isAuthenticated = false
    var shouldFailAuthentication = false
    var _currentAuthInfo: AuthInfo?
    
    var currentAuthInfo: AuthInfo? {
        return _currentAuthInfo
    }
    
    func isAuthenticated() -> Bool {
        return _isAuthenticated
    }
    
    func authenticate() async throws -> AuthInfo {
        if shouldFailAuthentication {
            throw RadikoError.authenticationFailed
        }
        _isAuthenticated = true
        let authInfo = AuthInfo.create(authToken: "test_token", areaId: "JP13", areaName: "東京都")
        _currentAuthInfo = authInfo
        return authInfo
    }
    
    func refreshAuth() async throws -> AuthInfo {
        return try await authenticate()
    }
    
    func setupAuthenticated() {
        _isAuthenticated = true
        _currentAuthInfo = AuthInfo.create(authToken: "test_token", areaId: "JP13", areaName: "東京都")
    }
    
    func setupAuthenticationFailure() {
        shouldFailAuthentication = true
        _isAuthenticated = false
        _currentAuthInfo = nil
    }
}

/// モックAPIサービス
class MockRadikoAPIService: RadikoAPIServiceProtocol {
    var programsToReturn: [RadioProgram] = []
    var shouldThrowError = false
    var errorToThrow: Error = RadikoError.networkError(NSError(domain: "Test", code: -1))
    
    func fetchStations(for areaId: String) async throws -> [RadioStation] {
        if shouldThrowError {
            throw errorToThrow
        }
        return []
    }
    
    func fetchPrograms(stationId: String, date: Date) async throws -> [RadioProgram] {
        if shouldThrowError {
            throw errorToThrow
        }
        return programsToReturn
    }
    
    func setupProgramsSuccess() {
        programsToReturn = [
            RadioProgram(
                id: "test_prog",
                title: "テスト番組",
                description: "テスト番組の説明",
                startTime: Date(),
                endTime: Date().addingTimeInterval(3600),
                personalities: ["テストパーソナリティ"],
                stationId: "TBS"
            )
        ]
    }
}

/// モックストリーミングダウンローダー
class MockStreamingDownloader: StreamingDownloader {
    var segmentResults: [SegmentDownloadResult] = []
    var shouldThrowError = false
    var errorToThrow: Error = RecordingError.downloadFailed
    
    override func buildStreamingURL(stationId: String, ft: String, to: String) throws -> String {
        if shouldThrowError {
            throw errorToThrow
        }
        return "https://radiko.jp/test/playlist.m3u8"
    }
    
    override func downloadSegments(_ segments: [M3U8Segment], 
                                 progressHandler: ((Double) -> Void)? = nil) async throws -> [SegmentDownloadResult] {
        if shouldThrowError {
            throw errorToThrow
        }
        
        // プログレス更新のシミュレーション
        for i in 0..<segments.count {
            let progress = Double(i + 1) / Double(segments.count)
            progressHandler?(progress)
        }
        
        return segmentResults
    }
    
    func setupStreamingSuccess() {
        segmentResults = [
            SegmentDownloadResult(
                url: "https://radiko.jp/segment0.aac",
                data: "テストデータ0".data(using: .utf8)!,
                duration: 10.0
            ),
            SegmentDownloadResult(
                url: "https://radiko.jp/segment1.aac",
                data: "テストデータ1".data(using: .utf8)!,
                duration: 10.0
            )
        ]
    }
}