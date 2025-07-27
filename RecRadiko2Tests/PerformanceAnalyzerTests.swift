//
//  PerformanceAnalyzerTests.swift
//  RecRadiko2Tests
//
//  Created by Claude on 2025/07/26.
//

import XCTest
@testable import RecRadiko2

@MainActor
class PerformanceAnalyzerTests: XCTestCase {
    
    var analyzer: PerformanceAnalyzer!
    
    override func setUp() async throws {
        try await super.setUp()
        analyzer = PerformanceAnalyzer()
    }
    
    override func tearDown() async throws {
        analyzer.stopMonitoring()
        analyzer = nil
        try await super.tearDown()
    }
    
    // MARK: - Network Condition Tests
    
    func testNetworkConditionOptimalConcurrency() throws {
        // 優秀な状態
        let excellentCondition = NetworkCondition.excellent(speed: 150.0)
        XCTAssertEqual(excellentCondition.optimalConcurrency, 8)
        
        // 良好な状態
        let goodCondition = NetworkCondition.good(speed: 75.0)
        XCTAssertEqual(goodCondition.optimalConcurrency, 5)
        
        // 普通の状態
        let fairCondition = NetworkCondition.fair(speed: 25.0)
        XCTAssertEqual(fairCondition.optimalConcurrency, 3)
        
        // 低速な状態
        let poorCondition = NetworkCondition.poor(speed: 5.0)
        XCTAssertEqual(poorCondition.optimalConcurrency, 1)
    }
    
    func testNetworkConditionBufferSize() throws {
        // 優秀な状態
        let excellentCondition = NetworkCondition.excellent(speed: 150.0)
        XCTAssertEqual(excellentCondition.bufferSize, 2 * 1024 * 1024) // 2MB
        
        // 良好な状態
        let goodCondition = NetworkCondition.good(speed: 75.0)
        XCTAssertEqual(goodCondition.bufferSize, 1024 * 1024) // 1MB
        
        // 普通の状態
        let fairCondition = NetworkCondition.fair(speed: 25.0)
        XCTAssertEqual(fairCondition.bufferSize, 512 * 1024) // 512KB
        
        // 低速な状態
        let poorCondition = NetworkCondition.poor(speed: 5.0)
        XCTAssertEqual(poorCondition.bufferSize, 256 * 1024) // 256KB
    }
    
    // MARK: - Performance Monitoring Tests
    
    func testPerformanceMonitoringStartStop() async throws {
        // 初期状態確認
        XCTAssertFalse(analyzer.isMonitoring)
        XCTAssertNil(analyzer.currentMetrics)
        
        // 監視開始
        analyzer.startMonitoring()
        XCTAssertTrue(analyzer.isMonitoring)
        
        // 少し待機してメトリクス収集を確認
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5秒
        XCTAssertNotNil(analyzer.currentMetrics)
        
        // 監視停止
        analyzer.stopMonitoring()
        XCTAssertFalse(analyzer.isMonitoring)
    }
    
    func testMetricsCollection() async throws {
        analyzer.startMonitoring()
        
        // メトリクス収集まで待機
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
        
        guard let metrics = analyzer.currentMetrics else {
            XCTFail("メトリクスが収集されていません")
            return
        }
        
        // メトリクス値の妥当性確認
        XCTAssertGreaterThanOrEqual(metrics.downloadSpeed, 0.0)
        XCTAssertGreaterThan(metrics.memoryUsage, 0)
        XCTAssertGreaterThanOrEqual(metrics.cpuUsage, 0.0)
        XCTAssertLessThanOrEqual(metrics.cpuUsage, 100.0)
        XCTAssertGreaterThanOrEqual(metrics.responseTime, 0.0)
        
        analyzer.stopMonitoring()
    }
    
    // MARK: - Optimization Tests
    
    func testDownloadSettingsOptimization() async throws {
        // 良好な状態での最適化
        analyzer.networkCondition = .good(speed: 75.0)
        let goodSettings = analyzer.optimizeDownloadSettings()
        XCTAssertEqual(goodSettings.maxConcurrent, 5)
        XCTAssertEqual(goodSettings.bufferSize, 1024 * 1024)
        
        // 低速状態での最適化
        analyzer.networkCondition = .poor(speed: 5.0)
        let poorSettings = analyzer.optimizeDownloadSettings()
        XCTAssertEqual(poorSettings.maxConcurrent, 1)
        XCTAssertEqual(poorSettings.bufferSize, 256 * 1024)
    }
    
    func testHighMemoryUsageOptimization() async throws {
        // 高メモリ使用状況をシミュレート
        let highMemoryMetrics = PerformanceMetrics(
            downloadSpeed: 50.0,
            memoryUsage: 2 * 1024 * 1024 * 1024, // 2GB
            cpuUsage: 50.0,
            responseTime: 0.1,
            timestamp: Date()
        )
        
        analyzer.currentMetrics = highMemoryMetrics
        analyzer.networkCondition = .good(speed: 75.0)
        
        let optimizedSettings = analyzer.optimizeDownloadSettings()
        
        // 高メモリ使用時は並行数が半減されることを確認
        XCTAssertEqual(optimizedSettings.maxConcurrent, 2) // 5の半分（小数点切り捨て）
        XCTAssertEqual(optimizedSettings.bufferSize, 512 * 1024) // 1MBの半分
    }
    
    // MARK: - Recommendations Tests
    
    func testRecommendationsGeneration() async throws {
        // 低速ネットワーク状況
        let lowSpeedMetrics = PerformanceMetrics(
            downloadSpeed: 3.0, // 5.0未満
            memoryUsage: 500 * 1024 * 1024, // 500MB
            cpuUsage: 30.0,
            responseTime: 0.1,
            timestamp: Date()
        )
        
        analyzer.currentMetrics = lowSpeedMetrics
        let recommendations = analyzer.generateRecommendations()
        
        XCTAssertTrue(recommendations.contains { $0.contains("ネットワーク速度") })
    }
    
    func testHighMemoryRecommendations() async throws {
        // 高メモリ使用状況
        let highMemoryMetrics = PerformanceMetrics(
            downloadSpeed: 50.0,
            memoryUsage: 3 * 1024 * 1024 * 1024, // 3GB
            cpuUsage: 30.0,
            responseTime: 0.1,
            timestamp: Date()
        )
        
        analyzer.currentMetrics = highMemoryMetrics
        let recommendations = analyzer.generateRecommendations()
        
        XCTAssertTrue(recommendations.contains { $0.contains("メモリ使用量") })
    }
    
    func testHighCPURecommendations() async throws {
        // 高CPU使用状況
        let highCPUMetrics = PerformanceMetrics(
            downloadSpeed: 50.0,
            memoryUsage: 500 * 1024 * 1024,
            cpuUsage: 85.0, // 80%超
            responseTime: 0.1,
            timestamp: Date()
        )
        
        analyzer.currentMetrics = highCPUMetrics
        let recommendations = analyzer.generateRecommendations()
        
        XCTAssertTrue(recommendations.contains { $0.contains("CPU使用率") })
    }
    
    func testSlowUIResponseRecommendations() async throws {
        // 遅いUI応答
        let slowUIMetrics = PerformanceMetrics(
            downloadSpeed: 50.0,
            memoryUsage: 500 * 1024 * 1024,
            cpuUsage: 30.0,
            responseTime: 0.3, // 0.2秒超
            timestamp: Date()
        )
        
        analyzer.currentMetrics = slowUIMetrics
        let recommendations = analyzer.generateRecommendations()
        
        XCTAssertTrue(recommendations.contains { $0.contains("UI応答") })
    }
    
    func testGoodPerformanceRecommendations() async throws {
        // 良好なパフォーマンス
        let goodMetrics = PerformanceMetrics(
            downloadSpeed: 50.0,
            memoryUsage: 500 * 1024 * 1024,
            cpuUsage: 30.0,
            responseTime: 0.1,
            timestamp: Date()
        )
        
        analyzer.currentMetrics = goodMetrics
        let recommendations = analyzer.generateRecommendations()
        
        XCTAssertTrue(recommendations.contains { $0.contains("良好") })
    }
    
    // MARK: - Performance Report Tests
    
    func testPerformanceReportGeneration() async throws {
        // テストデータ作成
        let testMetrics = [
            PerformanceMetrics(downloadSpeed: 50.0, memoryUsage: 500 * 1024 * 1024, cpuUsage: 30.0, responseTime: 0.1, timestamp: Date()),
            PerformanceMetrics(downloadSpeed: 60.0, memoryUsage: 600 * 1024 * 1024, cpuUsage: 40.0, responseTime: 0.15, timestamp: Date()),
            PerformanceMetrics(downloadSpeed: 55.0, memoryUsage: 550 * 1024 * 1024, cpuUsage: 35.0, responseTime: 0.12, timestamp: Date())
        ]
        
        // テスト用メソッドでメトリクス履歴を設定
        analyzer.setMetricsForTesting(testMetrics)
        
        let report = analyzer.generatePerformanceReport()
        
        // レポート内容確認
        XCTAssertTrue(report.contains("パフォーマンスレポート"))
        XCTAssertTrue(report.contains("ダウンロード性能"))
        XCTAssertTrue(report.contains("システムリソース"))
        XCTAssertTrue(report.contains("推奨事項"))
    }
    
    func testEmptyMetricsReport() throws {
        // メトリクス履歴がない状態
        let report = analyzer.generatePerformanceReport()
        XCTAssertTrue(report.contains("パフォーマンスデータがありません"))
    }
    
    // MARK: - StreamingDownloader Integration Tests
    
    func testStreamingDownloaderOptimization() async throws {
        let mockClient = MockHTTPClient()
        let downloader = StreamingDownloader(httpClient: mockClient, maxConcurrentDownloads: 5)
        
        // テストセグメント作成
        let segments = [
            M3U8Segment(url: "https://example.com/seg1.ts", duration: 10.0),
            M3U8Segment(url: "https://example.com/seg2.ts", duration: 10.0),
            M3U8Segment(url: "https://example.com/seg3.ts", duration: 10.0)
        ]
        
        // モックレスポンス設定
        mockClient.requestHandler = { url, method, headers, body in
            switch url.absoluteString {
            case "https://example.com/seg1.ts":
                return Data("segment1".utf8)
            case "https://example.com/seg2.ts":
                return Data("segment2".utf8)
            case "https://example.com/seg3.ts":
                return Data("segment3".utf8)
            default:
                return Data()
            }
        }
        
        // 低速状態に設定
        analyzer.networkCondition = .poor(speed: 5.0)
        
        // 最適化されたダウンロード実行
        let results = try await downloader.downloadWithOptimization(segments, analyzer: analyzer)
        
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0].data, Data("segment1".utf8))
        XCTAssertEqual(results[1].data, Data("segment2".utf8))
        XCTAssertEqual(results[2].data, Data("segment3".utf8))
    }
}

// MARK: - Test Helpers

extension PerformanceAnalyzerTests {
    
    /// テスト用のメトリクス生成
    private func createTestMetrics(downloadSpeed: Double = 50.0,
                                  memoryUsage: Int64 = 500 * 1024 * 1024,
                                  cpuUsage: Double = 30.0,
                                  responseTime: TimeInterval = 0.1) -> PerformanceMetrics {
        return PerformanceMetrics(
            downloadSpeed: downloadSpeed,
            memoryUsage: memoryUsage,
            cpuUsage: cpuUsage,
            responseTime: responseTime,
            timestamp: Date()
        )
    }
}

// MARK: - Performance Test Extensions

extension XCTestCase {
    
    /// パフォーマンス測定ヘルパー
    func measureAsyncPerformance<T>(_ operation: @escaping () async throws -> T) async rethrows -> T {
        let startTime = Date()
        let result = try await operation()
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        print("Performance measurement: \(duration) seconds")
        return result
    }
    
    /// メモリ使用量測定ヘルパー
    func measureMemoryUsage<T>(_ operation: () throws -> T) rethrows -> (result: T, memoryUsage: Int64) {
        let initialMemory = getTestMemoryUsage()
        let result = try operation()
        let finalMemory = getTestMemoryUsage()
        
        return (result, finalMemory - initialMemory)
    }
    
    private func getTestMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}