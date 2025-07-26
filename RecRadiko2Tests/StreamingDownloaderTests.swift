//
//  StreamingDownloaderTests.swift
//  RecRadiko2Tests
//
//  Created by Claude on 2025/07/26.
//

import XCTest
@testable import RecRadiko2

/// ストリーミングダウンローダーのテスト
class StreamingDownloaderTests: XCTestCase {
    
    var downloader: StreamingDownloader!
    var mockHTTPClient: MockHTTPClient!
    
    override func setUp() {
        super.setUp()
        mockHTTPClient = MockHTTPClient()
        downloader = StreamingDownloader(httpClient: mockHTTPClient)
    }
    
    override func tearDown() {
        downloader = nil
        mockHTTPClient = nil
        super.tearDown()
    }
    
    // MARK: - Basic Download Tests
    
    func testDownloadSingleSegment() async throws {
        // Given
        let segmentURL = "https://radiko.jp/segment0.aac"
        let mockData = "AAC音声データ".data(using: .utf8)!
        mockHTTPClient.dataToReturn = mockData
        
        // When
        let downloadedData = try await downloader.downloadSegment(from: segmentURL)
        
        // Then
        XCTAssertEqual(downloadedData, mockData)
        XCTAssertEqual(mockHTTPClient.requestCount, 1)
    }
    
    func testDownloadMultipleSegments() async throws {
        // Given
        let segments = [
            M3U8Segment(url: "https://radiko.jp/segment0.aac", duration: 10.0),
            M3U8Segment(url: "https://radiko.jp/segment1.aac", duration: 10.0),
            M3U8Segment(url: "https://radiko.jp/segment2.aac", duration: 10.0)
        ]
        
        let mockData = "AAC音声データ".data(using: .utf8)!
        mockHTTPClient.dataToReturn = mockData
        
        // When
        let results = try await downloader.downloadSegments(segments)
        
        // Then
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(mockHTTPClient.requestCount, 3)
        for result in results {
            XCTAssertEqual(result.data, mockData)
        }
    }
    
    // MARK: - Progress Tracking Tests
    
    func testDownloadProgressTracking() async throws {
        // Given
        let segments = [
            M3U8Segment(url: "https://radiko.jp/segment0.aac", duration: 10.0),
            M3U8Segment(url: "https://radiko.jp/segment1.aac", duration: 10.0)
        ]
        
        mockHTTPClient.dataToReturn = "データ".data(using: .utf8)!
        
        var progressUpdates: [Double] = []
        
        // When
        let results = try await downloader.downloadSegments(segments) { progress in
            progressUpdates.append(progress)
        }
        
        // Then
        XCTAssertEqual(results.count, 2)
        XCTAssertFalse(progressUpdates.isEmpty)
        XCTAssertEqual(progressUpdates.last, 1.0) // 100%完了
    }
    
    // MARK: - Error Handling Tests
    
    func testDownloadSegmentNetworkError() async throws {
        // Given
        let segmentURL = "https://radiko.jp/segment0.aac"
        mockHTTPClient.shouldThrowError = true
        mockHTTPClient.errorToThrow = HTTPError.networkError(NSError(domain: "test", code: -1))
        
        // When & Then
        do {
            _ = try await downloader.downloadSegment(from: segmentURL)
            XCTFail("エラーが発生すべき")
        } catch {
            XCTAssertTrue(error is RecordingError)
        }
    }
    
    func testDownloadWithRetry() async throws {
        // Given
        let segmentURL = "https://radiko.jp/segment0.aac"
        let mockData = "AAC音声データ".data(using: .utf8)!
        
        // 最初の2回は失敗、3回目で成功
        mockHTTPClient.requestHandler = { url, method, headers, body in
            if self.mockHTTPClient.requestCount <= 2 {
                throw HTTPError.serverError
            }
            return mockData
        }
        
        // When
        let downloadedData = try await downloader.downloadSegment(from: segmentURL, maxRetries: 3)
        
        // Then
        XCTAssertEqual(downloadedData, mockData)
        XCTAssertEqual(mockHTTPClient.requestCount, 3)
    }
    
    // MARK: - Concurrent Download Tests
    
    func testConcurrentSegmentDownloads() async throws {
        // Given
        let segments = Array(0..<10).map { index in
            M3U8Segment(url: "https://radiko.jp/segment\(index).aac", duration: 10.0)
        }
        
        mockHTTPClient.dataToReturn = "データ".data(using: .utf8)!
        
        // When
        let startTime = Date()
        let results = try await downloader.downloadSegmentsConcurrently(segments, maxConcurrent: 3)
        let duration = Date().timeIntervalSince(startTime)
        
        // Then
        XCTAssertEqual(results.count, 10)
        XCTAssertLessThan(duration, 5.0) // 並行処理により高速化されているはず
    }
    
    // MARK: - Streaming URL Construction Tests
    
    func testBuildStreamingURL() throws {
        // Given
        let stationId = "TBS"
        let ft = "20250726220000"
        let to = "20250727000000"
        
        // When
        let url = try downloader.buildStreamingURL(stationId: stationId, ft: ft, to: to)
        
        // Then
        XCTAssertTrue(url.contains("radiko.jp"))
        XCTAssertTrue(url.contains(stationId))
        XCTAssertTrue(url.contains(ft))
        XCTAssertTrue(url.contains(to))
    }
}

