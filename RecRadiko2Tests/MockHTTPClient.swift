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
    var shouldThrowError = false
    var errorToThrow: Error = HTTPError.networkError(NSError(domain: "Test", code: -1))
    var dataToReturn: Data?
    var requestHandler: ((URL, HTTPMethod, [String: String]?, Data?) throws -> Data)?
    
    // スレッドセーフティのためのキュー
    private let responseQueue = DispatchQueue(label: "com.recradiko2.test.mock-http-client", attributes: .concurrent)
    
    // MARK: - Setup Methods
    
    func setupAuth1Success() {
        // 実際のRadiko APIが返す形式に準拠したトークン
        // Base64エンコードされたトークンを使用
        let tokenData = "test_auth_token_1234567890abcdef_padding_data".data(using: .utf8)!
        auth1Response = Auth1MockResponse(
            authToken: tokenData.base64EncodedString(),
            keyOffset: 8,
            keyLength: 16
        )
    }
    
    func setupAuth2Success() {
        // 実際のRadiko APIが返す形式: エリアコード,エリア名（神奈川県エリア）
        auth2Response = "JP14,神奈川県"
    }
    
    func setupAuth2AreaRestricted() {
        // エリア制限時は空文字列を返す
        auth2Response = ""
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
        
        // カスタムハンドラーが設定されている場合はそれを使用
        if let handler = requestHandler {
            return try handler(endpoint, method, headers, body)
        }
        
        // デフォルトのdataToReturnが設定されている場合はそれを返す
        if let data = dataToReturn {
            return data
        }
        
        let urlString = endpoint.absoluteString
        
        switch true {
        case urlString.contains("v2/api/auth1"):
            // auth1はrequestWithHeadersで呼び出されるべき
            // requestDataから呼ばれた場合は空データを返す
            return Data()
            
        case urlString.contains("v2/api/auth2"):
            return try handleAuth2Request(headers: headers)
            
        case urlString.contains("station/list"):
            stationListRequestCount += 1
            return stationListResponse ?? createMockStationListXML()
            
        case urlString.contains("program/station"):
            programListRequestCount += 1
            return programListResponse ?? createMockProgramListXML()
            
        case urlString.contains("program/by_id"):
            // 番組詳細取得のケースを追加
            return dataToReturn ?? createMockProgramDetailsXML(programId: "test_program_001")
            
        case urlString.contains("ts/playlist.m3u8"):
            // M3U8プレイリスト取得のケースを追加
            return createMockM3U8Playlist()
            
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
        // requestWithHeadersメソッドで処理される
        // このメソッドからは空データを返す
        return Data()
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
        
        // エリア制限の場合は空のレスポンスを返す（RadikoAuthServiceで処理される）
        return response.data(using: .utf8)!
    }
    
    // MARK: - Mock Data Creation
    
    private func createMockStationListXML() -> Data {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <stations area_id="JP14" area_name="神奈川県">
            <station id="TBS" area_id="JP14">
                <name>TBSラジオ</name>
                <ascii_name>TBS RADIO</ascii_name>
                <logo>https://example.com/tbs_logo.png</logo>
                <banner>https://example.com/tbs_banner.png</banner>
                <href>https://www.tbsradio.jp/</href>
            </station>
            <station id="QRR" area_id="JP14">
                <name>文化放送</name>
                <ascii_name>JOQR</ascii_name>
                <logo>https://example.com/qrr_logo.png</logo>
                <banner>https://example.com/qrr_banner.png</banner>
                <href>https://www.joqr.co.jp/</href>
            </station>
            <station id="JORF" area_id="JP14">
                <name>ラジオ日本</name>
                <ascii_name>RADIO NIPPON</ascii_name>
                <logo>https://example.com/jorf_logo.png</logo>
                <banner>https://example.com/jorf_banner.png</banner>
                <href>https://www.radionikkei.jp/</href>
            </station>
            <station id="BAYFM78" area_id="JP14">
                <name>bayfm78</name>
                <ascii_name>Bay FM 78</ascii_name>
                <logo>https://example.com/bayfm_logo.png</logo>
                <banner>https://example.com/bayfm_banner.png</banner>
                <href>https://www.bayfm.co.jp/</href>
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
    
    private func createMockM3U8Playlist() -> Data {
        let m3u8 = """
        #EXTM3U
        #EXT-X-VERSION:3
        #EXT-X-TARGETDURATION:5
        #EXT-X-MEDIA-SEQUENCE:0
        #EXT-X-KEY:METHOD=AES-128,URI="https://radiko.jp/v2/api/ts/key?token=test_token",IV=0x00000000000000000000000000000001
        #EXTINF:5.0,
        https://example.com/segment0.aac
        #EXTINF:5.0,
        https://example.com/segment1.aac
        #EXTINF:5.0,
        https://example.com/segment2.aac
        #EXT-X-ENDLIST
        """
        return m3u8.data(using: .utf8)!
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
    
    // 追加のセットアップメソッド
    func setupAuth1FailWithKeyExtraction() {
        // キー抽出に失敗する不正なトークンを設定
        auth1Response = Auth1MockResponse(
            authToken: "invalid_token",
            keyOffset: 100,  // 範囲外のオフセット
            keyLength: 16
        )
    }
    
    func setupAuth1FailWithInvalidToken() {
        // 無効なトークンを設定
        auth1Response = Auth1MockResponse(
            authToken: "",  // 空のトークン
            keyOffset: 8,
            keyLength: 16
        )
    }
    
    func setupProgramDetailsSuccess(programId: String) {
        // 番組詳細のモックレスポンスを設定
        let xml = createMockProgramDetailsXML(programId: programId)
        dataToReturn = xml
    }
    
    private func createMockProgramDetailsXML(programId: String) -> Data {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <prog>
            <id>\(programId)</id>
            <station_id>TBS</station_id>
            <ft>20250726220000</ft>
            <to>20250726240000</to>
            <title>テスト番組</title>
            <info>テスト番組の詳細情報</info>
            <pfm>テストパーソナリティ</pfm>
            <img>https://example.com/test_image.jpg</img>
            <ts>1</ts>
        </prog>
        """
        return xml.data(using: .utf8)!
    }
    
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
    
    func requestWithHeaders(_ endpoint: URL,
                           method: HTTPMethod = .get,
                           headers: [String: String]? = nil,
                           body: Data? = nil) async throws -> (data: Data, headers: [String: String]) {
        requestCount += 1
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        // auth1リクエストの場合、適切なヘッダーを返す
        if endpoint.absoluteString.contains("v2/api/auth1") {
            auth1RequestCount += 1
            
            guard let auth1Response = auth1Response else {
                throw HTTPError.serverError
            }
            
            let responseHeaders = [
                "X-Radiko-AuthToken": auth1Response.authToken,
                "X-Radiko-KeyOffset": String(auth1Response.keyOffset),
                "X-Radiko-KeyLength": String(auth1Response.keyLength)
            ]
            
            return (data: Data(), headers: responseHeaders)
        }
        
        // その他のリクエストの場合、通常のrequestDataを呼び出す
        let data = try await requestData(endpoint, method: method, headers: headers, body: body)
        return (data: data, headers: [:])
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
    
    func requestWithHeaders(_ endpoint: URL,
                           method: HTTPMethod,
                           headers: [String: String]?,
                           body: Data?) async throws -> (data: Data, headers: [String: String]) {
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
    
    func requestWithHeaders(_ endpoint: URL,
                           method: HTTPMethod,
                           headers: [String: String]?,
                           body: Data?) async throws -> (data: Data, headers: [String: String]) {
        throw HTTPError.httpError(statusCode: statusCode)
    }
}