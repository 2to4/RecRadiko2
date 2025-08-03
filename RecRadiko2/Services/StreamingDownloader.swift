//
//  StreamingDownloader.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/26.
//

import Foundation

private let logger = AppLogger.shared.category("StreamingDownloader")

// MARK: - Array Extension for Chunking

extension Array {
    /// 配列を指定サイズのチャンクに分割
    /// - Parameter size: チャンクサイズ
    /// - Returns: チャンク配列
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}


/// セグメントダウンロード結果
struct SegmentDownloadResult {
    let url: String
    let data: Data
    let duration: Double
}

/// ストリーミングダウンローダー
class StreamingDownloader {
    
    private let httpClient: HTTPClientProtocol
    private let maxConcurrentDownloads: Int
    private var authHeaders: [String: String] = [:]
    
    // MARK: - Initialization
    
    init(httpClient: HTTPClientProtocol = HTTPClient(), maxConcurrentDownloads: Int = 3) {
        self.httpClient = httpClient
        self.maxConcurrentDownloads = maxConcurrentDownloads
    }
    
    // MARK: - Authentication Headers
    
    /// 認証ヘッダーを設定
    /// - Parameters:
    ///   - authToken: 認証トークン
    ///   - areaId: エリアID
    func setAuthHeaders(authToken: String, areaId: String) {
        logger.debug("認証ヘッダー設定: token=\(authToken.prefix(10))..., area=\(areaId)")
        authHeaders = [
            "X-Radiko-AuthToken": authToken,
            "X-Radiko-AreaId": areaId,
            "User-Agent": "curl/7.56.1",
            "Accept": "*/*",
            "Accept-Encoding": "gzip, deflate, br",
            "Connection": "keep-alive"
        ]
    }
    
    // MARK: - Single Segment Download
    
    /// 単一セグメントのダウンロード
    /// - Parameters:
    ///   - url: セグメントURL
    ///   - maxRetries: 最大リトライ回数
    /// - Returns: ダウンロードされたデータ
    func downloadSegment(from url: String, maxRetries: Int = 3) async throws -> Data {
        logger.debug("セグメントダウンロード開始: \(url)")
        
        guard let segmentURL = URL(string: url) else {
            logger.error("無効なセグメントURL: \(url)")
            throw RecordingError.invalidURL
        }
        
        var lastError: Error?
        
        for attempt in 0...maxRetries {
            do {
                logger.debug("セグメントダウンロード試行 \(attempt + 1)/\(maxRetries + 1): \(url)")
                
                // 認証ヘッダーを使用してリクエスト
                let data = try await httpClient.requestData(segmentURL, method: .get, headers: authHeaders, body: nil)
                
                logger.debug("セグメントダウンロード成功: \(url) (\(data.count)バイト)")
                return data
            } catch {
                lastError = error
                logger.warning("セグメントダウンロード失敗 (試行\(attempt + 1)): \(error.localizedDescription)")
                
                if attempt < maxRetries {
                    // 指数バックオフで待機
                    let delay = Double(1 << attempt)
                    logger.debug("リトライ待機: \(delay)秒")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        if let lastError = lastError {
            logger.error("セグメントダウンロード最終失敗: \(url) - \(lastError.localizedDescription)")
            throw RecordingError.networkError(lastError)
        } else {
            logger.error("セグメントダウンロード原因不明失敗: \(url)")
            throw RecordingError.downloadFailed
        }
    }
    
    // MARK: - Multiple Segments Download
    
    /// 複数セグメントの順次ダウンロード
    /// - Parameters:
    ///   - segments: セグメント配列
    ///   - progressHandler: 進捗ハンドラー（オプション）
    /// - Returns: ダウンロード結果配列
    func downloadSegments(_ segments: [M3U8Segment], 
                         progressHandler: ((Double) -> Void)? = nil) async throws -> [SegmentDownloadResult] {
        var results: [SegmentDownloadResult] = []
        
        for (index, segment) in segments.enumerated() {
            let data = try await downloadSegment(from: segment.url)
            let result = SegmentDownloadResult(
                url: segment.url,
                data: data,
                duration: segment.duration
            )
            results.append(result)
            
            // 進捗更新
            let progress = Double(index + 1) / Double(segments.count)
            progressHandler?(progress)
        }
        
        return results
    }
    
    /// 複数セグメントの並行ダウンロード（メモリ効率改善版）
    /// - Parameters:
    ///   - segments: セグメント配列
    ///   - maxConcurrent: 最大同時実行数
    ///   - resultHandler: 各結果の処理ハンドラー（メモリ効率のため）
    /// - Returns: ダウンロード結果配列
    func downloadSegmentsConcurrently(_ segments: [M3U8Segment], 
                                    maxConcurrent: Int? = nil,
                                    resultHandler: ((SegmentDownloadResult) -> Void)? = nil) async throws -> [SegmentDownloadResult] {
        let concurrentLimit = maxConcurrent ?? maxConcurrentDownloads
        var results: [SegmentDownloadResult] = []
        results.reserveCapacity(segments.count) // メモリ効率: 配列容量を事前予約
        
        // チャンク単位でのバッチ処理によるメモリ効率改善
        let chunkSize = concurrentLimit
        let chunks = segments.chunked(into: chunkSize)
        
        for chunk in chunks {
            let chunkResults = try await withThrowingTaskGroup(of: SegmentDownloadResult.self) { group in
                var tempResults: [SegmentDownloadResult] = []
                tempResults.reserveCapacity(chunk.count)
                
                // 並行ダウンロード実行
                for segment in chunk {
                    group.addTask {
                        let data = try await self.downloadSegment(from: segment.url)
                        return SegmentDownloadResult(
                            url: segment.url,
                            data: data,
                            duration: segment.duration
                        )
                    }
                }
                
                // 結果収集と即座の処理
                for try await result in group {
                    tempResults.append(result)
                    // 即座にハンドラーで処理してメモリ圧迫を軽減
                    resultHandler?(result)
                }
                
                return tempResults
            }
            
            results.append(contentsOf: chunkResults)
            
            // 定期的なメモリ圧迫チェック（オプション）
            if results.count % (chunkSize * 2) == 0 {
                // 大きなデータブロックの処理後に一時的に実行を遅延
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
        }
        
        return results
    }
    
    // MARK: - Streaming URL Construction
    
    /// ストリーミングURL構築
    /// - Parameters:
    ///   - stationId: 放送局ID
    ///   - ft: 開始時刻
    ///   - to: 終了時刻
    /// - Returns: 構築されたURL
    func buildStreamingURL(stationId: String, ft: String, to: String) throws -> String {
        // Radiko APIのストリーミングURLパターン
        let baseURL = "https://radiko.jp/v2/api/ts/playlist.m3u8"
        let queryItems = [
            "station_id=\(stationId)",
            "ft=\(ft)",
            "to=\(to)"
        ]
        
        let fullURL = "\(baseURL)?\(queryItems.joined(separator: "&"))"
        
        guard URL(string: fullURL) != nil else {
            throw RecordingError.invalidURL
        }
        
        return fullURL
    }
}