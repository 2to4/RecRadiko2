//
//  BaseViewModel.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/24.
//

import Foundation
import Combine

/// ViewModelの基底クラス
/// 共通的な状態管理とライフサイクル管理を提供
@MainActor
class BaseViewModel: ObservableObject {
    // MARK: - 共通状態
    /// ローディング状態
    @Published var isLoading: Bool = false
    
    /// エラーメッセージ
    @Published var errorMessage: String?
    
    // MARK: - Combine管理
    /// Combineの購読を管理するセット
    internal var cancellables = Set<AnyCancellable>()
    
    // MARK: - 初期化
    init() {
        setupNotifications()
    }
    
    // MARK: - ライフサイクル
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - 共通メソッド
    /// エラーメッセージを表示
    /// - Parameter message: 表示するエラーメッセージ
    func showError(_ message: String) {
        errorMessage = message
    }
    
    /// エラーメッセージをクリア
    func clearError() {
        errorMessage = nil
    }
    
    /// ローディング状態を設定
    /// - Parameter loading: ローディング状態
    func setLoading(_ loading: Bool) {
        isLoading = loading
    }
    
    // MARK: - サブクラスでオーバーライド可能
    /// 通知の設定
    /// サブクラスで必要に応じてオーバーライド
    internal func setupNotifications() {
        // デフォルトでは何もしない
    }
}

// MARK: - エラー定義
/// アプリケーション共通エラー
enum AppError: Error, LocalizedError {
    case networkError(String)
    case parseError(String)
    case fileError(String)
    case unauthorized
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "ネットワークエラー: \(message)"
        case .parseError(let message):
            return "データ解析エラー: \(message)"
        case .fileError(let message):
            return "ファイルエラー: \(message)"
        case .unauthorized:
            return "認証エラー: アクセスが拒否されました"
        case .unknown(let message):
            return "不明なエラー: \(message)"
        }
    }
}