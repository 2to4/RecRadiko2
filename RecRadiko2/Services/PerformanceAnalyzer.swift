//
//  PerformanceAnalyzer.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/26.
//

import Foundation
import os.log

/// パフォーマンス測定結果
struct PerformanceMetrics {
    let downloadSpeed: Double // Mbps
    let memoryUsage: Int64 // bytes
    let cpuUsage: Double // percentage
    let responseTime: TimeInterval // seconds
    let timestamp: Date
}

/// ネットワーク状態
enum NetworkCondition {
    case excellent(speed: Double) // > 100 Mbps
    case good(speed: Double)      // 50-100 Mbps  
    case fair(speed: Double)      // 10-50 Mbps
    case poor(speed: Double)      // < 10 Mbps
    
    var optimalConcurrency: Int {
        switch self {
        case .excellent: return 8
        case .good: return 5
        case .fair: return 3
        case .poor: return 1
        }
    }
    
    var bufferSize: Int {
        switch self {
        case .excellent: return 1024 * 1024 * 2 // 2MB
        case .good: return 1024 * 1024 * 1     // 1MB
        case .fair: return 1024 * 512          // 512KB
        case .poor: return 1024 * 256          // 256KB
        }
    }
}

/// パフォーマンス分析・最適化マネージャー
@MainActor
class PerformanceAnalyzer: ObservableObject {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.futo4.RecRadiko2", category: "Performance")
    
    @Published var currentMetrics: PerformanceMetrics?
    @Published var networkCondition: NetworkCondition = .fair(speed: 25.0)
    @Published var isMonitoring = false
    
    private var metricsHistory: [PerformanceMetrics] = []
    private var monitoringTask: Task<Void, Never>?
    
    // MARK: - Performance Monitoring
    
    /// パフォーマンス監視開始
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        monitoringTask = Task {
            while !Task.isCancelled && isMonitoring {
                await recordMetrics()
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒間隔
            }
        }
        
        logger.info("Performance monitoring started")
    }
    
    /// パフォーマンス監視停止
    func stopMonitoring() {
        isMonitoring = false
        monitoringTask?.cancel()
        monitoringTask = nil
        
        logger.info("Performance monitoring stopped")
    }
    
    /// テスト用：メトリクス履歴を設定
    func setMetricsForTesting(_ metrics: [PerformanceMetrics]) {
        metricsHistory = metrics
        if let latest = metrics.last {
            currentMetrics = latest
        }
    }
    
    /// 現在のメトリクスを記録
    private func recordMetrics() async {
        let metrics = PerformanceMetrics(
            downloadSpeed: await measureNetworkSpeed(),
            memoryUsage: getMemoryUsage(),
            cpuUsage: getCPUUsage(),
            responseTime: await measureUIResponseTime(),
            timestamp: Date()
        )
        
        currentMetrics = metrics
        metricsHistory.append(metrics)
        
        // 履歴制限（直近100件まで）
        if metricsHistory.count > 100 {
            metricsHistory.removeFirst()
        }
        
        // ネットワーク状態更新
        updateNetworkCondition(speed: metrics.downloadSpeed)
        
        logger.debug("Metrics recorded: \(metrics.downloadSpeed) Mbps, \(metrics.memoryUsage) bytes")
    }
    
    // MARK: - Performance Measurement
    
    /// ネットワーク速度測定
    private func measureNetworkSpeed() async -> Double {
        // 簡易的な速度測定（実際の実装では小さなファイルダウンロードで測定）
        let testStart = Date()
        let testSize = 1024 * 100 // 100KB
        
        do {
            // テストデータダウンロード（モック）
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒のモック遅延
            let duration = Date().timeIntervalSince(testStart)
            let speedBps = Double(testSize) / duration
            let speedMbps = speedBps * 8 / 1_000_000
            return speedMbps
        } catch {
            return 0.0
        }
    }
    
    /// メモリ使用量取得
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        } else {
            return 0
        }
    }
    
    /// CPU使用率取得
    private func getCPUUsage() -> Double {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let userTime = Double(info.cpu_ticks.0)
            let systemTime = Double(info.cpu_ticks.1)
            let idleTime = Double(info.cpu_ticks.2)
            let totalTime = userTime + systemTime + idleTime
            
            if totalTime > 0 {
                return ((userTime + systemTime) / totalTime) * 100
            }
        }
        
        return 0.0
    }
    
    /// UI応答時間測定
    private func measureUIResponseTime() async -> TimeInterval {
        let start = Date()
        
        // UI更新をシミュレート
        await MainActor.run {
            // 空の処理（実際にはUI更新処理）
        }
        
        return Date().timeIntervalSince(start)
    }
    
    // MARK: - Network Condition Analysis
    
    /// ネットワーク状態更新
    private func updateNetworkCondition(speed: Double) {
        let newCondition: NetworkCondition
        
        switch speed {
        case 100...:
            newCondition = .excellent(speed: speed)
        case 50..<100:
            newCondition = .good(speed: speed)
        case 10..<50:
            newCondition = .fair(speed: speed)
        default:
            newCondition = .poor(speed: speed)
        }
        
        if case .excellent = networkCondition, case .excellent = newCondition {
            // 同じ状態なら更新しない
        } else if case .good = networkCondition, case .good = newCondition {
            // 同じ状態なら更新しない
        } else if case .fair = networkCondition, case .fair = newCondition {
            // 同じ状態なら更新しない
        } else if case .poor = networkCondition, case .poor = newCondition {
            // 同じ状態なら更新しない
        } else {
            networkCondition = newCondition
            logger.info("Network condition updated: \(newCondition)")
        }
    }
    
    // MARK: - Performance Optimization
    
    /// ダウンロード設定最適化
    func optimizeDownloadSettings() -> (maxConcurrent: Int, bufferSize: Int) {
        let concurrency = networkCondition.optimalConcurrency
        let bufferSize = networkCondition.bufferSize
        
        // メモリ使用量が高い場合は並行数を制限
        if let currentMetrics = currentMetrics {
            let memoryGB = Double(currentMetrics.memoryUsage) / (1024 * 1024 * 1024)
            if memoryGB > 1.0 { // 1GB以上使用している場合
                let adjustedConcurrency = max(1, concurrency / 2)
                logger.warning("High memory usage detected, reducing concurrency to \(adjustedConcurrency)")
                return (adjustedConcurrency, bufferSize / 2)
            }
        }
        
        return (concurrency, bufferSize)
    }
    
    /// パフォーマンス推奨事項生成
    func generateRecommendations() -> [String] {
        var recommendations: [String] = []
        
        guard let metrics = currentMetrics else {
            return ["パフォーマンスデータを収集中..."]
        }
        
        // ダウンロード速度の推奨事項
        if metrics.downloadSpeed < 5.0 {
            recommendations.append("ネットワーク速度が低下しています。Wi-Fi接続を確認してください。")
        }
        
        // メモリ使用量の推奨事項
        let memoryGB = Double(metrics.memoryUsage) / (1024 * 1024 * 1024)
        if memoryGB > 2.0 {
            recommendations.append("メモリ使用量が多くなっています。他のアプリを終了することを推奨します。")
        }
        
        // CPU使用率の推奨事項
        if metrics.cpuUsage > 80.0 {
            recommendations.append("CPU使用率が高くなっています。同時ダウンロード数を減らすことを推奨します。")
        }
        
        // UI応答性の推奨事項
        if metrics.responseTime > 0.2 {
            recommendations.append("UI応答が遅くなっています。バックグラウンド処理を一時停止することを推奨します。")
        }
        
        if recommendations.isEmpty {
            recommendations.append("パフォーマンスは良好です。")
        }
        
        return recommendations
    }
    
    // MARK: - Performance Report
    
    /// パフォーマンスレポート生成
    func generatePerformanceReport() -> String {
        guard !metricsHistory.isEmpty else {
            return "パフォーマンスデータがありません。"
        }
        
        let avgDownloadSpeed = metricsHistory.map { $0.downloadSpeed }.reduce(0, +) / Double(metricsHistory.count)
        let avgMemoryUsage = metricsHistory.map { $0.memoryUsage }.reduce(0, +) / Int64(metricsHistory.count)
        let avgCPUUsage = metricsHistory.map { $0.cpuUsage }.reduce(0, +) / Double(metricsHistory.count)
        let avgResponseTime = metricsHistory.map { $0.responseTime }.reduce(0, +) / Double(metricsHistory.count)
        
        let report = """
        === RecRadiko2 パフォーマンスレポート ===
        
        測定期間: \(metricsHistory.count)サンプル
        
        ダウンロード性能:
        - 平均速度: \(String(format: "%.2f", avgDownloadSpeed)) Mbps
        - 最高速度: \(String(format: "%.2f", metricsHistory.map { $0.downloadSpeed }.max() ?? 0)) Mbps
        - 最低速度: \(String(format: "%.2f", metricsHistory.map { $0.downloadSpeed }.min() ?? 0)) Mbps
        
        システムリソース:
        - 平均メモリ使用量: \(String(format: "%.2f", Double(avgMemoryUsage) / (1024*1024))) MB
        - 平均CPU使用率: \(String(format: "%.2f", avgCPUUsage))%
        - 平均UI応答時間: \(String(format: "%.3f", avgResponseTime * 1000)) ms
        
        ネットワーク状態: \(networkCondition)
        
        推奨事項:
        \(generateRecommendations().map { "- \($0)" }.joined(separator: "\n"))
        
        生成日時: \(Date().formatted())
        """
        
        return report
    }
}

// MARK: - Performance Extension for StreamingDownloader

extension StreamingDownloader {
    /// パフォーマンス最適化されたダウンロード
    func downloadWithOptimization(_ segments: [M3U8Segment], 
                                 analyzer: PerformanceAnalyzer) async throws -> [SegmentDownloadResult] {
        let optimization = await analyzer.optimizeDownloadSettings()
        
        return try await downloadSegmentsConcurrently(
            segments,
            maxConcurrent: optimization.maxConcurrent
        ) { result in
            // 結果をアナライザーに通知（必要に応じて）
        }
    }
}

// MARK: - NetworkCondition Extensions

extension NetworkCondition: CustomStringConvertible {
    var description: String {
        switch self {
        case .excellent(let speed):
            return "優秀 (\(String(format: "%.1f", speed)) Mbps)"
        case .good(let speed):
            return "良好 (\(String(format: "%.1f", speed)) Mbps)"
        case .fair(let speed):
            return "普通 (\(String(format: "%.1f", speed)) Mbps)"
        case .poor(let speed):
            return "低速 (\(String(format: "%.1f", speed)) Mbps)"
        }
    }
}