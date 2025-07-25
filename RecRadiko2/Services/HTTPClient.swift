//
//  HTTPClient.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/25.
//

import Foundation

/// HTTP通信クライアントプロトコル
protocol HTTPClientProtocol {
    /// JSONレスポンスの取得とデコード
    /// - Parameters:
    ///   - endpoint: リクエストURL
    ///   - method: HTTPメソッド
    ///   - headers: HTTPヘッダー
    ///   - body: リクエストボディ
    /// - Returns: デコードされたオブジェクト
    func request<T: Decodable>(_ endpoint: URL,
                               method: HTTPMethod,
                               headers: [String: String]?,
                               body: Data?) async throws -> T
    
    /// 生データの取得
    /// - Parameters:
    ///   - endpoint: リクエストURL
    ///   - method: HTTPメソッド
    ///   - headers: HTTPヘッダー
    ///   - body: リクエストボディ
    /// - Returns: レスポンスデータ
    func requestData(_ endpoint: URL,
                     method: HTTPMethod,
                     headers: [String: String]?,
                     body: Data?) async throws -> Data
    
    /// テキストデータの取得
    /// - Parameters:
    ///   - endpoint: リクエストURL
    ///   - method: HTTPメソッド
    ///   - headers: HTTPヘッダー
    ///   - body: リクエストボディ
    /// - Returns: レスポンステキスト
    func requestText(_ endpoint: URL,
                     method: HTTPMethod,
                     headers: [String: String]?,
                     body: Data?) async throws -> String
}

/// HTTPメソッド定義
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

/// HTTPエラー定義
enum HTTPError: LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case networkError(Error)
    case httpError(statusCode: Int)
    case unauthorized
    case serverError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "無効なURLです"
        case .noData:
            return "データが取得できませんでした"
        case .decodingError:
            return "データの解析に失敗しました"
        case .networkError(let error):
            return "ネットワークエラー: \(error.localizedDescription)"
        case .httpError(let statusCode):
            return "HTTPエラー: \(statusCode)"
        case .unauthorized:
            return "認証に失敗しました"
        case .serverError:
            return "サーバーエラーが発生しました"
        }
    }
}

/// HTTP通信クライアント実装
class HTTPClient: HTTPClientProtocol {
    // MARK: - Properties
    private let session: URLSession
    private let timeout: TimeInterval
    
    // MARK: - Initializer
    init(session: URLSession = .shared, timeout: TimeInterval = 30.0) {
        self.session = session
        self.timeout = timeout
    }
    
    // MARK: - HTTPClientProtocol Implementation
    func request<T: Decodable>(_ endpoint: URL,
                               method: HTTPMethod = .get,
                               headers: [String: String]? = nil,
                               body: Data? = nil) async throws -> T {
        let data = try await requestData(endpoint,
                                        method: method,
                                        headers: headers,
                                        body: body)
        
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            throw HTTPError.decodingError
        }
    }
    
    func requestData(_ endpoint: URL,
                     method: HTTPMethod = .get,
                     headers: [String: String]? = nil,
                     body: Data? = nil) async throws -> Data {
        var request = URLRequest(url: endpoint)
        request.httpMethod = method.rawValue
        request.timeoutInterval = timeout
        
        // デフォルトヘッダー設定
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("RecRadiko2/1.0", forHTTPHeaderField: "User-Agent")
        
        // カスタムヘッダー設定
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // ボディ設定
        if let body = body {
            request.httpBody = body
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw HTTPError.networkError(NSError(domain: "Invalid response", code: 0))
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                return data
            case 401:
                throw HTTPError.unauthorized
            case 500...599:
                throw HTTPError.serverError
            default:
                throw HTTPError.httpError(statusCode: httpResponse.statusCode)
            }
        } catch let error as HTTPError {
            throw error
        } catch {
            throw HTTPError.networkError(error)
        }
    }
    
    func requestText(_ endpoint: URL,
                     method: HTTPMethod = .get,
                     headers: [String: String]? = nil,
                     body: Data? = nil) async throws -> String {
        let data = try await requestData(endpoint, method: method, headers: headers, body: body)
        guard let text = String(data: data, encoding: .utf8) else {
            throw HTTPError.decodingError
        }
        return text
    }
}

// MARK: - Radiko API専用拡張
extension HTTPClient {
    /// Radiko API用のXMLレスポンス処理
    /// - Parameters:
    ///   - endpoint: リクエストURL
    ///   - method: HTTPメソッド
    ///   - headers: HTTPヘッダー
    ///   - body: リクエストボディ
    /// - Returns: XMLDocument
    func requestXML(_ endpoint: URL,
                    method: HTTPMethod = .get,
                    headers: [String: String]? = nil,
                    body: Data? = nil) async throws -> XMLDocument {
        let data = try await requestData(endpoint,
                                        method: method,
                                        headers: headers,
                                        body: body)
        
        do {
            let xml = try XMLDocument(data: data, options: [])
            return xml
        } catch {
            throw HTTPError.decodingError
        }
    }
    
}