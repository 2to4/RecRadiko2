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
class RadikoAuthService: AuthServiceProtocol {
    // MARK: - Properties
    private let httpClient: HTTPClientProtocol
    private let userDefaults: UserDefaultsProtocol
    private let appKey = "bcd151073c03b352e1ef2fd66c32209da9ca0afa"
    
    private var _currentAuthInfo: AuthInfo?
    
    /// スレッドセーフな認証情報プロパティ
    var currentAuthInfo: AuthInfo? {
        get {
            ensureInitialized()
            return initializationQueue.sync {
                return _currentAuthInfo
            }
        }
    }
    
    // MARK: - Properties
    private var isInitialized = false
    private let initializationQueue = DispatchQueue(label: "RadikoAuthService.initialization", attributes: .concurrent)
    private var ongoingAuthenticationTask: Task<AuthInfo, Error>?
    
    // MARK: - Initializer
    init(httpClient: HTTPClientProtocol = HTTPClient(), 
         userDefaults: UserDefaultsProtocol = UserDefaults.standard) {
        self.httpClient = httpClient
        self.userDefaults = userDefaults
        // 遅延初期化：最初のアクセス時にキャッシュを読み込む
    }
    
    /// 遅延初期化の実行（スレッドセーフ）
    private func ensureInitialized() {
        initializationQueue.sync(flags: .barrier) {
            guard !isInitialized else { return }
            isInitialized = true
            loadCachedAuth()
        }
    }
    
    // MARK: - AuthServiceProtocol Implementation
    func authenticate() async throws -> AuthInfo {
        ensureInitialized()
        
        // 有効なキャッシュがある場合はそれを使用
        if let cached = initializationQueue.sync(execute: { _currentAuthInfo }), cached.isValid {
            return cached
        }
        
        // 進行中の認証処理がある場合は、それを待つ
        if let ongoingTask = initializationQueue.sync(execute: { ongoingAuthenticationTask }) {
            return try await ongoingTask.value
        }
        
        // 新しい認証処理を開始
        let authTask = Task<AuthInfo, Error> {
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
            
            // キャッシュ保存（スレッドセーフ）
            initializationQueue.sync(flags: .barrier) {
                _currentAuthInfo = authInfo
                ongoingAuthenticationTask = nil
            }
            saveCachedAuth(authInfo)
            
            return authInfo
        }
        
        // 進行中タスクとして設定
        initializationQueue.sync(flags: .barrier) {
            ongoingAuthenticationTask = authTask
        }
        
        return try await authTask.value
    }
    
    func refreshAuth() async throws -> AuthInfo {
        ensureInitialized()
        initializationQueue.sync(flags: .barrier) {
            _currentAuthInfo = nil
        }
        clearCachedAuth()
        return try await authenticate()
    }
    
    func isAuthenticated() -> Bool {
        ensureInitialized()
        return initializationQueue.sync {
            return _currentAuthInfo?.isValid ?? false
        }
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
        
        // HTTPClientを使用してレスポンスヘッダーを取得
        let (_, responseHeaders) = try await httpClient.requestWithHeaders(
            url,
            method: .post,
            headers: headers,
            body: nil
        )
        
        // レスポンスヘッダーから情報抽出
        guard let authToken = responseHeaders["X-Radiko-AuthToken"],
              let keyOffsetStr = responseHeaders["X-Radiko-KeyOffset"],
              let keyLengthStr = responseHeaders["X-Radiko-KeyLength"],
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
    internal func extractPartialKey(from authToken: String, offset: Int, length: Int) -> String {
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
        let trimmedResponse = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 空のレスポンスはエリア制限
        if trimmedResponse.isEmpty {
            throw RadikoError.areaRestricted
        }
        
        let components = trimmedResponse.components(separatedBy: ",")
        
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
        guard let data = userDefaults.data(forKey: "RadikoAuthInfo") else {
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let authInfo = try decoder.decode(AuthInfo.self, from: data)
            
            // 有効な認証情報のみロード（スレッドセーフ）
            if authInfo.isValid {
                _currentAuthInfo = authInfo
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
            userDefaults.set(data, forKey: "RadikoAuthInfo")
        } catch {
            // エンコードエラーは無視（ログ出力など後で追加可能）
        }
    }
    
    /// キャッシュされた認証情報をクリア
    private func clearCachedAuth() {
        userDefaults.removeObject(forKey: "RadikoAuthInfo")
    }
    
    // MARK: - Test Support
    
    /// テスト専用：完全な状態リセット（スレッドセーフ）
    func resetForTesting() {
        initializationQueue.sync(flags: .barrier) {
            isInitialized = false
            _currentAuthInfo = nil
            ongoingAuthenticationTask?.cancel()
            ongoingAuthenticationTask = nil
        }
        clearCachedAuth()
    }
}

// MARK: - Response Models

/// auth1レスポンス構造体
private struct Auth1Response {
    let authToken: String
    let keyOffset: Int
    let keyLength: Int
}

// MARK: - AuthStatus Definition

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

// MARK: - Extensions

extension RadikoAuthService {
    /// 認証状態の詳細情報を取得
    var authStatus: AuthStatus {
        ensureInitialized()
        return initializationQueue.sync {
            guard let authInfo = _currentAuthInfo else {
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
    }
}