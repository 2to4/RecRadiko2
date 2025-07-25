# RecRadiko2 Phase 2 詳細設計書
## API連携・データ管理設計

**作成日**: 2025年7月25日  
**バージョン**: 1.0  
**対象フェーズ**: Phase 2 - API連携・データ管理  
**期間**: 3週間（事前設計2日 + 実装19日）

## 1. Phase 2 概要

### 1.1 目標
Radiko APIとの完全な連携を実現し、実際の番組データの取得・管理機能を実装します。認証処理、番組表取得、深夜番組対応、データキャッシュ機構を含む包括的なデータ管理システムを構築します。

### 1.2 実装範囲
- **Radiko認証実装**: auth1/auth2フローの完全実装
- **番組表機能**: 放送局リスト・番組表の取得とパース
- **深夜番組対応**: 25時間表記変換と日付処理ロジック
- **データ永続化**: AppStorageとキャッシュ機構の実装

### 1.3 前提条件
- Phase 1の完全な実装（UI・基盤）
- Radiko APIの仕様理解
- ネットワーク通信とXMLパースの知識

## 2. Radiko API通信設計

### 2.1 API概要

#### 2.1.1 利用するAPIエンドポイント
```swift
enum RadikoAPIEndpoint {
    static let auth1 = "https://radiko.jp/v2/api/auth1"
    static let auth2 = "https://radiko.jp/v2/api/auth2"
    static let stationList = "https://radiko.jp/v3/station/list"
    static let programList = "https://radiko.jp/v3/program/station/weekly"
    static let streamingPlaylist = "https://radiko.jp/v2/api/ts/playlist.m3u8"
}
```

#### 2.1.2 API通信フロー
```
1. 認証フェーズ
   auth1 (認証トークン取得) → auth2 (エリア情報取得)
   
2. データ取得フェーズ
   放送局リスト取得 → 番組表取得
   
3. ストリーミング準備（Phase 3）
   プレイリスト取得 → セグメント取得
```

### 2.2 HTTPクライアント設計

#### 2.2.1 基本HTTPクライアント
```swift
import Foundation
import Combine

protocol HTTPClientProtocol {
    func request<T: Decodable>(_ endpoint: URL, 
                               method: HTTPMethod,
                               headers: [String: String]?,
                               body: Data?) async throws -> T
    
    func requestData(_ endpoint: URL,
                     method: HTTPMethod,
                     headers: [String: String]?,
                     body: Data?) async throws -> Data
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
}

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

@MainActor
class HTTPClient: HTTPClientProtocol {
    private let session: URLSession
    private let timeout: TimeInterval
    
    init(session: URLSession = .shared, timeout: TimeInterval = 30.0) {
        self.session = session
        self.timeout = timeout
    }
    
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
        
        // ヘッダー設定
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // ボディ設定
        if let body = body {
            request.httpBody = body
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
}
```

#### 2.2.2 Radiko専用拡張
```swift
extension HTTPClient {
    /// Radiko API用のXMLレスポンス処理
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
```

## 3. 認証フロー詳細設計

### 3.1 認証プロセス概要

```
1. auth1リクエスト
   - 認証トークン(authtoken)取得
   - キーオフセット・キー長取得
   
2. パーシャルキー抽出
   - authtokenから指定位置のキー抽出
   
3. auth2リクエスト
   - パーシャルキーで本認証
   - エリア情報取得
```

### 3.2 認証サービス実装

```swift
import Foundation
import CryptoKit

protocol AuthServiceProtocol {
    func authenticate() async throws -> AuthInfo
    func refreshAuth() async throws -> AuthInfo
    var currentAuthInfo: AuthInfo? { get }
}

struct AuthInfo: Codable {
    let authToken: String
    let areaId: String
    let areaName: String
    let expiresAt: Date
    
    var isValid: Bool {
        expiresAt > Date()
    }
}

@MainActor
class RadikoAuthService: AuthServiceProtocol {
    private let httpClient: HTTPClientProtocol
    private let appKey = "bcd151073c03b352e1ef2fd66c32209da9ca0afa"
    
    @Published private(set) var currentAuthInfo: AuthInfo?
    
    init(httpClient: HTTPClientProtocol = HTTPClient()) {
        self.httpClient = httpClient
    }
    
    func authenticate() async throws -> AuthInfo {
        // キャッシュチェック
        if let cached = loadCachedAuth(), cached.isValid {
            currentAuthInfo = cached
            return cached
        }
        
        // Step 1: auth1リクエスト
        let auth1Response = try await performAuth1()
        
        // Step 2: パーシャルキー生成
        let partialKey = extractPartialKey(
            from: auth1Response.authToken,
            offset: auth1Response.keyOffset,
            length: auth1Response.keyLength
        )
        
        // Step 3: auth2リクエスト
        let authInfo = try await performAuth2(
            authToken: auth1Response.authToken,
            partialKey: partialKey
        )
        
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
    
    // MARK: - Private Methods
    
    private func performAuth1() async throws -> Auth1Response {
        let url = URL(string: RadikoAPIEndpoint.auth1)!
        let headers = [
            "X-Radiko-App": "pc_html5",
            "X-Radiko-App-Version": "0.0.1",
            "X-Radiko-User": "dummy_user",
            "X-Radiko-Device": "pc"
        ]
        
        let response = try await httpClient.requestData(
            url,
            method: .post,
            headers: headers,
            body: nil
        )
        
        // ヘッダーから情報抽出（実装省略）
        return Auth1Response(
            authToken: "dummy_token",
            keyOffset: 0,
            keyLength: 16
        )
    }
    
    private func extractPartialKey(from authToken: String, 
                                  offset: Int, 
                                  length: Int) -> String {
        // Base64デコード
        guard let tokenData = Data(base64Encoded: authToken) else {
            return ""
        }
        
        // 指定位置から部分キー抽出
        let startIndex = tokenData.index(tokenData.startIndex, offsetBy: offset)
        let endIndex = tokenData.index(startIndex, offsetBy: length)
        let partialKeyData = tokenData[startIndex..<endIndex]
        
        return partialKeyData.base64EncodedString()
    }
    
    private func performAuth2(authToken: String, 
                             partialKey: String) async throws -> AuthInfo {
        let url = URL(string: RadikoAPIEndpoint.auth2)!
        let headers = [
            "X-Radiko-AuthToken": authToken,
            "X-Radiko-PartialKey": partialKey,
            "X-Radiko-User": "dummy_user",
            "X-Radiko-Device": "pc"
        ]
        
        let _ = try await httpClient.requestData(
            url,
            method: .post,
            headers: headers,
            body: nil
        )
        
        // レスポンスからエリア情報抽出（実装省略）
        return AuthInfo(
            authToken: authToken,
            areaId: "JP13",
            areaName: "東京都",
            expiresAt: Date().addingTimeInterval(3600) // 1時間有効
        )
    }
    
    // MARK: - Cache Management
    
    private func loadCachedAuth() -> AuthInfo? {
        guard let data = UserDefaults.standard.data(forKey: "RadikoAuthInfo") else {
            return nil
        }
        
        return try? JSONDecoder().decode(AuthInfo.self, from: data)
    }
    
    private func saveCachedAuth(_ authInfo: AuthInfo) {
        if let data = try? JSONEncoder().encode(authInfo) {
            UserDefaults.standard.set(data, forKey: "RadikoAuthInfo")
        }
    }
    
    private func clearCachedAuth() {
        UserDefaults.standard.removeObject(forKey: "RadikoAuthInfo")
    }
}

// MARK: - Response Models

private struct Auth1Response {
    let authToken: String
    let keyOffset: Int
    let keyLength: Int
}
```

## 4. データモデル設計

### 4.1 APIレスポンス対応モデル

#### 4.1.1 放送局データモデル
```swift
import Foundation

struct RadioStation: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let displayName: String
    let logoURL: String?
    let areaId: String
    let bannerURL: String?
    let href: String?
    
    // 追加プロパティ
    var isFavorite: Bool = false
    var lastAccessedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case displayName = "ascii_name"
        case logoURL = "logo"
        case areaId = "area_id"
        case bannerURL = "banner"
        case href
    }
}

// MARK: - API Response Model
struct StationListResponse: Codable {
    let stations: [RadioStation]
    let areaId: String
    let areaName: String
    
    enum CodingKeys: String, CodingKey {
        case stations
        case areaId = "area_id"
        case areaName = "area_name"
    }
}
```

#### 4.1.2 番組データモデル
```swift
import Foundation

struct RadioProgram: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let description: String?
    let startTime: Date
    let endTime: Date
    let personalities: [String]
    let stationId: String
    let imageURL: String?
    let isTimeFree: Bool
    
    // 計算プロパティ
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    
    var displayTime: String {
        TimeConverter.formatProgramTime(startTime)
    }
    
    var displayDuration: String {
        let minutes = Int(duration / 60)
        return "\(minutes)分"
    }
    
    // 深夜番組判定
    var isMidnightProgram: Bool {
        let hour = Calendar.current.component(.hour, from: startTime)
        return hour >= 0 && hour < 5
    }
    
    enum CodingKeys: String, CodingKey {
        case id = "ft"
        case title
        case description = "info"
        case startTime = "from_time"
        case endTime = "to_time"
        case personalities = "pfm"
        case stationId = "station_id"
        case imageURL = "img"
        case isTimeFree = "ts"
    }
}

// MARK: - Weekly Program Response
struct WeeklyProgramResponse: Codable {
    let stations: [StationPrograms]
    
    struct StationPrograms: Codable {
        let stationId: String
        let programs: [DailyPrograms]
        
        enum CodingKeys: String, CodingKey {
            case stationId = "id"
            case programs = "progs"
        }
    }
    
    struct DailyPrograms: Codable {
        let date: String
        let programs: [RadioProgram]
        
        enum CodingKeys: String, CodingKey {
            case date
            case programs = "prog"
        }
    }
}
```

### 4.2 データ変換ロジック

#### 4.2.1 XMLパーサー
```swift
import Foundation

protocol XMLParserProtocol {
    func parseStationList(from data: Data) throws -> [RadioStation]
    func parseProgramList(from data: Data) throws -> [RadioProgram]
}

class RadikoXMLParser: XMLParserProtocol {
    
    func parseStationList(from data: Data) throws -> [RadioStation] {
        let xml = try XMLDocument(data: data, options: [])
        guard let root = xml.rootElement() else {
            throw ParsingError.invalidXML
        }
        
        let stationNodes = try root.nodes(forXPath: "//station")
        
        return stationNodes.compactMap { node in
            guard let element = node as? XMLElement else { return nil }
            
            return RadioStation(
                id: element.attribute(forName: "id")?.stringValue ?? "",
                name: element.childElement(name: "name")?.stringValue ?? "",
                displayName: element.childElement(name: "ascii_name")?.stringValue ?? "",
                logoURL: element.childElement(name: "logo")?.stringValue,
                areaId: element.attribute(forName: "area_id")?.stringValue ?? "",
                bannerURL: element.childElement(name: "banner")?.stringValue,
                href: element.childElement(name: "href")?.stringValue
            )
        }
    }
    
    func parseProgramList(from data: Data) throws -> [RadioProgram] {
        let xml = try XMLDocument(data: data, options: [])
        guard let root = xml.rootElement() else {
            throw ParsingError.invalidXML
        }
        
        let programNodes = try root.nodes(forXPath: "//prog")
        
        return programNodes.compactMap { node in
            guard let element = node as? XMLElement else { return nil }
            
            let startTimeStr = element.attribute(forName: "ft")?.stringValue ?? ""
            let endTimeStr = element.attribute(forName: "to")?.stringValue ?? ""
            
            guard let startTime = TimeConverter.parseRadikoTime(startTimeStr),
                  let endTime = TimeConverter.parseRadikoTime(endTimeStr) else {
                return nil
            }
            
            return RadioProgram(
                id: element.attribute(forName: "id")?.stringValue ?? "",
                title: element.childElement(name: "title")?.stringValue ?? "",
                description: element.childElement(name: "info")?.stringValue,
                startTime: startTime,
                endTime: endTime,
                personalities: parsePfm(element.childElement(name: "pfm")?.stringValue),
                stationId: element.attribute(forName: "station_id")?.stringValue ?? "",
                imageURL: element.childElement(name: "img")?.stringValue,
                isTimeFree: element.attribute(forName: "ts")?.stringValue == "1"
            )
        }
    }
    
    private func parsePfm(_ pfmString: String?) -> [String] {
        guard let pfm = pfmString else { return [] }
        return pfm.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

enum ParsingError: LocalizedError {
    case invalidXML
    case missingRequiredField
    
    var errorDescription: String? {
        switch self {
        case .invalidXML:
            return "XMLデータの解析に失敗しました"
        case .missingRequiredField:
            return "必須フィールドが見つかりません"
        }
    }
}

// MARK: - XMLElement Helper
extension XMLElement {
    func childElement(name: String) -> XMLElement? {
        return self.elements(forName: name).first
    }
}
```

## 5. キャッシュ機構設計

### 5.1 キャッシュ戦略

#### 5.1.1 キャッシュポリシー
```swift
enum CachePolicy {
    case stationList(expiration: TimeInterval = 3600 * 24)     // 24時間
    case programList(expiration: TimeInterval = 3600 * 6)      // 6時間
    case authInfo(expiration: TimeInterval = 3600)             // 1時間
    
    var key: String {
        switch self {
        case .stationList:
            return "cache_station_list"
        case .programList:
            return "cache_program_list"
        case .authInfo:
            return "cache_auth_info"
        }
    }
    
    var expiration: TimeInterval {
        switch self {
        case .stationList(let exp):
            return exp
        case .programList(let exp):
            return exp
        case .authInfo(let exp):
            return exp
        }
    }
}
```

### 5.2 キャッシュサービス実装

```swift
import Foundation

protocol CacheServiceProtocol {
    func save<T: Codable>(_ object: T, for policy: CachePolicy) throws
    func load<T: Codable>(_ type: T.Type, for policy: CachePolicy) throws -> T?
    func invalidate(for policy: CachePolicy)
    func invalidateAll()
}

class CacheService: CacheServiceProtocol {
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    init() throws {
        // キャッシュディレクトリ作成
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        guard let cachePath = paths.first else {
            throw CacheError.directoryNotFound
        }
        
        cacheDirectory = cachePath.appendingPathComponent("RecRadiko2", isDirectory: true)
        
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try fileManager.createDirectory(at: cacheDirectory, 
                                          withIntermediateDirectories: true)
        }
    }
    
    func save<T: Codable>(_ object: T, for policy: CachePolicy) throws {
        let wrapper = CacheWrapper(data: object, expiresAt: Date().addingTimeInterval(policy.expiration))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(wrapper)
        let fileURL = cacheFileURL(for: policy)
        
        try data.write(to: fileURL)
    }
    
    func load<T: Codable>(_ type: T.Type, for policy: CachePolicy) throws -> T? {
        let fileURL = cacheFileURL(for: policy)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let wrapper = try decoder.decode(CacheWrapper<T>.self, from: data)
        
        // 有効期限チェック
        if wrapper.expiresAt < Date() {
            invalidate(for: policy)
            return nil
        }
        
        return wrapper.data
    }
    
    func invalidate(for policy: CachePolicy) {
        let fileURL = cacheFileURL(for: policy)
        try? fileManager.removeItem(at: fileURL)
    }
    
    func invalidateAll() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, 
                                       withIntermediateDirectories: true)
    }
    
    // MARK: - Private Methods
    
    private func cacheFileURL(for policy: CachePolicy) -> URL {
        return cacheDirectory.appendingPathComponent("\(policy.key).cache")
    }
}

// MARK: - Cache Wrapper
private struct CacheWrapper<T: Codable>: Codable {
    let data: T
    let expiresAt: Date
}

// MARK: - Cache Error
enum CacheError: LocalizedError {
    case directoryNotFound
    case encodingFailed
    case decodingFailed
    
    var errorDescription: String? {
        switch self {
        case .directoryNotFound:
            return "キャッシュディレクトリが見つかりません"
        case .encodingFailed:
            return "データのエンコードに失敗しました"
        case .decodingFailed:
            return "データのデコードに失敗しました"
        }
    }
}
```

## 6. 深夜番組処理アルゴリズム設計

### 6.1 25時間表記変換

#### 6.1.1 時刻変換ユーティリティ
```swift
import Foundation

struct TimeConverter {
    
    /// Radiko時刻文字列（YYYYMMDDHHmmss）をDateに変換
    static func parseRadikoTime(_ timeString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return formatter.date(from: timeString)
    }
    
    /// 25時間表記用の時刻フォーマット
    static func formatProgramTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        
        guard let hour = components.hour, let minute = components.minute else {
            return "--:--"
        }
        
        // 深夜番組の25時間表記変換
        if hour < 5 {
            // 0-4時を24-28時として表示
            return String(format: "%02d:%02d", hour + 24, minute)
        } else {
            return String(format: "%02d:%02d", hour, minute)
        }
    }
    
    /// 番組の実際の日付を取得（深夜番組考慮）
    static func getProgramDate(_ program: RadioProgram) -> Date {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: program.startTime)
        
        if hour < 5 {
            // 深夜番組は前日扱い
            return calendar.date(byAdding: .day, value: -1, to: program.startTime) ?? program.startTime
        } else {
            return program.startTime
        }
    }
    
    /// 指定日の番組かどうか判定（深夜番組考慮）
    static func isProgramOnDate(_ program: RadioProgram, date: Date) -> Bool {
        let programDate = getProgramDate(program)
        let calendar = Calendar.current
        return calendar.isDate(programDate, inSameDayAs: date)
    }
    
    /// 放送日を表示用文字列に変換
    static func formatProgramDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d(E)"
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return formatter.string(from: date)
    }
}

// MARK: - Date Extension
extension Date {
    /// 5時を基準とした放送日を取得
    var broadcastDate: Date {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: self)
        
        if hour < 5 {
            // 0-4時は前日の放送日
            return calendar.date(byAdding: .day, value: -1, to: self) ?? self
        } else {
            return self
        }
    }
    
    /// 指定時間を加算（時間単位）
    func addingHours(_ hours: Int) -> Date {
        return Calendar.current.date(byAdding: .hour, value: hours, to: self) ?? self
    }
}
```

### 6.2 番組表の日付処理

```swift
extension ProgramListViewModel {
    
    /// 指定日の番組一覧を取得（深夜番組考慮）
    func programsForDate(_ date: Date) -> [RadioProgram] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        // 5時から翌日5時までの番組を取得
        let rangeStart = calendar.date(byAdding: .hour, value: 5, to: startOfDay)!
        let rangeEnd = calendar.date(byAdding: .day, value: 1, to: rangeStart)!
        
        return programs.filter { program in
            program.startTime >= rangeStart && program.startTime < rangeEnd
        }.sorted { $0.startTime < $1.startTime }
    }
    
    /// 週間番組表の日付リスト生成
    func generateWeekDates() -> [Date] {
        let calendar = Calendar.current
        let today = Date()
        
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }.map { date in
            // 5時基準の放送日に調整
            date.broadcastDate
        }
    }
}
```

## 7. API統合サービス実装

### 7.1 Radiko APIサービス

```swift
import Foundation
import Combine

protocol RadikoAPIServiceProtocol {
    func authenticate() async throws -> AuthInfo
    func fetchStations(for areaId: String?) async throws -> [RadioStation]
    func fetchPrograms(stationId: String, date: Date) async throws -> [RadioProgram]
    func fetchWeeklyPrograms(stationId: String) async throws -> [RadioProgram]
}

@MainActor
class RadikoAPIService: RadikoAPIServiceProtocol {
    private let httpClient: HTTPClientProtocol
    private let authService: AuthServiceProtocol
    private let cacheService: CacheServiceProtocol
    private let xmlParser: XMLParserProtocol
    
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: Error?
    
    init(httpClient: HTTPClientProtocol = HTTPClient(),
         authService: AuthServiceProtocol = RadikoAuthService(),
         cacheService: CacheServiceProtocol,
         xmlParser: XMLParserProtocol = RadikoXMLParser()) {
        self.httpClient = httpClient
        self.authService = authService
        self.cacheService = cacheService
        self.xmlParser = xmlParser
    }
    
    func authenticate() async throws -> AuthInfo {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let authInfo = try await authService.authenticate()
            lastError = nil
            return authInfo
        } catch {
            lastError = error
            throw error
        }
    }
    
    func fetchStations(for areaId: String? = nil) async throws -> [RadioStation] {
        // キャッシュチェック
        if let cached: [RadioStation] = try? cacheService.load(
            [RadioStation].self,
            for: .stationList()
        ) {
            return cached
        }
        
        isLoading = true
        defer { isLoading = false }
        
        // 認証確認
        let authInfo = try await ensureAuthenticated()
        let targetAreaId = areaId ?? authInfo.areaId
        
        // API呼び出し
        let url = URL(string: "\(RadikoAPIEndpoint.stationList)/\(targetAreaId).xml")!
        let xmlData = try await httpClient.requestData(url)
        
        // XMLパース
        let stations = try xmlParser.parseStationList(from: xmlData)
        
        // キャッシュ保存
        try? cacheService.save(stations, for: .stationList())
        
        lastError = nil
        return stations
    }
    
    func fetchPrograms(stationId: String, date: Date) async throws -> [RadioProgram] {
        isLoading = true
        defer { isLoading = false }
        
        // 認証確認
        _ = try await ensureAuthenticated()
        
        // 日付フォーマット
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let dateString = formatter.string(from: date)
        
        // API呼び出し
        let url = URL(string: "\(RadikoAPIEndpoint.programList)/\(stationId)/\(dateString).xml")!
        let xmlData = try await httpClient.requestData(url)
        
        // XMLパース
        let programs = try xmlParser.parseProgramList(from: xmlData)
        
        lastError = nil
        return programs
    }
    
    func fetchWeeklyPrograms(stationId: String) async throws -> [RadioProgram] {
        // キャッシュチェック
        let cacheKey = CachePolicy.programList()
        if let cached: [RadioProgram] = try? cacheService.load(
            [RadioProgram].self,
            for: cacheKey
        ) {
            return cached
        }
        
        isLoading = true
        defer { isLoading = false }
        
        // 認証確認
        _ = try await ensureAuthenticated()
        
        // API呼び出し
        let url = URL(string: "\(RadikoAPIEndpoint.programList)/\(stationId).xml")!
        let xmlData = try await httpClient.requestData(url)
        
        // XMLパース
        let programs = try xmlParser.parseProgramList(from: xmlData)
        
        // キャッシュ保存
        try? cacheService.save(programs, for: cacheKey)
        
        lastError = nil
        return programs
    }
    
    // MARK: - Private Methods
    
    private func ensureAuthenticated() async throws -> AuthInfo {
        if let authInfo = authService.currentAuthInfo, authInfo.isValid {
            return authInfo
        }
        
        return try await authService.authenticate()
    }
}
```

### 7.2 ViewModelの更新

```swift
// StationListViewModel更新
extension StationListViewModel {
    func loadStations() {
        Task {
            isLoading = true
            clearError()
            
            do {
                // API経由で実データ取得
                let apiService = RadikoAPIService(
                    cacheService: try CacheService()
                )
                
                // 認証
                _ = try await apiService.authenticate()
                
                // 放送局リスト取得
                let fetchedStations = try await apiService.fetchStations(
                    for: selectedArea.id
                )
                
                await MainActor.run {
                    self.stations = fetchedStations
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.showError(error.localizedDescription)
                    self.isLoading = false
                }
            }
        }
    }
}

// ProgramListViewModel更新
extension ProgramListViewModel {
    func loadPrograms() {
        guard let station = currentStation else { return }
        
        Task {
            isLoading = true
            clearError()
            
            do {
                let apiService = RadikoAPIService(
                    cacheService: try CacheService()
                )
                
                // 週間番組表取得
                let fetchedPrograms = try await apiService.fetchWeeklyPrograms(
                    stationId: station.id
                )
                
                await MainActor.run {
                    self.programs = fetchedPrograms
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.showError(error.localizedDescription)
                    self.isLoading = false
                }
            }
        }
    }
}
```

## 8. エラーハンドリング設計

### 8.1 統合エラー処理

```swift
enum RadikoError: LocalizedError {
    case authenticationFailed
    case networkError(Error)
    case invalidResponse
    case areaRestricted
    case programNotAvailable
    case cacheError(Error)
    
    var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "認証に失敗しました。しばらく時間をおいて再度お試しください。"
        case .networkError(let error):
            return "ネットワークエラー: \(error.localizedDescription)"
        case .invalidResponse:
            return "サーバーからの応答が不正です"
        case .areaRestricted:
            return "この地域では利用できません"
        case .programNotAvailable:
            return "この番組は現在利用できません"
        case .cacheError:
            return "キャッシュエラーが発生しました"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .authenticationFailed:
            return "インターネット接続を確認してください"
        case .networkError:
            return "インターネット接続を確認してください"
        case .areaRestricted:
            return "ラジコプレミアムをご利用ください"
        default:
            return nil
        }
    }
}
```

### 8.2 リトライ機構

```swift
extension RadikoAPIService {
    
    /// リトライ付きリクエスト実行
    private func executeWithRetry<T>(
        maxAttempts: Int = 3,
        delay: TimeInterval = 1.0,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                // リトライ可能なエラーかチェック
                if isRetryableError(error) && attempt < maxAttempts {
                    // 指数バックオフ
                    let backoffDelay = delay * pow(2.0, Double(attempt - 1))
                    try await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))
                    continue
                }
                
                throw error
            }
        }
        
        throw lastError ?? RadikoError.networkError(NSError(domain: "Unknown", code: 0))
    }
    
    private func isRetryableError(_ error: Error) -> Bool {
        if let httpError = error as? HTTPError {
            switch httpError {
            case .networkError, .serverError:
                return true
            default:
                return false
            }
        }
        return false
    }
}
```

## 9. UI統合更新

### 9.1 ローディング・エラー表示

```swift
// 共通ローディングビュー
struct LoadingOverlay: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text(message)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(40)
            .background(Color(white: 0.2))
            .cornerRadius(12)
        }
    }
}

// エラー表示ビュー
struct ErrorBanner: View {
    let error: Error
    let onRetry: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                
                Text(error.localizedDescription)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                
                Spacer()
                
                if let onRetry = onRetry {
                    Button("再試行") {
                        onRetry()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
            
            if let radikoError = error as? RadikoError,
               let suggestion = radikoError.recoverySuggestion {
                Text(suggestion)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.red.opacity(0.2))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.red.opacity(0.5), lineWidth: 1)
        )
    }
}
```

### 9.2 View更新例

```swift
// StationListView更新
extension StationListView {
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // エラーバナー
                if let error = viewModel.errorMessage {
                    ErrorBanner(error: error) {
                        viewModel.loadStations()
                    }
                    .padding()
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // 既存のコンテンツ
                explanationSection
                Divider()
                stationGrid
            }
            
            // ローディングオーバーレイ
            if viewModel.isLoading {
                LoadingOverlay(message: "放送局を読み込んでいます...")
            }
        }
        .background(Color.black)
        .onAppear {
            viewModel.loadStations()
        }
    }
}
```

## 10. パフォーマンス最適化

### 10.1 非同期処理最適化

```swift
// 並列データ取得
extension RadikoAPIService {
    
    /// 複数放送局の番組を並列取得
    func fetchMultipleStationPrograms(
        stationIds: [String],
        date: Date
    ) async throws -> [String: [RadioProgram]] {
        try await withThrowingTaskGroup(of: (String, [RadioProgram]).self) { group in
            for stationId in stationIds {
                group.addTask {
                    let programs = try await self.fetchPrograms(
                        stationId: stationId,
                        date: date
                    )
                    return (stationId, programs)
                }
            }
            
            var results: [String: [RadioProgram]] = [:]
            for try await (stationId, programs) in group {
                results[stationId] = programs
            }
            
            return results
        }
    }
}
```

### 10.2 メモリ管理

```swift
// 画像キャッシュ管理
class ImageCacheManager {
    static let shared = ImageCacheManager()
    private var cache = NSCache<NSString, NSImage>()
    
    init() {
        cache.countLimit = 50
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    func image(for url: URL) -> NSImage? {
        return cache.object(forKey: url.absoluteString as NSString)
    }
    
    func store(_ image: NSImage, for url: URL) {
        cache.setObject(image, forKey: url.absoluteString as NSString)
    }
}
```

---

## まとめ

Phase 2の詳細設計では、Radiko APIとの完全な連携を実現するための包括的な設計を行いました。認証フロー、番組表取得、深夜番組対応、キャッシュ機構を含む、堅牢なデータ管理システムの構築を目指します。

**主要な設計ポイント**:
1. **認証処理**: auth1/auth2の2段階認証フローの実装
2. **XMLパース**: 放送局・番組データの確実な取得
3. **深夜番組対応**: 25時間表記と日付処理の適切な実装
4. **キャッシュ戦略**: 6時間更新による効率的なデータ管理
5. **エラーハンドリング**: リトライ機構を含む堅牢な処理

**次のステップ**: この設計に基づいてPhase 2テスト仕様書を作成し、TDD開発の準備を整えます。