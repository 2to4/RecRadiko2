//
//  MockHTTPClient.swift
//  RecRadiko2Tests
//  
//  Created by Claude on 2025/07/25.
//

import Foundation
@testable import RecRadiko2

/// テスト用モックHTTPクライアント
class MockHTTPClient: HTTPClientProtocol {
    
    // MARK: - Properties
    var requestCount = 0
    var stationListRequestCount = 0
    var programListRequestCount = 0
    var auth1RequestCount = 0
    var auth2RequestCount = 0
    
    private var auth1Response: Auth1MockResponse?
    private var auth2Response: String?
    private var stationListResponse: Data?
    private var programListResponse: Data?
    private var shouldThrowError = false
    private var errorToThrow: Error = HTTPError.networkError(NSError(domain: "Test", code: -1))
    
    // MARK: - Setup Methods
    
    func setupAuth1Success() {
        auth1Response = Auth1MockResponse(
            authToken: "dGVzdF9hdXRoX3Rva2VuX2RhdGE=", // Base64エンコードされたテストトークン
            keyOffset: 8,
            keyLength: 16
        )
    }
    
    func setupAuth2Success() {
        auth2Response = "JP13,東京都"
    }
    
    func setupAuth2AreaRestricted() {
        shouldThrowError = true
        errorToThrow = RadikoError.areaRestricted
    }
    
    func setupCompleteFlow() {
        setupAuth1Success()
        setupAuth2Success()
        setupStationListSuccess()
        setupProgramListSuccess()
    }
    
    func setupNetworkError() {
        shouldThrowError = true
        errorToThrow = HTTPError.networkError(NSError(domain: "TestNetwork", code: -1001))
    }
    
    func setupServerError() {
        shouldThrowError = true
        errorToThrow = HTTPError.serverError
    }
    
    func setupStationListSuccess() {
        stationListResponse = createMockStationListXML()
    }
    
    func setupProgramListSuccess() {
        programListResponse = createMockProgramListXML()
    }
    
    func resetRequestCount() {
        requestCount = 0
        stationListRequestCount = 0
        programListRequestCount = 0
        auth1RequestCount = 0
        auth2RequestCount = 0
    }
    
    func reset() {
        resetRequestCount()
        auth1Response = nil
        auth2Response = nil
        stationListResponse = nil
        programListResponse = nil
        shouldThrowError = false
        errorToThrow = HTTPError.networkError(NSError(domain: "Test", code: -1))
    }
    
    // MARK: - HTTPClientProtocol Implementation
    
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
        requestCount += 1
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        let urlString = endpoint.absoluteString
        
        switch true {
        case urlString.contains("auth1"):
            return try handleAuth1Request(headers: headers)
            
        case urlString.contains("auth2"):
            return try handleAuth2Request(headers: headers)
            
        case urlString.contains("station/list"):
            stationListRequestCount += 1
            return stationListResponse ?? createMockStationListXML()
            
        case urlString.contains("program/station"):
            programListRequestCount += 1
            return programListResponse ?? createMockProgramListXML()
            
        default:
            return Data()
        }
    }
    
    // MARK: - Private Request Handlers
    
    private func handleAuth1Request(headers: [String: String]?) throws -> Data {
        auth1RequestCount += 1
        
        guard let response = auth1Response else {
            throw HTTPError.serverError
        }
        
        // auth1はレスポンスヘッダーで情報を返すため、
        // テスト用に特別なフォーマットのデータを返す
        let responseData = """
        X-Radiko-AuthToken: \(response.authToken)
        X-Radiko-KeyOffset: \(response.keyOffset)
        X-Radiko-KeyLength: \(response.keyLength)
        """.data(using: .utf8)!
        
        return responseData
    }
    
    private func handleAuth2Request(headers: [String: String]?) throws -> Data {
        auth2RequestCount += 1
        
        // 認証ヘッダーの検証
        guard let authToken = headers?["X-Radiko-AuthToken"],
              let partialKey = headers?["X-Radiko-PartialKey"],
              !authToken.isEmpty,
              !partialKey.isEmpty else {
            throw HTTPError.unauthorized
        }
        
        guard let response = auth2Response else {
            throw HTTPError.serverError
        }
        
        return response.data(using: .utf8)!
    }
    
    // MARK: - Mock Data Creation
    
    private func createMockStationListXML() -> Data {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <stations area_id="JP13" area_name="東京都">
            <station id="TBS" area_id="JP13">
                <name>TBSラジオ</name>
                <ascii_name>TBS RADIO</ascii_name>
                <logo>https://example.com/tbs_logo.png</logo>
                <banner>https://example.com/tbs_banner.png</banner>
                <href>https://www.tbsradio.jp/</href>
            </station>
            <station id="QRR" area_id="JP13">
                <name>文化放送</name>
                <ascii_name>JOQR</ascii_name>
                <logo>https://example.com/qrr_logo.png</logo>
                <banner>https://example.com/qrr_banner.png</banner>
                <href>https://www.joqr.co.jp/</href>
            </station>
            <station id="LFR" area_id="JP13">
                <name>ニッポン放送</name>
                <ascii_name>NIPPON BROADCASTING SYSTEM</ascii_name>
                <logo>https://example.com/lfr_logo.png</logo>
                <banner>https://example.com/lfr_banner.png</banner>
                <href>https://www.1242.com/</href>
            </station>
        </stations>
        """
        return xml.data(using: .utf8)!
    }
    
    private func createMockProgramListXML() -> Data {
        let currentDate = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let dateString = formatter.string(from: currentDate)
        
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <radiko>
            <stations>
                <station id="TBS">
                    <progs>
                        <date>\(dateString)</date>
                        <prog id="prog_001" ft="\(dateString)220000" to="\(dateString)240000" ts="1" station_id="TBS">
                            <title>荻上チキ・Session</title>
                            <info>平日22時から放送中のニュース番組</info>
                            <pfm>荻上チキ,南部広美</pfm>
                            <img>https://example.com/session_image.jpg</img>
                        </prog>
                        <prog id="prog_002" ft="\(dateString)010000" to="\(dateString)020000" ts="1" station_id="TBS">
                            <title>深夜番組テスト</title>
                            <info>深夜1時の番組</info>
                            <pfm>深夜パーソナリティ</pfm>
                            <img>https://example.com/midnight_image.jpg</img>
                        </prog>
                        <prog id="prog_003" ft="\(dateString)140000" to="\(dateString)160000" ts="1" station_id="TBS">
                            <title>伊集院光とらじおと</title>
                            <info>月曜から木曜、午後の2時間</info>
                            <pfm>伊集院光</pfm>
                            <img>https://example.com/ijuin_image.jpg</img>
                        </prog>
                    </progs>
                </station>
            </stations>
        </radiko>
        """
        return xml.data(using: .utf8)!
    }
}

// MARK: - Response Models

struct Auth1MockResponse {
    let authToken: String
    let keyOffset: Int
    let keyLength: Int
}

// MARK: - Radiko専用拡張

extension MockHTTPClient {
    
    func requestXML(_ endpoint: URL,
                    method: HTTPMethod = .get,
                    headers: [String: String]? = nil,
                    body: Data? = nil) async throws -> XMLDocument {
        let data = try await requestData(endpoint, method: method, headers: headers, body: body)
        return try XMLDocument(data: data, options: [])
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

// MARK: - Timeout Mock Client

/// タイムアウト用モックHTTPクライアント
class TimeoutMockHTTPClient: HTTPClientProtocol {
    private let delay: TimeInterval
    
    init(delay: TimeInterval) {
        self.delay = delay
    }
    
    func request<T: Decodable>(_ endpoint: URL,
                               method: HTTPMethod,
                               headers: [String: String]?,
                               body: Data?) async throws -> T {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        throw HTTPError.networkError(NSError(domain: "Timeout", code: -1001))
    }
    
    func requestData(_ endpoint: URL,
                     method: HTTPMethod,
                     headers: [String: String]?,
                     body: Data?) async throws -> Data {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        throw HTTPError.networkError(NSError(domain: "Timeout", code: -1001))
    }
    
    func requestText(_ endpoint: URL,
                     method: HTTPMethod,
                     headers: [String: String]?,
                     body: Data?) async throws -> String {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        throw HTTPError.networkError(NSError(domain: "Timeout", code: -1001))
    }
}

// MARK: - Server Error Mock Client

/// サーバーエラー用モックHTTPクライアント  
class ServerErrorMockHTTPClient: HTTPClientProtocol {
    private let statusCode: Int
    
    init(statusCode: Int = 500) {
        self.statusCode = statusCode
    }
    
    func request<T: Decodable>(_ endpoint: URL,
                               method: HTTPMethod,
                               headers: [String: String]?,
                               body: Data?) async throws -> T {
        throw HTTPError.httpError(statusCode: statusCode)
    }
    
    func requestData(_ endpoint: URL,
                     method: HTTPMethod,
                     headers: [String: String]?,
                     body: Data?) async throws -> Data {
        throw HTTPError.httpError(statusCode: statusCode)
    }
    
    func requestText(_ endpoint: URL,
                     method: HTTPMethod,
                     headers: [String: String]?,
                     body: Data?) async throws -> String {
        throw HTTPError.httpError(statusCode: statusCode)
    }
}