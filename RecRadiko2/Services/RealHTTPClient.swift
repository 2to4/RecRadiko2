//
//  RealHTTPClient.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/27.
//

import Foundation

/// 実際のHTTPクライアント実装
final class RealHTTPClient: HTTPClientProtocol {
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func request<T: Decodable>(_ endpoint: URL, 
                               method: HTTPMethod, 
                               headers: [String: String]?, 
                               body: Data?) async throws -> T {
        let data = try await requestData(endpoint, method: method, headers: headers, body: body)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
    
    func requestData(_ endpoint: URL, 
                     method: HTTPMethod, 
                     headers: [String: String]?, 
                     body: Data?) async throws -> Data {
        var request = URLRequest(url: endpoint)
        request.httpMethod = method.rawValue
        request.httpBody = body
        
        // デフォルトヘッダー（TestRadikoAPI.swiftと同じ設定）
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        
        // カスタムヘッダー
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPError.networkError(NSError(domain: "Invalid response", code: 0))
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            switch httpResponse.statusCode {
            case 401:
                throw HTTPError.unauthorized
            case 404:
                throw HTTPError.httpError(statusCode: 404)
            case 500...599:
                throw HTTPError.serverError
            default:
                throw HTTPError.httpError(statusCode: httpResponse.statusCode)
            }
        }
        
        return data
    }
    
    func requestText(_ endpoint: URL, 
                     method: HTTPMethod, 
                     headers: [String: String]?, 
                     body: Data?) async throws -> String {
        let data = try await requestData(endpoint, method: method, headers: headers, body: body)
        guard let text = String(data: data, encoding: .utf8) else {
            throw HTTPError.decodingError
        }
        return text
    }
    
    func requestWithHeaders(_ endpoint: URL, 
                           method: HTTPMethod, 
                           headers: [String: String]?, 
                           body: Data?) async throws -> (data: Data, headers: [String: String]) {
        var request = URLRequest(url: endpoint)
        request.httpMethod = method.rawValue
        request.httpBody = body
        
        // デフォルトヘッダー（TestRadikoAPI.swiftと同じ設定）
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        
        // カスタムヘッダー
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPError.networkError(NSError(domain: "Invalid response", code: 0))
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            switch httpResponse.statusCode {
            case 401:
                throw HTTPError.unauthorized
            case 404:
                throw HTTPError.httpError(statusCode: 404)
            case 500...599:
                throw HTTPError.serverError
            default:
                throw HTTPError.httpError(statusCode: httpResponse.statusCode)
            }
        }
        
        // レスポンスヘッダーを辞書に変換
        var responseHeaders: [String: String] = [:]
        httpResponse.allHeaderFields.forEach { key, value in
            if let keyString = key as? String, let valueString = value as? String {
                responseHeaders[keyString] = valueString
            }
        }
        
        return (data, responseHeaders)
    }
}