//
//  ErrorRecoveryManager.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/26.
//

import Foundation
import SwiftUI
import os.log

/// 回復オプション
enum RecoveryOption: Equatable {
    case retry
    case retryLater(after: TimeInterval)
    case changeSettings
    case reportIssue
    case dismiss
    
    var localizedTitle: String {
        switch self {
        case .retry:
            return "再試行"
        case .retryLater(let after):
            return "後で再試行 (\(Int(after))秒後)"
        case .changeSettings:
            return "設定を変更"
        case .reportIssue:
            return "問題を報告"
        case .dismiss:
            return "閉じる"
        }
    }
}

/// 強化されたエラー定義
enum RecRadikoError: LocalizedError, Equatable {
    // ネットワーク関連
    case networkUnavailable(retryAfter: TimeInterval)
    case networkTimeout(duration: TimeInterval)
    case serverUnavailable(statusCode: Int)
    case radikoServiceUnavailable(estimatedRecovery: Date?)
    
    // ストレージ関連
    case diskSpaceInsufficient(required: Int64, available: Int64)
    case fileAccessDenied(path: String)
    case diskWriteError(path: String, underlyingError: String)
    
    // データ関連
    case invalidAudioData(segment: String)
    case corruptedDownload(url: String, expectedSize: Int64, actualSize: Int64)
    case playlistParsingFailed(url: String, reason: String)
    
    // 認証関連
    case authenticationExpired
    case authenticationFailed(reason: String)
    case radikoAuthServiceError(reason: String)
    
    // システム関連
    case memoryPressure(currentUsage: Int64)
    case systemResourcesUnavailable(resource: String)
    case unexpectedSystemError(code: Int, description: String)
    
    static func == (lhs: RecRadikoError, rhs: RecRadikoError) -> Bool {
        switch (lhs, rhs) {
        case (.networkUnavailable(let lhsRetry), .networkUnavailable(let rhsRetry)):
            return lhsRetry == rhsRetry
        case (.networkTimeout(let lhsDuration), .networkTimeout(let rhsDuration)):
            return lhsDuration == rhsDuration
        case (.serverUnavailable(let lhsCode), .serverUnavailable(let rhsCode)):
            return lhsCode == rhsCode
        case (.diskSpaceInsufficient(let lhsReq, let lhsAvail), .diskSpaceInsufficient(let rhsReq, let rhsAvail)):
            return lhsReq == rhsReq && lhsAvail == rhsAvail
        case (.fileAccessDenied(let lhsPath), .fileAccessDenied(let rhsPath)):
            return lhsPath == rhsPath
        case (.corruptedDownload(let lhsUrl, let lhsExp, let lhsAct), .corruptedDownload(let rhsUrl, let rhsExp, let rhsAct)):
            return lhsUrl == rhsUrl && lhsExp == rhsExp && lhsAct == rhsAct
        case (.invalidAudioData(let lhsSeg), .invalidAudioData(let rhsSeg)):
            return lhsSeg == rhsSeg
        case (.playlistParsingFailed(let lhsUrl, let lhsReason), .playlistParsingFailed(let rhsUrl, let rhsReason)):
            return lhsUrl == rhsUrl && lhsReason == rhsReason
        case (.authenticationExpired, .authenticationExpired):
            return true
        case (.authenticationFailed(let lhsReason), .authenticationFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.radikoAuthServiceError(let lhsReason), .radikoAuthServiceError(let rhsReason)):
            return lhsReason == rhsReason
        case (.memoryPressure(let lhsUsage), .memoryPressure(let rhsUsage)):
            return lhsUsage == rhsUsage
        case (.systemResourcesUnavailable(let lhsResource), .systemResourcesUnavailable(let rhsResource)):
            return lhsResource == rhsResource
        case (.unexpectedSystemError(let lhsCode, let lhsDesc), .unexpectedSystemError(let rhsCode, let rhsDesc)):
            return lhsCode == rhsCode && lhsDesc == rhsDesc
        default:
            return false
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "ネットワークに接続できません"
        case .networkTimeout(let duration):
            return "ネットワークタイムアウト（\(Int(duration))秒）"
        case .serverUnavailable(let statusCode):
            return "サーバーエラー（HTTP \(statusCode)）"
        case .radikoServiceUnavailable:
            return "Radikoサービスが利用できません"
        case .diskSpaceInsufficient(let required, let available):
            let requiredMB = required / (1024 * 1024)
            let availableMB = available / (1024 * 1024)
            return "ディスク容量が不足しています（必要: \(requiredMB)MB、利用可能: \(availableMB)MB）"
        case .fileAccessDenied(let path):
            return "ファイルアクセスが拒否されました: \(path)"
        case .diskWriteError(let path, let error):
            return "ファイル書き込みエラー: \(path) - \(error)"
        case .invalidAudioData(let segment):
            return "無効な音声データ: \(segment)"
        case .corruptedDownload(let url, let expected, let actual):
            return "ダウンロード破損: \(url)（期待サイズ: \(expected)、実際: \(actual)）"
        case .playlistParsingFailed(let url, let reason):
            return "プレイリスト解析失敗: \(url) - \(reason)"
        case .authenticationExpired:
            return "認証が期限切れです"
        case .authenticationFailed(let reason):
            return "認証に失敗しました: \(reason)"
        case .radikoAuthServiceError(let reason):
            return "Radiko認証サービスエラー: \(reason)"
        case .memoryPressure(let usage):
            return "メモリ不足（使用量: \(usage / (1024*1024))MB）"
        case .systemResourcesUnavailable(let resource):
            return "システムリソースが利用できません: \(resource)"
        case .unexpectedSystemError(let code, let description):
            return "予期しないシステムエラー（コード: \(code)）: \(description)"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .networkUnavailable:
            return "インターネット接続が不安定、またはWi-Fi/Ethernetが切断されています。"
        case .networkTimeout:
            return "ネットワーク応答が遅すぎるため、接続がタイムアウトしました。"
        case .serverUnavailable:
            return "Radikoサーバーが一時的に利用できない状態です。"
        case .radikoServiceUnavailable:
            return "Radikoサービスがメンテナンス中、または障害が発生している可能性があります。"
        case .diskSpaceInsufficient:
            return "録音ファイルを保存するために十分なディスク容量がありません。"
        case .fileAccessDenied:
            return "指定されたフォルダへの書き込み権限がありません。"
        case .diskWriteError:
            return "ディスクの書き込み中にエラーが発生しました。ディスクの状態を確認してください。"
        case .invalidAudioData:
            return "ダウンロードされた音声データが破損している可能性があります。"
        case .corruptedDownload:
            return "ダウンロード中にデータが破損しました。ネットワーク接続を確認してください。"
        case .playlistParsingFailed:
            return "Radikoから提供されたプレイリストの形式が予期しないものです。"
        case .authenticationExpired:
            return "Radikoとの認証セッションが期限切れになりました。"
        case .authenticationFailed:
            return "Radikoサーバーとの認証に失敗しました。"
        case .radikoAuthServiceError:
            return "Radiko認証サービスで問題が発生しました。"
        case .memoryPressure:
            return "アプリケーションのメモリ使用量が多すぎます。"
        case .systemResourcesUnavailable:
            return "システムリソースが不足しています。"
        case .unexpectedSystemError:
            return "予期しないシステムエラーが発生しました。"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable:
            return "Wi-Fi接続を確認し、インターネット接続をテストしてから再試行してください。"
        case .networkTimeout:
            return "しばらく待ってから再試行するか、より安定したネットワーク接続を使用してください。"
        case .serverUnavailable:
            return "しばらく時間をおいてから再試行してください。問題が続く場合は、Radikoの公式サイトで障害情報を確認してください。"
        case .radikoServiceUnavailable:
            return "Radikoサービスの復旧まで待ってから再試行してください。"
        case .diskSpaceInsufficient:
            return "不要なファイルを削除してディスク容量を確保するか、別の保存先を選択してください。"
        case .fileAccessDenied:
            return "別の保存先フォルダを選択するか、フォルダのアクセス権限を確認してください。"
        case .diskWriteError:
            return "ディスクの状態を確認し、別の保存先を試してみてください。"
        case .invalidAudioData, .corruptedDownload:
            return "ネットワーク接続を確認してから再ダウンロードを試してください。"
        case .playlistParsingFailed:
            return "少し時間をおいてから再試行してください。問題が続く場合は番組が利用できない可能性があります。"
        case .authenticationExpired:
            return "アプリが自動的に再認証を試行します。問題が続く場合はアプリを再起動してください。"
        case .authenticationFailed:
            return "アプリを再起動して再試行してください。"
        case .radikoAuthServiceError:
            return "少し時間をおいてから再試行してください。"
        case .memoryPressure:
            return "他のアプリケーションを終了してメモリを解放してから再試行してください。"
        case .systemResourcesUnavailable:
            return "システムを再起動するか、他のアプリケーションを終了してから再試行してください。"
        case .unexpectedSystemError:
            return "アプリケーションを再起動してから再試行してください。問題が続く場合はシステムを再起動してください。"
        }
    }
    
    var helpAnchor: String? {
        switch self {
        case .networkUnavailable, .networkTimeout:
            return "network-troubleshooting"
        case .serverUnavailable, .radikoServiceUnavailable:
            return "radiko-service-issues"
        case .diskSpaceInsufficient, .fileAccessDenied, .diskWriteError:
            return "storage-issues"
        case .invalidAudioData, .corruptedDownload, .playlistParsingFailed:
            return "download-issues"
        case .authenticationExpired, .authenticationFailed, .radikoAuthServiceError:
            return "authentication-issues"
        case .memoryPressure, .systemResourcesUnavailable, .unexpectedSystemError:
            return "system-issues"
        }
    }
    
    /// 自動回復可能かどうか
    var isRecoverable: Bool {
        switch self {
        case .networkUnavailable, .networkTimeout, .serverUnavailable:
            return true
        case .radikoServiceUnavailable:
            return false
        case .diskSpaceInsufficient:
            return false
        case .fileAccessDenied:
            return false
        case .diskWriteError:
            return false
        case .invalidAudioData, .corruptedDownload:
            return true
        case .playlistParsingFailed:
            return true
        case .authenticationExpired:
            return true
        case .authenticationFailed:
            return true
        case .radikoAuthServiceError:
            return true
        case .memoryPressure:
            return false
        case .systemResourcesUnavailable:
            return false
        case .unexpectedSystemError:
            return false
        }
    }
    
    /// 推奨回復オプション
    var recommendedRecoveryOptions: [RecoveryOption] {
        switch self {
        case .networkUnavailable:
            return [.retry, .retryLater(after: 30), .dismiss]
        case .networkTimeout:
            return [.retry, .retryLater(after: 60), .changeSettings, .dismiss]
        case .serverUnavailable:
            return [.retryLater(after: 300), .reportIssue, .dismiss]
        case .radikoServiceUnavailable:
            return [.retryLater(after: 1800), .reportIssue, .dismiss]
        case .diskSpaceInsufficient:
            return [.changeSettings, .reportIssue, .dismiss]
        case .fileAccessDenied:
            return [.changeSettings, .reportIssue, .dismiss]
        case .diskWriteError:
            return [.retry, .changeSettings, .reportIssue, .dismiss]
        case .invalidAudioData, .corruptedDownload:
            return [.retry, .retryLater(after: 60), .dismiss]
        case .playlistParsingFailed:
            return [.retry, .retryLater(after: 120), .reportIssue, .dismiss]
        case .authenticationExpired:
            return [.retry, .dismiss]
        case .authenticationFailed:
            return [.retry, .retryLater(after: 60), .reportIssue, .dismiss]
        case .radikoAuthServiceError:
            return [.retry, .retryLater(after: 180), .reportIssue, .dismiss]
        case .memoryPressure:
            return [.changeSettings, .reportIssue, .dismiss]
        case .systemResourcesUnavailable:
            return [.retryLater(after: 120), .reportIssue, .dismiss]
        case .unexpectedSystemError:
            return [.retry, .reportIssue, .dismiss]
        }
    }
}

/// エラー回復マネージャー
@MainActor
class ErrorRecoveryManager: ObservableObject {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.futo4.RecRadiko2", category: "ErrorRecovery")
    
    @Published var currentError: RecRadikoError?
    @Published var isShowingErrorDialog = false
    @Published var recoveryInProgress = false
    
    private var recoveryAttempts: [String: Int] = [:]
    private var lastErrorTime: [String: Date] = [:]
    
    // MARK: - Error Recovery
    
    /// エラー回復試行
    /// - Parameter error: 回復を試行するエラー
    /// - Returns: 回復成功可否
    func attemptRecovery(from error: RecRadikoError) async -> Bool {
        let errorKey = String(describing: error)
        
        guard error.isRecoverable else {
            logger.warning("Error is not recoverable: \(error)")
            return false
        }
        
        // 連続試行回数チェック
        let attemptCount = recoveryAttempts[errorKey, default: 0]
        guard attemptCount < 3 else {
            logger.error("Max recovery attempts exceeded for error: \(error)")
            return false
        }
        
        // 短時間での連続エラーチェック
        if let lastTime = lastErrorTime[errorKey],
           Date().timeIntervalSince(lastTime) < 30 {
            logger.warning("Too frequent error occurrence: \(error)")
            return false
        }
        
        recoveryInProgress = true
        recoveryAttempts[errorKey] = attemptCount + 1
        lastErrorTime[errorKey] = Date()
        
        logger.info("Attempting recovery for error: \(error)")
        
        let success = await performRecovery(for: error)
        
        if success {
            recoveryAttempts.removeValue(forKey: errorKey)
            logger.info("Recovery successful for error: \(error)")
        } else {
            logger.error("Recovery failed for error: \(error)")
        }
        
        recoveryInProgress = false
        return success
    }
    
    /// 具体的な回復処理実行
    private func performRecovery(for error: RecRadikoError) async -> Bool {
        switch error {
        case .networkUnavailable, .networkTimeout:
            return await recoverFromNetworkError()
            
        case .serverUnavailable:
            return await recoverFromServerError()
            
        case .authenticationExpired:
            return await recoverFromAuthenticationError()
            
        case .invalidAudioData, .corruptedDownload:
            return await recoverFromDataError()
            
        case .playlistParsingFailed:
            return await recoverFromPlaylistError()
            
        default:
            return false
        }
    }
    
    // MARK: - Specific Recovery Methods
    
    private func recoverFromNetworkError() async -> Bool {
        // ネットワーク接続テスト
        do {
            let url = URL(string: "https://radiko.jp")!
            let (_, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse,
               200...299 ~= httpResponse.statusCode {
                return true
            }
        } catch {
            logger.error("Network recovery test failed: \(error)")
        }
        
        return false
    }
    
    private func recoverFromServerError() async -> Bool {
        // サーバー状態確認（簡易実装）
        try? await Task.sleep(nanoseconds: 5_000_000_000) // 5秒待機
        
        // 実際にはRadikoサーバーの状態を確認
        do {
            let url = URL(string: "https://radiko.jp/v2/api/auth1")!
            let (_, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                return true
            }
        } catch {
            logger.error("Server recovery test failed: \(error)")
        }
        
        return false
    }
    
    private func recoverFromAuthenticationError() async -> Bool {
        // 認証再試行（実際にはRadikoAuthServiceを使用）
        logger.info("Attempting authentication recovery")
        
        // モック実装（実際にはRadikoAuthServiceの再認証メソッドを呼び出し）
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2秒待機
        
        return true
    }
    
    private func recoverFromDataError() async -> Bool {
        // データ回復は通常セグメントの再ダウンロードで解決
        logger.info("Data error recovery - will retry download")
        return true
    }
    
    private func recoverFromPlaylistError() async -> Bool {
        // プレイリスト回復は再取得で対応
        logger.info("Playlist error recovery - will retry fetch")
        return true
    }
    
    // MARK: - User Error Reporting
    
    /// ユーザーにエラーを報告
    /// - Parameters:
    ///   - error: 報告するエラー
    ///   - recovery: 回復オプション
    func reportToUser(error: RecRadikoError, recovery: RecoveryOption? = nil) {
        currentError = error
        isShowingErrorDialog = true
        
        logger.info("Reporting error to user: \(error)")
        
        // 自動回復を試行
        if let recovery = recovery, recovery == .retry {
            Task {
                let success = await attemptRecovery(from: error)
                if success {
                    dismissError()
                }
            }
        }
    }
    
    /// エラーダイアログを閉じる
    func dismissError() {
        currentError = nil
        isShowingErrorDialog = false
    }
    
    /// リトライスケジュール
    /// - Parameters:
    ///   - error: リトライするエラー
    ///   - delay: 遅延時間
    func scheduleRetry(for error: RecRadikoError, after delay: TimeInterval) {
        Task {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            let success = await attemptRecovery(from: error)
            if success {
                dismissError()
            } else {
                // リトライ失敗時の処理
                reportToUser(error: error)
            }
        }
    }
    
    // MARK: - Error Statistics
    
    /// エラー統計取得
    func getErrorStatistics() -> [String: Any] {
        return [
            "totalRecoveryAttempts": recoveryAttempts.values.reduce(0, +),
            "uniqueErrorTypes": recoveryAttempts.keys.count,
            "averageRecoveryAttempts": recoveryAttempts.isEmpty ? 0 : Double(recoveryAttempts.values.reduce(0, +)) / Double(recoveryAttempts.count),
            "lastErrorTime": lastErrorTime.values.max() ?? Date.distantPast
        ]
    }
    
    /// エラー履歴クリア
    func clearErrorHistory() {
        recoveryAttempts.removeAll()
        lastErrorTime.removeAll()
        logger.info("Error history cleared")
    }
}

// MARK: - Error Dialog View

struct ErrorRecoveryDialog: View {
    @ObservedObject var errorManager: ErrorRecoveryManager
    let onRecoverySelected: (RecoveryOption) -> Void
    
    var body: some View {
        if let error = errorManager.currentError {
            VStack(spacing: 20) {
                // エラーアイコン
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                
                // エラータイトル
                Text(error.errorDescription ?? "エラーが発生しました")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                // エラー詳細
                if let reason = error.failureReason {
                    Text(reason)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // 回復提案
                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                        .font(.callout)
                        .foregroundColor(.blue)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // 回復オプションボタン
                VStack(spacing: 10) {
                    ForEach(error.recommendedRecoveryOptions, id: \.localizedTitle) { option in
                        Button(option.localizedTitle) {
                            onRecoverySelected(option)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(errorManager.recoveryInProgress)
                    }
                }
                
                // 進行中インジケーター
                if errorManager.recoveryInProgress {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("回復中...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(30)
            .frame(width: 400)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(12)
            .shadow(radius: 10)
        }
    }
}