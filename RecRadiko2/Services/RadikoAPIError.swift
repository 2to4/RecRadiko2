//
//  RadikoAPIError.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/25.
//

import Foundation

/// Radiko API関連エラー
enum RadikoError: LocalizedError, Equatable {
    case authenticationFailed
    case networkError(Error)
    case invalidResponse
    case areaRestricted
    case programNotAvailable
    case cacheError(Error)
    case invalidAuthToken
    case parsingError(String)
    
    static func == (lhs: RadikoError, rhs: RadikoError) -> Bool {
        switch (lhs, rhs) {
        case (.authenticationFailed, .authenticationFailed),
             (.invalidResponse, .invalidResponse),
             (.areaRestricted, .areaRestricted),
             (.programNotAvailable, .programNotAvailable),
             (.invalidAuthToken, .invalidAuthToken):
            return true
        case let (.networkError(lhsError), .networkError(rhsError)):
            return (lhsError as NSError) == (rhsError as NSError)
        case let (.cacheError(lhsError), .cacheError(rhsError)):
            return (lhsError as NSError) == (rhsError as NSError)
        case let (.parsingError(lhsMessage), .parsingError(rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "認証に失敗しました。しばらく時間をおいて再度お試しください。"
        case .networkError(let error):
            return "ネットワークエラー: \(error.localizedDescription)"
        case .invalidResponse:
            return "サーバーからの応答が不正です"
        case .areaRestricted:
            return "この地域では利用できません"
        case .programNotAvailable:
            return "この番組は現在利用できません"
        case .cacheError(let error):
            return "キャッシュエラーが発生しました: \(error.localizedDescription)"
        case .invalidAuthToken:
            return "認証トークンが無効です"
        case .parsingError(let message):
            return "データの解析に失敗しました: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .authenticationFailed:
            return "インターネット接続を確認してください"
        case .networkError:
            return "インターネット接続を確認してください"
        case .areaRestricted:
            return "ラジコプレミアムをご利用ください"
        case .invalidAuthToken:
            return "アプリを再起動してください"
        default:
            return nil
        }
    }
}

/// Radiko APIエンドポイント定義
enum RadikoAPIEndpoint {
    static let auth1 = "https://radiko.jp/v2/api/auth1"
    static let auth2 = "https://radiko.jp/v2/api/auth2"
    static let stationList = "https://radiko.jp/v3/station/list"
    static let programList = "https://radiko.jp/v3/program/date"
    static let streamingPlaylist = "https://radiko.jp/v2/api/ts/playlist.m3u8"
    
    /// 地域別放送局リストURL
    /// - Parameter areaId: 地域ID (例: JP13)
    /// - Returns: 放送局リストURL
    static func stationListURL(for areaId: String) -> String {
        return "\(stationList)/\(areaId).xml"
    }
    
    /// 番組表URL
    /// - Parameters:
    ///   - areaId: エリアID (例: JP14)
    ///   - date: 対象日
    /// - Returns: 番組表URL
    static func programListURL(areaId: String, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let dateString = formatter.string(from: date)
        return "\(programList)/\(dateString)/\(areaId).xml"
    }
    
    /// ストリーミングプレイリストURL
    /// - Parameters:
    ///   - stationId: 放送局ID
    ///   - programId: 番組ID
    /// - Returns: プレイリストURL
    static func streamingURL(stationId: String, programId: String) -> String {
        return "\(streamingPlaylist)?station_id=\(stationId)&l=15&lsid=\(programId)"
    }
}

/// XMLパースエラー
enum ParsingError: LocalizedError, Equatable {
    case invalidXML
    case missingRequiredField(String)
    case invalidTimeFormat(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidXML:
            return "XMLデータの解析に失敗しました"
        case .missingRequiredField(let field):
            return "必須フィールドが見つかりません: \(field)"
        case .invalidTimeFormat(let format):
            return "時刻フォーマットが不正です: \(format)"
        }
    }
}