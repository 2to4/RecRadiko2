# RecRadiko2 Phase 2テスト仕様書
## API連携・データ管理テスト仕様

**作成日**: 2025年7月25日  
**バージョン**: 1.0  
**対象フェーズ**: Phase 2 - API連携・データ管理  
**テストフレームワーク**: Swift Testing + XCTest  
**期間**: 3週間

## 1. テスト戦略概要

### 1.1 テスト目標
- **API通信の信頼性**: Radiko APIとの安定した通信
- **データ変換の正確性**: XML→Modelオブジェクト変換の検証
- **認証フローの堅牢性**: auth1/auth2の2段階認証テスト
- **キャッシュ機構の効率性**: データ永続化とキャッシュ戦略の検証

### 1.2 テスト範囲

#### テスト対象
- **認証サービス**: RadikoAuthService
- **APIサービス**: RadikoAPIService
- **XMLパーサー**: RadikoXMLParser
- **キャッシュサービス**: CacheService
- **時刻変換**: TimeConverter
- **データモデル**: RadioStation, RadioProgram

#### テスト除外範囲
- **実際のネットワーク通信**: モックサーバーで代替
- **macOSシステム機能**: 統合テストで検証
- **UIテスト**: Phase 2では除外（実装完了後に実施）

### 1.3 テスト種別

```
ユニットテスト （Swift Testing）
├── Model層テスト: データ構造とロジック
├── Service層テスト: API通信とキャッシュ
├── Utility層テスト: 時刻変換と共通処理
└── ViewModel層テスト: 状態管理とビジネスロジック

統合テスト （Swift Testing）
├── API統合テスト: エンドツーエンドの通信
├── キャッシュ統合テスト: ファイルシステム連携
└── 認証統合テスト: 認証フロー全体

モック・スタブテスト
├── モックAPIサーバー: 実APIの模擬
├── ネットワークモック: 通信状態の模擬
└── ファイルシステムモック: ディスク操作の模擬
```

## 2. ユニットテスト仕様

### 2.1 認証サービステスト (RadikoAuthService)

#### 2.1.1 正常系テストケース

```swift
import Testing
import Foundation
@testable import RecRadiko2

@Suite("RadikoAuthService Tests")
struct RadikoAuthServiceTests {
    
    @Test("認証成功 - auth1からauth2までの完全なフロー")
    func authenticateSuccess() async throws {
        // Given
        let mockHTTPClient = MockHTTPClient()
        mockHTTPClient.setupAuth1Success()
        mockHTTPClient.setupAuth2Success()
        
        let authService = RadikoAuthService(httpClient: mockHTTPClient)
        
        // When
        let authInfo = try await authService.authenticate()
        
        // Then
        #expect(authInfo.authToken.isEmpty == false)
        #expect(authInfo.areaId == "JP13")
        #expect(authInfo.areaName == "東京都")
        #expect(authInfo.isValid == true)
    }
    
    @Test("キャッシュされた認証情報の使用")
    func useCachedAuthInfo() async throws {
        // Given
        let mockHTTPClient = MockHTTPClient()
        let authService = RadikoAuthService(httpClient: mockHTTPClient)
        
        // 有効な認証情報をキャッシュに保存
        let cachedAuth = AuthInfo(
            authToken: "cached_token",
            areaId: "JP13",
            areaName: "東京都",
            expiresAt: Date().addingTimeInterval(3600)
        )
        authService.saveCachedAuth(cachedAuth)
        
        // When
        let authInfo = try await authService.authenticate()
        
        // Then
        #expect(authInfo.authToken == "cached_token")
        #expect(mockHTTPClient.requestCount == 0) // HTTP呼び出しなし
    }
    
    @Test("パーシャルキーの正確な抽出")
    func extractPartialKeyCorrectly() {
        // Given
        let authService = RadikoAuthService()
        let authToken = "dGVzdF9hdXRoX3Rva2VuX2Rh dGE="
        let offset = 8
        let length = 16
        
        // When
        let partialKey = authService.extractPartialKey(
            from: authToken,
            offset: offset,
            length: length
        )
        
        // Then
        #expect(partialKey.isEmpty == false)
        #expect(partialKey.count > 0)
    }
}
```

#### 2.1.2 異常系テストケース

```swift
@Suite("RadikoAuthService Error Tests")
struct RadikoAuthServiceErrorTests {
    
    @Test("auth1通信失敗時のエラーハンドリング")
    func auth1NetworkError() async throws {
        // Given
        let mockHTTPClient = MockHTTPClient()
        mockHTTPClient.setupNetworkError()
        
        let authService = RadikoAuthService(httpClient: mockHTTPClient)
        
        // When & Then
        await #expect(throws: HTTPError.networkError) {
            try await authService.authenticate()
        }
    }
    
    @Test("認証トークンの有効期限切れ")
    func expiredAuthToken() async throws {
        // Given
        let mockHTTPClient = MockHTTPClient()
        let authService = RadikoAuthService(httpClient: mockHTTPClient)
        
        // 期限切れの認証情報をキャッシュに保存
        let expiredAuth = AuthInfo(
            authToken: "expired_token",
            areaId: "JP13",
            areaName: "東京都",
            expiresAt: Date().addingTimeInterval(-3600) // 1時間前
        )
        authService.saveCachedAuth(expiredAuth)
        
        // 新しい認証のためのモック設定
        mockHTTPClient.setupAuth1Success()
        mockHTTPClient.setupAuth2Success()
        
        // When
        let authInfo = try await authService.authenticate()
        
        // Then
        #expect(authInfo.authToken != "expired_token")
        #expect(authInfo.isValid == true)
        #expect(mockHTTPClient.requestCount > 0) // 新しいHTTP呼び出しあり
    }
    
    @Test("地域制限エラーの処理")
    func areaRestrictedError() async throws {
        // Given
        let mockHTTPClient = MockHTTPClient()
        mockHTTPClient.setupAuth2AreaRestricted()
        
        let authService = RadikoAuthService(httpClient: mockHTTPClient)
        
        // When & Then
        await #expect(throws: RadikoError.areaRestricted) {
            try await authService.authenticate()
        }
    }
}
```

### 2.2 XMLパーサーテスト (RadikoXMLParser)

#### 2.2.1 放送局リストパーステスト

```swift
@Suite("RadikoXMLParser Station Tests")
struct RadikoXMLParserStationTests {
    
    @Test("放送局XMLの正常パース")
    func parseStationListXML() throws {
        // Given
        let xmlString = """
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
        </stations>
        """
        
        let xmlData = xmlString.data(using: .utf8)!
        let parser = RadikoXMLParser()
        
        // When
        let stations = try parser.parseStationList(from: xmlData)
        
        // Then
        #expect(stations.count == 2)
        
        let tbsStation = stations.first { $0.id == "TBS" }
        #expect(tbsStation?.name == "TBSラジオ")
        #expect(tbsStation?.displayName == "TBS RADIO")
        #expect(tbsStation?.areaId == "JP13")
        #expect(tbsStation?.logoURL == "https://example.com/tbs_logo.png")
        
        let qrrStation = stations.first { $0.id == "QRR" }
        #expect(qrrStation?.name == "文化放送")
        #expect(qrrStation?.displayName == "JOQR")
    }
    
    @Test("不正な放送局XMLのエラーハンドリング")
    func parseInvalidStationXML() throws {
        // Given
        let invalidXMLString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <invalid_root>
            <wrong_structure>
        """
        
        let xmlData = invalidXMLString.data(using: .utf8)!
        let parser = RadikoXMLParser()
        
        // When & Then
        #expect(throws: ParsingError.invalidXML) {
            try parser.parseStationList(from: xmlData)
        }
    }
}
```

#### 2.2.2 番組リストパーステスト

```swift
@Suite("RadikoXMLParser Program Tests")
struct RadikoXMLParserProgramTests {
    
    @Test("番組XMLの正常パース")
    func parseProgramListXML() throws {
        // Given
        let xmlString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <radiko>
            <stations>
                <station id="TBS">
                    <progs>
                        <date>20250725</date>
                        <prog id="prog_001" ft="20250725220000" to="20250726000000" ts="1" station_id="TBS">
                            <title>荻上チキ・Session</title>
                            <info>平日22時から放送中のニュース番組</info>
                            <pfm>荻上チキ,南部広美</pfm>
                            <img>https://example.com/program_image.jpg</img>
                        </prog>
                        <prog id="prog_002" ft="20250726010000" to="20250726020000" ts="1" station_id="TBS">
                            <title>深夜番組テスト</title>
                            <info>深夜1時の番組</info>
                            <pfm>深夜パーソナリティ</pfm>
                        </prog>
                    </progs>
                </station>
            </stations>
        </radiko>
        """
        
        let xmlData = xmlString.data(using: .utf8)!
        let parser = RadikoXMLParser()
        
        // When
        let programs = try parser.parseProgramList(from: xmlData)
        
        // Then
        #expect(programs.count == 2)
        
        let sessionProgram = programs.first { $0.id == "prog_001" }
        #expect(sessionProgram?.title == "荻上チキ・Session")
        #expect(sessionProgram?.personalities == ["荻上チキ", "南部広美"])
        #expect(sessionProgram?.isTimeFree == true)
        #expect(sessionProgram?.stationId == "TBS")
        
        let midnightProgram = programs.first { $0.id == "prog_002" }
        #expect(midnightProgram?.title == "深夜番組テスト")
        #expect(midnightProgram?.isMidnightProgram == true)
    }
    
    @Test("時刻フォーマットの処理")
    func parseTimeFormat() throws {
        // Given
        let xmlString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <radiko>
            <stations>
                <station id="TBS">
                    <progs>
                        <date>20250725</date>
                        <prog id="prog_001" ft="20250725220000" to="20250726000000" ts="1" station_id="TBS">
                            <title>テスト番組</title>
                        </prog>
                    </progs>
                </station>
            </stations>
        </radiko>
        """
        
        let xmlData = xmlString.data(using: .utf8)!
        let parser = RadikoXMLParser()
        
        // When
        let programs = try parser.parseProgramList(from: xmlData)
        
        // Then
        let program = programs.first!
        
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: program.startTime)
        #expect(startComponents.year == 2025)
        #expect(startComponents.month == 7)
        #expect(startComponents.day == 25)
        #expect(startComponents.hour == 22)
        #expect(startComponents.minute == 0)
        
        let endComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: program.endTime)
        #expect(endComponents.hour == 0) // 翌日0時
        #expect(endComponents.day == 26)
    }
}
```

### 2.3 キャッシュサービステスト (CacheService)

#### 2.3.1 基本キャッシュ操作テスト

```swift
@Suite("CacheService Tests")
struct CacheServiceTests {
    
    @Test("オブジェクトの保存と読み込み")
    func saveAndLoadObject() throws {
        // Given
        let cacheService = try CacheService()
        let testStations = [
            RadioStation(id: "TBS", name: "TBSラジオ", displayName: "TBS", logoURL: nil, areaId: "JP13"),
            RadioStation(id: "QRR", name: "文化放送", displayName: "QRR", logoURL: nil, areaId: "JP13")
        ]
        
        // When
        try cacheService.save(testStations, for: .stationList())
        let loadedStations: [RadioStation]? = try cacheService.load([RadioStation].self, for: .stationList())
        
        // Then
        #expect(loadedStations?.count == 2)
        #expect(loadedStations?[0].id == "TBS")
        #expect(loadedStations?[1].id == "QRR")
    }
    
    @Test("有効期限の処理")
    func expiredCacheHandling() throws {
        // Given
        let cacheService = try CacheService()
        let testData = ["test_data"]
        
        // 短い有効期限のキャッシュポリシー
        let shortPolicy = CachePolicy.stationList(expiration: 0.1) // 0.1秒
        
        // When
        try cacheService.save(testData, for: shortPolicy)
        
        // 有効期限まで待機
        Thread.sleep(forTimeInterval: 0.2)
        
        let loadedData: [String]? = try cacheService.load([String].self, for: shortPolicy)
        
        // Then
        #expect(loadedData == nil) // 期限切れのためnil
    }
    
    @Test("キャッシュの無効化")
    func invalidateCache() throws {
        // Given
        let cacheService = try CacheService()
        let testData = ["test_data"]
        let policy = CachePolicy.stationList()
        
        // When
        try cacheService.save(testData, for: policy)
        cacheService.invalidate(for: policy)
        let loadedData: [String]? = try cacheService.load([String].self, for: policy)
        
        // Then
        #expect(loadedData == nil)
    }
    
    @Test("全キャッシュの削除")
    func invalidateAllCache() throws {
        // Given
        let cacheService = try CacheService()
        let stationData = ["station_data"]
        let programData = ["program_data"]
        
        // When
        try cacheService.save(stationData, for: .stationList())
        try cacheService.save(programData, for: .programList())
        
        cacheService.invalidateAll()
        
        let loadedStationData: [String]? = try cacheService.load([String].self, for: .stationList())
        let loadedProgramData: [String]? = try cacheService.load([String].self, for: .programList())
        
        // Then
        #expect(loadedStationData == nil)
        #expect(loadedProgramData == nil)
    }
}
```

### 2.4 時刻変換テスト (TimeConverter)

#### 2.4.1 25時間表記変換テスト

```swift
@Suite("TimeConverter Tests")
struct TimeConverterTests {
    
    @Test("Radiko時刻文字列のパース")
    func parseRadikoTimeString() {
        // Given
        let timeString = "20250725220000" // 2025年7月25日 22時00分00秒
        
        // When
        let date = TimeConverter.parseRadikoTime(timeString)
        
        // Then
        #expect(date != nil)
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date!)
        #expect(components.year == 2025)
        #expect(components.month == 7)
        #expect(components.day == 25)
        #expect(components.hour == 22)
        #expect(components.minute == 0)
    }
    
    @Test("25時間表記フォーマット - 通常時間")
    func formatNormalTime() {
        // Given
        let calendar = Calendar.current
        let date = calendar.date(from: DateComponents(year: 2025, month: 7, day: 25, hour: 14, minute: 30))!
        
        // When
        let formattedTime = TimeConverter.formatProgramTime(date)
        
        // Then
        #expect(formattedTime == "14:30")
    }
    
    @Test("25時間表記フォーマット - 深夜時間")
    func formatMidnightTime() {
        // Given
        let calendar = Calendar.current
        let date = calendar.date(from: DateComponents(year: 2025, month: 7, day: 26, hour: 2, minute: 30))!
        
        // When
        let formattedTime = TimeConverter.formatProgramTime(date)
        
        // Then
        #expect(formattedTime == "26:30") // 2時30分 → 26時30分
    }
    
    @Test("番組の放送日取得 - 通常番組")
    func getProgramDateNormal() {
        // Given
        let calendar = Calendar.current
        let startTime = calendar.date(from: DateComponents(year: 2025, month: 7, day: 25, hour: 14, minute: 0))!
        let program = RadioProgram(
            id: "test",
            title: "テスト番組",
            description: nil,
            startTime: startTime,
            endTime: startTime.addingTimeInterval(3600),
            personalities: [],
            stationId: "TBS",
            imageURL: nil,
            isTimeFree: true
        )
        
        // When
        let programDate = TimeConverter.getProgramDate(program)
        
        // Then
        let programComponents = calendar.dateComponents([.year, .month, .day], from: programDate)
        #expect(programComponents.year == 2025)
        #expect(programComponents.month == 7)
        #expect(programComponents.day == 25)
    }
    
    @Test("番組の放送日取得 - 深夜番組")
    func getProgramDateMidnight() {
        // Given
        let calendar = Calendar.current
        let startTime = calendar.date(from: DateComponents(year: 2025, month: 7, day: 26, hour: 2, minute: 0))!
        let program = RadioProgram(
            id: "test",
            title: "深夜番組",
            description: nil,
            startTime: startTime,
            endTime: startTime.addingTimeInterval(3600),
            personalities: [],
            stationId: "TBS",
            imageURL: nil,
            isTimeFree: true
        )
        
        // When
        let programDate = TimeConverter.getProgramDate(program)
        
        // Then
        let programComponents = calendar.dateComponents([.year, .month, .day], from: programDate)
        #expect(programComponents.year == 2025)
        #expect(programComponents.month == 7)
        #expect(programComponents.day == 25) // 前日扱い
    }
    
    @Test("指定日の番組判定")
    func isProgramOnDate() {
        // Given
        let calendar = Calendar.current
        let targetDate = calendar.date(from: DateComponents(year: 2025, month: 7, day: 25))!
        
        // 深夜2時の番組（7/26 02:00だが7/25の番組扱い）
        let midnightTime = calendar.date(from: DateComponents(year: 2025, month: 7, day: 26, hour: 2, minute: 0))!
        let midnightProgram = RadioProgram(
            id: "midnight",
            title: "深夜番組",
            description: nil,
            startTime: midnightTime,
            endTime: midnightTime.addingTimeInterval(3600),
            personalities: [],
            stationId: "TBS",
            imageURL: nil,
            isTimeFree: true
        )
        
        // When & Then
        #expect(TimeConverter.isProgramOnDate(midnightProgram, date: targetDate) == true)
    }
}
```

### 2.5 データモデルテスト

#### 2.5.1 RadioProgramモデルテスト

```swift
@Suite("RadioProgram Model Tests")
struct RadioProgramTests {
    
    @Test("番組継続時間の計算")
    func programDuration() {
        // Given
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(3600) // 1時間後
        
        let program = RadioProgram(
            id: "test",
            title: "テスト番組",
            description: nil,
            startTime: startTime,
            endTime: endTime,
            personalities: [],
            stationId: "TBS",
            imageURL: nil,
            isTimeFree: true
        )
        
        // When & Then
        #expect(program.duration == 3600.0) // 1時間 = 3600秒
    }
    
    @Test("深夜番組の判定")
    func midnightProgramDetection() {
        // Given
        let calendar = Calendar.current
        let midnightTime = calendar.date(from: DateComponents(year: 2025, month: 7, day: 26, hour: 2, minute: 0))!
        
        let program = RadioProgram(
            id: "midnight",
            title: "深夜番組",
            description: nil,
            startTime: midnightTime,
            endTime: midnightTime.addingTimeInterval(3600),
            personalities: [],
            stationId: "TBS",
            imageURL: nil,
            isTimeFree: true
        )
        
        // When & Then
        #expect(program.isMidnightProgram == true)
    }
    
    @Test("表示時刻の取得")
    func displayTimeFormat() {
        // Given
        let calendar = Calendar.current
        let time = calendar.date(from: DateComponents(year: 2025, month: 7, day: 25, hour: 14, minute: 30))!
        
        let program = RadioProgram(
            id: "test",
            title: "テスト番組",
            description: nil,
            startTime: time,
            endTime: time.addingTimeInterval(3600),
            personalities: [],
            stationId: "TBS",
            imageURL: nil,
            isTimeFree: true
        )
        
        // When & Then
        #expect(program.displayTime == "14:30")
    }
}
```

## 3. 統合テスト仕様

### 3.1 API統合テスト

#### 3.1.1 認証からデータ取得まで

```swift
@Suite("API Integration Tests")
struct APIIntegrationTests {
    
    @Test("完全な認証フローから放送局取得まで")
    func fullAuthenticationAndStationFetch() async throws {
        // Given
        let mockHTTPClient = MockHTTPClient()
        mockHTTPClient.setupCompleteFlow()
        
        let cacheService = try CacheService()
        let apiService = RadikoAPIService(
            httpClient: mockHTTPClient,
            cacheService: cacheService
        )
        
        // When
        let authInfo = try await apiService.authenticate()
        let stations = try await apiService.fetchStations(for: authInfo.areaId)
        
        // Then
        #expect(authInfo.isValid == true)
        #expect(stations.count > 0)
        #expect(stations.allSatisfy { $0.areaId == authInfo.areaId })
    }
    
    @Test("番組表取得の統合テスト")
    func programFetchIntegration() async throws {
        // Given
        let mockHTTPClient = MockHTTPClient()
        mockHTTPClient.setupCompleteFlow()
        
        let cacheService = try CacheService()
        let apiService = RadikoAPIService(
            httpClient: mockHTTPClient,
            cacheService: cacheService
        )
        
        let testDate = Date()
        
        // When
        _ = try await apiService.authenticate()
        let programs = try await apiService.fetchPrograms(stationId: "TBS", date: testDate)
        
        // Then
        #expect(programs.count > 0)
        #expect(programs.allSatisfy { $0.stationId == "TBS" })
    }
}
```

### 3.2 キャッシュ統合テスト

```swift
@Suite("Cache Integration Tests")
struct CacheIntegrationTests {
    
    @Test("APIとキャッシュの連携")
    func apiCacheIntegration() async throws {
        // Given
        let mockHTTPClient = MockHTTPClient()
        mockHTTPClient.setupCompleteFlow()
        
        let cacheService = try CacheService()
        let apiService = RadikoAPIService(
            httpClient: mockHTTPClient,
            cacheService: cacheService
        )
        
        // When - 初回呼び出し
        _ = try await apiService.authenticate()
        let firstStations = try await apiService.fetchStations()
        
        // 2回目の呼び出し（キャッシュから取得されるはず）
        mockHTTPClient.resetRequestCount()
        let secondStations = try await apiService.fetchStations()
        
        // Then
        #expect(firstStations.count == secondStations.count)
        #expect(mockHTTPClient.stationListRequestCount == 0) // キャッシュから取得
    }
    
    @Test("ファイルシステム統合テスト")
    func fileSystemIntegration() throws {
        // Given
        let cacheService = try CacheService()
        let testData = "テストデータ"
        let policy = CachePolicy.stationList()
        
        // When
        try cacheService.save(testData, for: policy)
        
        // 新しいインスタンスでも読み込み可能か確認
        let newCacheService = try CacheService()
        let loadedData: String? = try newCacheService.load(String.self, for: policy)
        
        // Then
        #expect(loadedData == testData)
    }
}
```

## 4. ViewModelテスト仕様

### 4.1 StationListViewModelテスト

```swift
@Suite("StationListViewModel Tests")
struct StationListViewModelTests {
    
    @Test("放送局読み込み成功")
    @MainActor
    func loadStationsSuccess() async throws {
        // Given
        let mockAPIService = MockRadikoAPIService()
        mockAPIService.setupStationsSuccess()
        
        let viewModel = StationListViewModel()
        viewModel.apiService = mockAPIService
        
        // When
        await viewModel.loadStations()
        
        // Then
        #expect(viewModel.stations.count > 0)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }
    
    @Test("地域変更時の放送局更新")
    @MainActor
    func areaChangeStationUpdate() async throws {
        // Given
        let mockAPIService = MockRadikoAPIService()
        mockAPIService.setupStationsSuccess()
        
        let viewModel = StationListViewModel()
        viewModel.apiService = mockAPIService
        
        // When
        viewModel.selectArea(Area.osaka)
        
        // 少し待機してから状態確認
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        // Then
        #expect(viewModel.selectedArea == Area.osaka)
        #expect(mockAPIService.fetchStationsCallCount > 0)
    }
    
    @Test("放送局選択時の通知送信")
    @MainActor
    func stationSelectionNotification() async throws {
        // Given
        let viewModel = StationListViewModel()
        let testStation = RadioStation(
            id: "TBS", 
            name: "TBSラジオ", 
            displayName: "TBS", 
            logoURL: nil, 
            areaId: "JP13"
        )
        
        var receivedStation: RadioStation?
        let expectation = expectation(description: "Station selection notification")
        
        NotificationCenter.default.addObserver(forName: .stationSelected, object: nil, queue: .main) { notification in
            receivedStation = notification.object as? RadioStation
            expectation.fulfill()
        }
        
        // When
        viewModel.selectStation(testStation)
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        #expect(receivedStation?.id == "TBS")
    }
}
```

### 4.2 ProgramListViewModelテスト

```swift
@Suite("ProgramListViewModel Tests")
struct ProgramListViewModelTests {
    
    @Test("番組表読み込みと深夜番組処理")
    @MainActor
    func loadProgramsWithMidnightHandling() async throws {
        // Given
        let mockAPIService = MockRadikoAPIService()
        mockAPIService.setupProgramsWithMidnight()
        
        let viewModel = ProgramListViewModel()
        viewModel.apiService = mockAPIService
        
        let testStation = RadioStation(
            id: "TBS", 
            name: "TBSラジオ", 
            displayName: "TBS", 
            logoURL: nil, 
            areaId: "JP13"
        )
        
        // When
        viewModel.setStation(testStation)
        await viewModel.loadPrograms()
        
        // Then
        #expect(viewModel.programs.count > 0)
        
        // 深夜番組の正しい処理を確認
        let midnightPrograms = viewModel.programs.filter { $0.isMidnightProgram }
        #expect(midnightPrograms.count > 0)
        
        // 25時間表記の確認
        let midnightProgram = midnightPrograms.first!
        #expect(midnightProgram.displayTime.hasPrefix("2")) // 24時以降の表記
    }
    
    @Test("日付選択時の番組フィルタリング")
    @MainActor
    func dateSelectionFiltering() async throws {
        // Given
        let mockAPIService = MockRadikoAPIService()
        mockAPIService.setupProgramsWithMidnight()
        
        let viewModel = ProgramListViewModel()
        viewModel.apiService = mockAPIService
        
        let testStation = RadioStation(
            id: "TBS", 
            name: "TBSラジオ", 
            displayName: "TBS", 
            logoURL: nil, 
            areaId: "JP13"
        )
        
        // When
        viewModel.setStation(testStation)
        await viewModel.loadPrograms()
        
        let targetDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        viewModel.selectDate(targetDate)
        
        // Then
        let filteredPrograms = viewModel.programsForDate(targetDate)
        #expect(filteredPrograms.count >= 0)
        
        // すべての番組が指定日のものであることを確認
        for program in filteredPrograms {
            #expect(TimeConverter.isProgramOnDate(program, date: targetDate))
        }
    }
}
```

## 5. モック・スタブ仕様

### 5.1 モックHTTPクライアント

```swift
class MockHTTPClient: HTTPClientProtocol {
    var requestCount = 0
    var stationListRequestCount = 0
    var programListRequestCount = 0
    
    private var auth1Response: Data?
    private var auth2Response: Data?
    private var stationListResponse: Data?
    private var programListResponse: Data?
    private var shouldThrowError = false
    private var errorToThrow: Error = HTTPError.networkError(NSError())
    
    func setupAuth1Success() {
        auth1Response = createMockAuth1Response()
    }
    
    func setupAuth2Success() {
        auth2Response = createMockAuth2Response()
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
        errorToThrow = HTTPError.networkError(NSError(domain: "Test", code: -1))
    }
    
    func resetRequestCount() {
        requestCount = 0
        stationListRequestCount = 0
        programListRequestCount = 0
    }
    
    // MARK: - HTTPClientProtocol
    
    func request<T: Decodable>(_ endpoint: URL, 
                               method: HTTPMethod, 
                               headers: [String: String]?, 
                               body: Data?) async throws -> T {
        let data = try await requestData(endpoint, method: method, headers: headers, body: body)
        return try JSONDecoder().decode(T.self, from: data)
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
        
        switch {
        case urlString.contains("auth1"):
            return auth1Response ?? Data()
        case urlString.contains("auth2"):
            return auth2Response ?? Data()
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
    
    // MARK: - Mock Data Creation
    
    private func createMockAuth1Response() -> Data {
        return "X-Radiko-AuthToken: mock_auth_token\r\nX-Radiko-KeyOffset: 8\r\nX-Radiko-KeyLength: 16".data(using: .utf8)!
    }
    
    private func createMockAuth2Response() -> Data {
        return "JP13,東京都".data(using: .utf8)!
    }
    
    private func createMockStationListXML() -> Data {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <stations area_id="JP13" area_name="東京都">
            <station id="TBS" area_id="JP13">
                <name>TBSラジオ</name>
                <ascii_name>TBS RADIO</ascii_name>
                <logo>https://example.com/tbs_logo.png</logo>
            </station>
            <station id="QRR" area_id="JP13">
                <name>文化放送</name>
                <ascii_name>JOQR</ascii_name>
                <logo>https://example.com/qrr_logo.png</logo>
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
                            <info>平日22時から放送中</info>
                            <pfm>荻上チキ,南部広美</pfm>
                        </prog>
                        <prog id="prog_002" ft="\(dateString)010000" to="\(dateString)020000" ts="1" station_id="TBS">
                            <title>深夜番組</title>
                            <info>深夜1時の番組</info>
                            <pfm>深夜パーソナリティ</pfm>
                        </prog>
                    </progs>
                </station>
            </stations>
        </radiko>
        """
        return xml.data(using: .utf8)!
    }
}
```

### 5.2 モックAPIサービス

```swift
class MockRadikoAPIService: RadikoAPIServiceProtocol {
    var fetchStationsCallCount = 0
    var fetchProgramsCallCount = 0
    
    private var shouldSucceed = true
    private var errorToThrow: Error = RadikoError.networkError(NSError())
    
    func setupStationsSuccess() {
        shouldSucceed = true
    }
    
    func setupProgramsWithMidnight() {
        shouldSucceed = true
    }
    
    func setupNetworkError() {
        shouldSucceed = false
        errorToThrow = RadikoError.networkError(NSError())
    }
    
    // MARK: - RadikoAPIServiceProtocol
    
    func authenticate() async throws -> AuthInfo {
        if !shouldSucceed {
            throw errorToThrow
        }
        
        return AuthInfo(
            authToken: "mock_token",
            areaId: "JP13",
            areaName: "東京都",
            expiresAt: Date().addingTimeInterval(3600)
        )
    }
    
    func fetchStations(for areaId: String?) async throws -> [RadioStation] {
        fetchStationsCallCount += 1
        
        if !shouldSucceed {
            throw errorToThrow
        }
        
        return [
            RadioStation(id: "TBS", name: "TBSラジオ", displayName: "TBS", logoURL: nil, areaId: areaId ?? "JP13"),
            RadioStation(id: "QRR", name: "文化放送", displayName: "QRR", logoURL: nil, areaId: areaId ?? "JP13")
        ]
    }
    
    func fetchPrograms(stationId: String, date: Date) async throws -> [RadioProgram] {
        fetchProgramsCallCount += 1
        
        if !shouldSucceed {
            throw errorToThrow
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        
        return [
            RadioProgram(
                id: "prog_001",
                title: "荻上チキ・Session",
                description: "平日22時から放送中",
                startTime: calendar.date(byAdding: .hour, value: 22, to: today)!,
                endTime: calendar.date(byAdding: .hour, value: 24, to: today)!,
                personalities: ["荻上チキ", "南部広美"],
                stationId: stationId,
                imageURL: nil,
                isTimeFree: true
            ),
            RadioProgram(
                id: "prog_002",
                title: "深夜番組",
                description: "深夜1時の番組",
                startTime: calendar.date(byAdding: .hour, value: 25, to: today)!, // 翌日1時
                endTime: calendar.date(byAdding: .hour, value: 26, to: today)!,   // 翌日2時
                personalities: ["深夜パーソナリティ"],
                stationId: stationId,
                imageURL: nil,
                isTimeFree: true
            )
        ]
    }
    
    func fetchWeeklyPrograms(stationId: String) async throws -> [RadioProgram] {
        return try await fetchPrograms(stationId: stationId, date: Date())
    }
}
```

## 6. 異常系テスト仕様

### 6.1 ネットワークエラーテスト

```swift
@Suite("Network Error Tests")
struct NetworkErrorTests {
    
    @Test("認証中のネットワーク断絶")
    func authenticationNetworkFailure() async throws {
        // Given
        let mockHTTPClient = MockHTTPClient()
        mockHTTPClient.setupNetworkError()
        
        let authService = RadikoAuthService(httpClient: mockHTTPClient)
        
        // When & Then
        await #expect(throws: HTTPError.networkError) {
            try await authService.authenticate()
        }
    }
    
    @Test("データ取得中のタイムアウト")
    func dataFetchTimeout() async throws {
        // Given
        let timeoutHTTPClient = TimeoutMockHTTPClient(delay: 5.0) // 5秒遅延
        let apiService = RadikoAPIService(httpClient: timeoutHTTPClient)
        
        // When & Then
        await #expect(throws: HTTPError.networkError) {
            try await apiService.fetchStations()
        }
    }
    
    @Test("サーバーエラー応答の処理")
    func serverErrorHandling() async throws {
        // Given
        let mockHTTPClient = MockHTTPClient()
        mockHTTPClient.setupServerError(statusCode: 500)
        
        let apiService = RadikoAPIService(httpClient: mockHTTPClient)
        
        // When & Then
        await #expect(throws: HTTPError.serverError) {
            try await apiService.fetchStations()
        }
    }
}
```

### 6.2 データ破損テスト

```swift
@Suite("Data Corruption Tests")
struct DataCorruptionTests {
    
    @Test("破損したXMLデータの処理")
    func corruptedXMLHandling() throws {
        // Given
        let corruptedXML = "<?xml version=\"1.0\"<broken_structure>".data(using: .utf8)!
        let parser = RadikoXMLParser()
        
        // When & Then
        #expect(throws: ParsingError.invalidXML) {
            try parser.parseStationList(from: corruptedXML)
        }
    }
    
    @Test("不完全なAPIレスポンス")
    func incompleteAPIResponse() throws {
        // Given
        let incompleteXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <stations area_id="JP13">
            <station id="TBS">
                <!-- 必須フィールドが不足 -->
            </station>
        </stations>
        """.data(using: .utf8)!
        
        let parser = RadikoXMLParser()
        
        // When
        let stations = try parser.parseStationList(from: incompleteXML)
        
        // Then - パースは成功するが、フィールドが空になる
        #expect(stations.count == 1)
        #expect(stations[0].name.isEmpty)
    }
    
    @Test("キャッシュファイルの破損")
    func corruptedCacheFile() throws {
        // Given
        let cacheService = try CacheService()
        let policy = CachePolicy.stationList()
        
        // 破損したキャッシュファイルを直接作成
        let fileURL = cacheService.cacheFileURL(for: policy)
        let corruptedData = "broken_cache_data".data(using: .utf8)!
        try corruptedData.write(to: fileURL)
        
        // When & Then
        let loadedData: [RadioStation]? = try cacheService.load([RadioStation].self, for: policy)
        #expect(loadedData == nil) // 破損したキャッシュは無視される
    }
}
```

## 7. パフォーマンステスト仕様

### 7.1 レスポンス時間テスト

```swift
@Suite("Performance Tests")
struct PerformanceTests {
    
    @Test("大量データのパース性能")
    func largeProgramListParsing() throws {
        // Given - 1000件の番組データを含むXML
        let largeXML = createLargeProgramListXML(programCount: 1000)
        let parser = RadikoXMLParser()
        
        // When
        let startTime = Date()
        let programs = try parser.parseProgramList(from: largeXML)
        let endTime = Date()
        
        // Then - 1秒以内でパース完了
        let processingTime = endTime.timeIntervalSince(startTime)
        #expect(processingTime < 1.0)
        #expect(programs.count == 1000)
    }
    
    @Test("並列API呼び出し性能")
    func concurrentAPICalls() async throws {
        // Given
        let mockHTTPClient = MockHTTPClient()
        mockHTTPClient.setupCompleteFlow()
        
        let apiService = RadikoAPIService(httpClient: mockHTTPClient)
        let stationIds = ["TBS", "QRR", "LFR", "RN1", "RN2"]
        
        // When
        let startTime = Date()
        let results = try await apiService.fetchMultipleStationPrograms(
            stationIds: stationIds,
            date: Date()
        )
        let endTime = Date()
        
        // Then - 並列処理により短時間で完了
        let processingTime = endTime.timeIntervalSince(startTime)
        #expect(processingTime < 2.0) // 逐次処理より大幅に短縮
        #expect(results.count == stationIds.count)
    }
    
    @Test("キャッシュアクセス性能")
    func cacheAccessPerformance() throws {
        // Given
        let cacheService = try CacheService()
        let testData = Array(0..<10000).map { "data_\($0)" }
        let policy = CachePolicy.stationList()
        
        // 事前にキャッシュに保存
        try cacheService.save(testData, for: policy)
        
        // When - 100回連続でキャッシュアクセス
        let startTime = Date()
        for _ in 0..<100 {
            let _: [String]? = try cacheService.load([String].self, for: policy)
        }
        let endTime = Date()
        
        // Then - 0.1秒以内で完了
        let processingTime = endTime.timeIntervalSince(startTime)
        #expect(processingTime < 0.1)
    }
    
    private func createLargeProgramListXML(programCount: Int) -> Data {
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <radiko>
            <stations>
                <station id="TBS">
                    <progs>
                        <date>20250725</date>
        """
        
        for i in 0..<programCount {
            xml += """
                        <prog id="prog_\(i)" ft="20250725\(String(format: "%06d", i))" to="20250725\(String(format: "%06d", i + 100))" ts="1" station_id="TBS">
                            <title>番組\(i)</title>
                            <info>番組説明\(i)</info>
                            <pfm>パーソナリティ\(i)</pfm>
                        </prog>
            """
        }
        
        xml += """
                    </progs>
                </station>
            </stations>
        </radiko>
        """
        
        return xml.data(using: .utf8)!
    }
}
```

## 8. テスト実行戦略

### 8.1 テスト実行順序

```
1. ユニットテスト
   └── 各コンポーネント単体の動作確認
   
2. モック・スタブテスト
   └── モック実装の正確性確認
   
3. 統合テスト
   └── コンポーネント間連携確認
   
4. 異常系テスト
   └── エラーハンドリング確認
   
5. パフォーマンステスト
   └── 性能要件確認
```

### 8.2 継続的テスト

```swift
// Package.swift テスト設定例
// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "RecRadiko2",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "RecRadiko2", targets: ["RecRadiko2"])
    ],
    dependencies: [
        // テスト用依存関係
    ],
    targets: [
        .executableTarget(
            name: "RecRadiko2",
            dependencies: []
        ),
        .testTarget(
            name: "RecRadiko2Tests",
            dependencies: ["RecRadiko2"],
            resources: [
                .copy("MockData/")
            ]
        )
    ]
)
```

### 8.3 テストカバレッジ測定

```bash
# コードカバレッジ有効でテスト実行
xcodebuild test \
  -project RecRadiko2.xcodeproj \
  -scheme RecRadiko2Tests \
  -destination 'platform=macOS' \
  -enableCodeCoverage YES

# カバレッジレポート生成
xcrun xccov view --report --json DerivedData/RecRadiko2/Logs/Test/*.xcresult
```

## 9. テスト環境設定

### 9.1 テスト用設定

```swift
// テスト用設定クラス
class TestConfiguration {
    static let shared = TestConfiguration()
    
    let mockAPIBaseURL = "http://localhost:8080"
    let testCacheDirectory = "/tmp/RecRadiko2_test_cache"
    let networkTimeout: TimeInterval = 5.0
    
    private init() {}
    
    func setupTestEnvironment() {
        // テスト用キャッシュディレクトリクリア
        try? FileManager.default.removeItem(atPath: testCacheDirectory)
        
        // テスト用ネットワーク設定
        URLSession.shared.configuration.timeoutIntervalForRequest = networkTimeout
    }
    
    func tearDownTestEnvironment() {
        // テスト後のクリーンアップ
        try? FileManager.default.removeItem(atPath: testCacheDirectory)
    }
}
```

### 9.2 テストヘルパー

```swift
// テスト用ヘルパー関数
class TestHelpers {
    
    static func createTestRadioStation(id: String = "TEST") -> RadioStation {
        return RadioStation(
            id: id,
            name: "テスト放送局",
            displayName: "TEST",
            logoURL: "https://example.com/logo.png",
            areaId: "JP13"
        )
    }
    
    static func createTestRadioProgram(id: String = "TEST", 
                                      startHour: Int = 14) -> RadioProgram {
        let calendar = Calendar.current
        let today = Date()
        let startTime = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: today)!
        let endTime = calendar.date(byAdding: .hour, value: 1, to: startTime)!
        
        return RadioProgram(
            id: id,
            title: "テスト番組",
            description: "テスト用番組",
            startTime: startTime,
            endTime: endTime,
            personalities: ["テストパーソナリティ"],
            stationId: "TEST",
            imageURL: nil,
            isTimeFree: true
        )
    }
    
    static func waitForAsyncOperation(timeout: TimeInterval = 1.0) async {
        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
    }
}
```

---

## まとめ

Phase 2のテスト仕様書では、API連携とデータ管理機能に対する包括的なテスト戦略を定義しました。認証フロー、XMLパース、キャッシュ機構、深夜番組処理など、各コンポーネントの正確性と信頼性を確保するためのテストケースを網羅しています。

**主要なテストポイント**:
1. **認証フローテスト**: auth1/auth2の2段階認証の完全検証
2. **XMLパーステスト**: 放送局・番組データの正確な変換確認
3. **深夜番組テスト**: 25時間表記と日付処理の適切な実装確認
4. **キャッシュテスト**: データ永続化とキャッシュ戦略の効率性確認
5. **統合テスト**: API連携からデータ表示までのエンドツーエンド検証

**次のステップ**: このテスト仕様に基づいてTDD開発を開始し、実装とテストを並行して進めます。