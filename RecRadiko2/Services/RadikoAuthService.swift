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
    init(httpClient: HTTPClientProtocol = RealHTTPClient(), 
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
        
        // TestRadikoAPI.swiftと同じく常に新しい認証を実行（キャッシュ無効）
        print("🔐 [RadikoAuthService] 新しい認証を実行（キャッシュ無効）")
        
        // Step 1: auth1リクエスト
        print("🔑 [RadikoAuthService] auth1リクエスト実行")
        let auth1Response = try await performAuth1()
        print("✅ [RadikoAuthService] auth1完了: offset=\(auth1Response.keyOffset), length=\(auth1Response.keyLength)")
        
        // Step 2: パーシャルキー生成
        let partialKey = extractPartialKey(
            from: auth1Response.authToken,
            offset: auth1Response.keyOffset,
            length: auth1Response.keyLength
        )
        
        // Step 3: auth2リクエスト
        print("🔑 [RadikoAuthService] auth2リクエスト実行: partialKey=\(partialKey.prefix(10))...")
        let authInfo = try await performAuth2(
            authToken: auth1Response.authToken,
            partialKey: partialKey
        )
        print("✅ [RadikoAuthService] auth2完了: エリア=\(authInfo.areaId) - \(authInfo.areaName)")
        
        return authInfo
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
            print("❌ [RadikoAuthService] 無効なURL: \(RadikoAPIEndpoint.auth1)")
            throw HTTPError.invalidURL
        }
        
        let headers = [
            "User-Agent": "Mozilla/5.0",  // TestRadikoAPI.swiftと同じ
            "X-Radiko-App": "pc_html5",
            "X-Radiko-App-Version": "5.0.0",  // TestRadikoAPI.swiftと同じ
            "X-Radiko-Device": "pc",
            "X-Radiko-User": "dummy_user"
        ]
        
        print("🌐 [RadikoAuthService] auth1リクエスト開始")
        print("🌐 [RadikoAuthService] URL: \(url)")
        print("🌐 [RadikoAuthService] ヘッダー: \(headers)")
        
        // TestRadikoAPI.swiftと同じ方法でHTTPレスポンスを取得
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30.0  // タイムアウト設定
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        
        let (data, response): (Data, URLResponse)
        do {
            let result = try await URLSession.shared.data(for: request)
            data = result.0
            response = result.1
            print("🌐 [RadikoAuthService] レスポンス受信: データサイズ=\(data.count)バイト")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("🌐 [RadikoAuthService] レスポンス内容: \(responseString.prefix(200))")
            }
        } catch {
            print("❌ [RadikoAuthService] ネットワークエラー詳細: \(error)")
            print("❌ [RadikoAuthService] エラータイプ: \(type(of: error))")
            if let urlError = error as? URLError {
                print("❌ [RadikoAuthService] URLError詳細: code=\(urlError.code.rawValue), \(urlError.localizedDescription)")
            }
            throw RadikoError.networkError(error)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [RadikoAuthService] HTTPレスポンスの取得に失敗")
            throw RadikoError.invalidResponse
        }
        
        print("🌐 [RadikoAuthService] ステータスコード: \(httpResponse.statusCode)")
        print("🌐 [RadikoAuthService] レスポンスヘッダー: \(httpResponse.allHeaderFields)")
        
        // TestRadikoAPI.swiftと同じ方法でヘッダー取得（大文字小文字区別なし）
        guard let authToken = httpResponse.value(forHTTPHeaderField: "X-Radiko-AuthToken"),
              let keyOffsetStr = httpResponse.value(forHTTPHeaderField: "X-Radiko-KeyOffset"),
              let keyLengthStr = httpResponse.value(forHTTPHeaderField: "X-Radiko-KeyLength"),
              let keyOffset = Int(keyOffsetStr),
              let keyLength = Int(keyLengthStr) else {
            print("❌ [RadikoAuthService] レスポンスヘッダー取得失敗")
            print("❌ [RadikoAuthService] ステータスコード: \(httpResponse.statusCode)")
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
    ///   - authToken: 認証トークン（未使用、互換性のため残す）
    ///   - offset: オフセット
    ///   - length: 長さ
    /// - Returns: パーシャルキー
    internal func extractPartialKey(from authToken: String, offset: Int, length: Int) -> String {
        // アプリキーをデータに変換
        guard let keyData = appKey.data(using: .utf8) else {
            return ""
        }
        
        // 範囲チェック
        guard offset >= 0,
              length > 0,
              offset + length <= keyData.count else {
            return ""
        }
        
        // 指定位置から部分キー抽出（Pythonプロジェクトと同じロジック）
        let partialKeyData = keyData.subdata(in: offset..<(offset + length))
        
        print("🔑 [RadikoAuthService] パーシャルキー生成: offset=\(offset), length=\(length)")
        print("🔑 [RadikoAuthService] 元キー長: \(keyData.count), 抽出範囲: \(offset)..<\(offset + length)")
        print("🔑 [RadikoAuthService] パーシャルキー: \(partialKeyData.base64EncodedString().prefix(10))...")
        
        return partialKeyData.base64EncodedString()
    }
    
    /// auth2リクエスト実行
    private func performAuth2(authToken: String, partialKey: String) async throws -> AuthInfo {
        guard let url = URL(string: RadikoAPIEndpoint.auth2) else {
            throw HTTPError.invalidURL
        }
        
        let headers = [
            "X-Radiko-AuthToken": authToken,
            "X-Radiko-PartialKey": partialKey  // TestRadikoAPI.swiftと同じ大文字のK
        ]
        
        let responseText = try await httpClient.requestText(
            url,
            method: .get,
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