//
//  RadikoAuthService.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/25.
//

import Foundation
import Combine

/// Radiko認証サービスプロトコル
protocol AuthServiceProtocol {
    /// 現在の認証情報
    var currentAuthInfo: AuthInfo? { get }
    
    /// 認証実行
    /// - Returns: 認証情報
    func authenticate() async throws -> AuthInfo
    
    /// 認証更新
    /// - Returns: 新しい認証情報
    func refreshAuth() async throws -> AuthInfo
    
    /// 認証状態の確認
    /// - Returns: 認証が有効かどうか
    func isAuthenticated() -> Bool
}

/// Radiko認証サービス実装
@MainActor
class RadikoAuthService: AuthServiceProtocol {
    // MARK: - Properties
    private let httpClient: HTTPClientProtocol
    private let appKey = "bcd151073c03b352e1ef2fd66c32209da9ca0afa"
    
    @Published private(set) var currentAuthInfo: AuthInfo?
    
    // MARK: - Initializer
    init(httpClient: HTTPClientProtocol = HTTPClient()) {
        self.httpClient = httpClient
        loadCachedAuth()
    }
    
    // MARK: - AuthServiceProtocol Implementation
    func authenticate() async throws -> AuthInfo {
        // 有効なキャッシュがある場合はそれを使用
        if let cached = currentAuthInfo, cached.isValid {
            return cached
        }
        
        // Step 1: auth1リクエスト
        let auth1Response: Auth1Response
        do {
            auth1Response = try await performAuth1()
        } catch {
            throw RadikoError.authenticationFailed
        }
        
        // Step 2: パーシャルキー生成
        let partialKey = extractPartialKey(
            from: auth1Response.authToken,
            offset: auth1Response.keyOffset,
            length: auth1Response.keyLength
        )
        
        // Step 3: auth2リクエスト
        let authInfo: AuthInfo
        do {
            authInfo = try await performAuth2(
                authToken: auth1Response.authToken,
                partialKey: partialKey
            )
        } catch {
            throw RadikoError.authenticationFailed
        }
        
        // キャッシュ保存
        currentAuthInfo = authInfo
        saveCachedAuth(authInfo)
        
        return authInfo
    }
    
    func refreshAuth() async throws -> AuthInfo {
        currentAuthInfo = nil
        clearCachedAuth()
        return try await authenticate()
    }
    
    func isAuthenticated() -> Bool {
        return currentAuthInfo?.isValid ?? false
    }
    
    // MARK: - Private Methods
    
    /// auth1リクエスト実行
    private func performAuth1() async throws -> Auth1Response {
        guard let url = URL(string: RadikoAPIEndpoint.auth1) else {
            throw HTTPError.invalidURL
        }
        
        let headers = [
            "X-Radiko-App": "pc_html5",
            "X-Radiko-App-Version": "0.0.1",
            "X-Radiko-User": "dummy_user",
            "X-Radiko-Device": "pc"
        ]
        
        // HTTPレスポンスを直接取得
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPError.networkError(NSError(domain: "Invalid response", code: 0))
        }
        
        // レスポンスヘッダーから情報抽出
        guard let authToken = httpResponse.value(forHTTPHeaderField: "X-Radiko-AuthToken"),
              let keyOffsetStr = httpResponse.value(forHTTPHeaderField: "X-Radiko-KeyOffset"),
              let keyLengthStr = httpResponse.value(forHTTPHeaderField: "X-Radiko-KeyLength"),
              let keyOffset = Int(keyOffsetStr),
              let keyLength = Int(keyLengthStr) else {
            throw RadikoError.invalidResponse
        }
        
        return Auth1Response(
            authToken: authToken,
            keyOffset: keyOffset,
            keyLength: keyLength
        )
    }
    
    /// パーシャルキー抽出
    /// - Parameters:
    ///   - authToken: 認証トークン
    ///   - offset: オフセット
    ///   - length: 長さ
    /// - Returns: パーシャルキー
    func extractPartialKey(from authToken: String, offset: Int, length: Int) -> String {
        // Base64デコード
        guard let tokenData = Data(base64Encoded: authToken) else {
            return ""
        }
        
        // 範囲チェック
        guard offset >= 0,
              length > 0,
              offset + length <= tokenData.count else {
            return ""
        }
        
        // 指定位置から部分キー抽出
        let startIndex = tokenData.index(tokenData.startIndex, offsetBy: offset)
        let endIndex = tokenData.index(startIndex, offsetBy: length)
        let partialKeyData = tokenData[startIndex..<endIndex]
        
        return partialKeyData.base64EncodedString()
    }
    
    /// auth2リクエスト実行
    private func performAuth2(authToken: String, partialKey: String) async throws -> AuthInfo {
        guard let url = URL(string: RadikoAPIEndpoint.auth2) else {
            throw HTTPError.invalidURL
        }
        
        let headers = [
            "X-Radiko-AuthToken": authToken,
            "X-Radiko-PartialKey": partialKey,
            "X-Radiko-User": "dummy_user",
            "X-Radiko-Device": "pc"
        ]
        
        let responseText = try await httpClient.requestText(
            url,
            method: .post,
            headers: headers,
            body: nil
        )
        
        // レスポンス解析（形式: "JP13,東京都"）
        let components = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: ",")
        
        guard components.count >= 2 else {
            throw RadikoError.invalidResponse
        }
        
        let areaId = components[0]
        let areaName = components[1]
        
        // エリア制限チェック
        if areaId.isEmpty {
            throw RadikoError.areaRestricted
        }
        
        return AuthInfo.create(
            authToken: authToken,
            areaId: areaId,
            areaName: areaName
        )
    }
    
    // MARK: - Cache Management
    
    /// キャッシュから認証情報を読み込み
    private func loadCachedAuth() {
        guard let data = UserDefaults.standard.data(forKey: "RadikoAuthInfo") else {
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let authInfo = try decoder.decode(AuthInfo.self, from: data)
            
            // 有効な認証情報のみロード
            if authInfo.isValid {
                currentAuthInfo = authInfo
            } else {
                clearCachedAuth()
            }
        } catch {
            clearCachedAuth()
        }
    }
    
    /// 認証情報をキャッシュに保存
    private func saveCachedAuth(_ authInfo: AuthInfo) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(authInfo)
            UserDefaults.standard.set(data, forKey: "RadikoAuthInfo")
        } catch {
            // エンコードエラーは無視（ログ出力など後で追加可能）
        }
    }
    
    /// キャッシュされた認証情報をクリア
    private func clearCachedAuth() {
        UserDefaults.standard.removeObject(forKey: "RadikoAuthInfo")
    }
}

// MARK: - Response Models

/// auth1レスポンス構造体
private struct Auth1Response {
    let authToken: String
    let keyOffset: Int
    let keyLength: Int
}

// MARK: - Extensions

extension RadikoAuthService {
    /// 認証状態の詳細情報を取得
    var authStatus: AuthStatus {
        guard let authInfo = currentAuthInfo else {
            return .notAuthenticated
        }
        
        let validationResult = authInfo.validate()
        switch validationResult {
        case .valid:
            return .authenticated(authInfo)
        case .warning(let reason):
            return .warning(authInfo, reason: reason)
        case .expired:
            return .expired(authInfo)
        case .invalid(let reason):
            return .invalid(authInfo, reason: reason)
        }
    }
    
    /// 認証状態列挙型
    enum AuthStatus {
        case notAuthenticated
        case authenticated(AuthInfo)
        case warning(AuthInfo, reason: String)
        case expired(AuthInfo)
        case invalid(AuthInfo, reason: String)
        
        var isUsable: Bool {
            switch self {
            case .authenticated, .warning:
                return true
            case .notAuthenticated, .expired, .invalid:
                return false
            }
        }
        
        var authInfo: AuthInfo? {
            switch self {
            case .notAuthenticated:
                return nil
            case .authenticated(let info), .warning(let info, _), .expired(let info), .invalid(let info, _):
                return info
            }
        }
    }
}