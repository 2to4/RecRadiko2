//
//  AuthInfo.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/25.
//

import Foundation

/// Radiko認証情報モデル
struct AuthInfo: Codable, Equatable {
    /// 認証トークン
    let authToken: String
    
    /// エリアID (例: JP13)
    let areaId: String
    
    /// エリア名 (例: 東京都)
    let areaName: String
    
    /// 有効期限
    let expiresAt: Date
    
    /// 認証情報が有効かどうか
    var isValid: Bool {
        expiresAt > Date()
    }
    
    /// 有効期限までの残り時間（秒）
    var remainingTime: TimeInterval {
        max(0, expiresAt.timeIntervalSince(Date()))
    }
    
    /// 有効期限までの残り時間を分単位で取得
    var remainingMinutes: Int {
        Int(remainingTime / 60)
    }
    
    // MARK: - Initializer
    init(authToken: String, areaId: String, areaName: String, expiresAt: Date) {
        self.authToken = authToken
        self.areaId = areaId
        self.areaName = areaName
        self.expiresAt = expiresAt
    }
    
    // MARK: - Factory Methods
    
    /// 1時間有効な認証情報を作成
    /// - Parameters:
    ///   - authToken: 認証トークン
    ///   - areaId: エリアID
    ///   - areaName: エリア名
    /// - Returns: 1時間有効な認証情報
    static func create(authToken: String, areaId: String, areaName: String) -> AuthInfo {
        let expiresAt = Date().addingTimeInterval(3600) // 1時間後
        return AuthInfo(authToken: authToken, areaId: areaId, areaName: areaName, expiresAt: expiresAt)
    }
    
    /// カスタム有効期限の認証情報を作成
    /// - Parameters:
    ///   - authToken: 認証トークン
    ///   - areaId: エリアID  
    ///   - areaName: エリア名
    ///   - validFor: 有効時間（秒）
    /// - Returns: 指定時間有効な認証情報
    static func create(authToken: String, areaId: String, areaName: String, validFor: TimeInterval) -> AuthInfo {
        let expiresAt = Date().addingTimeInterval(validFor)
        return AuthInfo(authToken: authToken, areaId: areaId, areaName: areaName, expiresAt: expiresAt)
    }
}

// MARK: - CustomStringConvertible
extension AuthInfo: CustomStringConvertible {
    var description: String {
        return "AuthInfo(areaId: \(areaId), areaName: \(areaName), isValid: \(isValid), remainingMinutes: \(remainingMinutes))"
    }
}

// MARK: - Validation
extension AuthInfo {
    /// 認証情報の妥当性を検証
    /// - Returns: 検証結果
    func validate() -> ValidationResult {
        if authToken.isEmpty {
            return .invalid(reason: "認証トークンが空です")
        }
        
        if areaId.isEmpty {
            return .invalid(reason: "エリアIDが空です")
        }
        
        if !isValid {
            return .expired
        }
        
        // 5分以内に期限切れの場合は警告
        if remainingTime < 300 {
            return .warning(reason: "認証の有効期限が近づいています（残り\(remainingMinutes)分）")
        }
        
        return .valid
    }
    
    /// 検証結果
    enum ValidationResult: Equatable {
        case valid
        case warning(reason: String)
        case invalid(reason: String)
        case expired
        
        var isUsable: Bool {
            switch self {
            case .valid, .warning:
                return true
            case .invalid, .expired:
                return false
            }
        }
        
        var message: String? {
            switch self {
            case .valid:
                return nil
            case .warning(let reason), .invalid(let reason):
                return reason
            case .expired:
                return "認証の有効期限が切れています"
            }
        }
    }
}