//
//  RecordingError.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/26.
//

import Foundation

/// 録音関連の統一エラー型
enum RecordingError: Error, LocalizedError, Equatable {
    // ネットワーク関連
    case networkError(Error)
    case downloadFailed
    case playlistFetchFailed
    case authenticationError
    
    // M3U8解析関連
    case invalidPlaylistFormat
    case unsupportedPlaylistVersion
    case missingSegments
    
    // ファイル・ストレージ関連
    case saveFailed
    case insufficientStorage
    case invalidURL
    case fileNotFound
    
    // ストリーミング関連
    case streamingFailed
    case segmentCorrupted
    case downloadTimeout
    case noData
    
    // その他
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        // ネットワーク関連
        case .networkError(let error):
            return "ネットワークエラー: \(error.localizedDescription)"
        case .downloadFailed:
            return "ダウンロードに失敗しました"
        case .playlistFetchFailed:
            return "プレイリストの取得に失敗しました"
        case .authenticationError:
            return "認証エラーが発生しました"
            
        // M3U8解析関連
        case .invalidPlaylistFormat:
            return "プレイリストの形式が無効です"
        case .unsupportedPlaylistVersion:
            return "サポートされていないプレイリストバージョンです"
        case .missingSegments:
            return "セグメント情報が見つかりません"
            
        // ファイル・ストレージ関連
        case .saveFailed:
            return "録音データの保存に失敗しました"
        case .insufficientStorage:
            return "ストレージ容量が不足しています"
        case .invalidURL:
            return "URLが無効です"
        case .fileNotFound:
            return "ファイルが見つかりません"
            
        // ストリーミング関連
        case .streamingFailed:
            return "ストリーミングに失敗しました"
        case .segmentCorrupted:
            return "セグメントデータが破損しています"
        case .downloadTimeout:
            return "ダウンロードがタイムアウトしました"
        case .noData:
            return "録音データがありません"
            
        // その他
        case .unknown(let message):
            return "不明なエラー: \(message)"
        }
    }
    
    var isRecoverable: Bool {
        switch self {
        case .networkError, .downloadFailed, .downloadTimeout:
            return true
        case .authenticationError:
            return true
        case .segmentCorrupted:
            return true
        default:
            return false
        }
    }
    
    static func == (lhs: RecordingError, rhs: RecordingError) -> Bool {
        switch (lhs, rhs) {
        case (.downloadFailed, .downloadFailed),
             (.playlistFetchFailed, .playlistFetchFailed),
             (.authenticationError, .authenticationError),
             (.invalidPlaylistFormat, .invalidPlaylistFormat),
             (.unsupportedPlaylistVersion, .unsupportedPlaylistVersion),
             (.missingSegments, .missingSegments),
             (.saveFailed, .saveFailed),
             (.insufficientStorage, .insufficientStorage),
             (.invalidURL, .invalidURL),
             (.fileNotFound, .fileNotFound),
             (.streamingFailed, .streamingFailed),
             (.segmentCorrupted, .segmentCorrupted),
             (.downloadTimeout, .downloadTimeout),
             (.noData, .noData):
            return true
        case let (.networkError(lhsError), .networkError(rhsError)):
            return (lhsError as NSError) == (rhsError as NSError)
        case let (.unknown(lhsMessage), .unknown(rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}