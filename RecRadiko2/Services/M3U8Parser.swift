//
//  M3U8Parser.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/26.
//

import Foundation


/// M3U8セグメント
struct M3U8Segment: Equatable {
    let url: String
    let duration: Double
}

/// M3U8プレイリスト
struct M3U8Playlist: Equatable {
    let version: Int
    let targetDuration: Int
    let mediaSequence: Int
    let segments: [M3U8Segment]
    let isEndList: Bool
    let allowCache: Bool?
    
    init(version: Int = 3,
         targetDuration: Int = 10,
         mediaSequence: Int = 0,
         segments: [M3U8Segment] = [],
         isEndList: Bool = false,
         allowCache: Bool? = nil) {
        self.version = version
        self.targetDuration = targetDuration
        self.mediaSequence = mediaSequence
        self.segments = segments
        self.isEndList = isEndList
        self.allowCache = allowCache
    }
}

/// M3U8プレイリスト解析クラス
class M3U8Parser {
    
    // MARK: - Public Methods
    
    /// M3U8プレイリストを解析（メモリ効率改善版）
    /// - Parameters:
    ///   - content: M3U8コンテンツ
    ///   - baseURL: 相対URLを解決するための基準URL（オプション）
    /// - Returns: 解析されたプレイリスト
    func parse(_ content: String, baseURL: URL? = nil) throws -> M3U8Playlist {
        // メモリ効率: 分割時に中間配列を作らずストリーミング処理
        let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
            .lazy
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // M3U8ファイルの検証
        guard lines.first == "#EXTM3U" else {
            throw RecordingError.invalidPlaylistFormat
        }
        
        var version = 3
        var targetDuration = 10
        var mediaSequence = 0
        var segments: [M3U8Segment] = []
        var isEndList = false
        var allowCache: Bool?
        var currentDuration: Double?
        
        // メモリ効率: セグメント数の概算による容量事前予約
        let estimatedSegmentCount = content.components(separatedBy: "#EXTINF:").count - 1
        if estimatedSegmentCount > 0 {
            segments.reserveCapacity(estimatedSegmentCount)
        }
        
        for line in lines {
            let lineString = String(line) // Substringから文字列に変換
            if lineString.hasPrefix("#EXT-X-VERSION:") {
                if let versionValue = extractIntValue(from: lineString, prefix: "#EXT-X-VERSION:") {
                    version = versionValue
                }
            } else if lineString.hasPrefix("#EXT-X-TARGETDURATION:") {
                if let targetValue = extractIntValue(from: lineString, prefix: "#EXT-X-TARGETDURATION:") {
                    targetDuration = targetValue
                }
            } else if lineString.hasPrefix("#EXT-X-MEDIA-SEQUENCE:") {
                if let sequenceValue = extractIntValue(from: lineString, prefix: "#EXT-X-MEDIA-SEQUENCE:") {
                    mediaSequence = sequenceValue
                }
            } else if lineString.hasPrefix("#EXTINF:") {
                // セグメントの長さを解析（メモリ効率改善）
                currentDuration = extractDuration(from: lineString)
            } else if lineString.hasPrefix("#EXT-X-ENDLIST") {
                isEndList = true
            } else if lineString.hasPrefix("#EXT-X-ALLOW-CACHE:") {
                allowCache = extractBoolValue(from: lineString, prefix: "#EXT-X-ALLOW-CACHE:")
            } else if !lineString.hasPrefix("#") && lineString.contains(".aac") || lineString.contains(".m4a") {
                // セグメントURL
                if let duration = currentDuration {
                    let resolvedURL = resolveURL(lineString, baseURL: baseURL)
                    segments.append(M3U8Segment(url: resolvedURL, duration: duration))
                    currentDuration = nil
                }
            }
        }
        
        return M3U8Playlist(
            version: version,
            targetDuration: targetDuration,
            mediaSequence: mediaSequence,
            segments: segments,
            isEndList: isEndList,
            allowCache: allowCache
        )
    }
    
    // MARK: - Private Helper Methods for Memory Efficiency
    
    /// 整数値抽出（メモリ効率改善）
    private func extractIntValue(from line: String, prefix: String) -> Int? {
        let valueString = String(line.dropFirst(prefix.count))
        return Int(valueString)
    }
    
    /// 期間値抽出（メモリ効率改善）
    private func extractDuration(from line: String) -> Double? {
        let valueString = line.dropFirst("#EXTINF:".count)
        if let commaIndex = valueString.firstIndex(of: ",") {
            let durationString = String(valueString[..<commaIndex])
            return Double(durationString)
        } else {
            return Double(valueString)
        }
    }
    
    /// ブール値抽出（メモリ効率改善）
    private func extractBoolValue(from line: String, prefix: String) -> Bool? {
        let valueString = String(line.dropFirst(prefix.count))
        return valueString == "YES"
    }
    
    // MARK: - Private Methods
    
    /// 相対URLを絶対URLに解決
    private func resolveURL(_ urlString: String, baseURL: URL?) -> String {
        guard let baseURL = baseURL else {
            return urlString
        }
        
        // すでに絶対URLの場合はそのまま返す
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            return urlString
        }
        
        // 絶対パスの場合
        if urlString.hasPrefix("/") {
            var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
            components?.path = urlString
            components?.query = nil
            components?.fragment = nil
            return components?.url?.absoluteString ?? urlString
        }
        
        // 相対パスの場合（../ などを含む）
        if let url = URL(string: urlString, relativeTo: baseURL) {
            return url.absoluteString
        }
        
        // フォールバック
        let resolvedURL = baseURL.deletingLastPathComponent().appendingPathComponent(urlString)
        return resolvedURL.absoluteString
    }
}