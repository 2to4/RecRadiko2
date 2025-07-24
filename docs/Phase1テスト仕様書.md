# RecRadiko2 Phase 1 テスト仕様書
## UI・基盤テスト

**作成日**: 2025年7月24日  
**バージョン**: 1.0  
**対象フェーズ**: Phase 1 - 基盤構築・UI実装  
**テストフレームワーク**: Swift Testing, XCTest

## 1. テスト概要

### 1.1 テスト目標
Phase 1で実装するUI基盤、ViewModel、共通コンポーネントの動作確認と品質保証を目的とします。TDD手法に基づき、実装前にテストケースを定義し、継続的な品質向上を図ります。

### 1.2 テスト範囲
- **UIコンポーネントテスト**: 各UIコンポーネントの表示・動作確認
- **ViewModelテスト**: 状態管理とビジネスロジックの確認
- **ナビゲーションテスト**: 画面遷移とタブ切り替えの確認
- **状態管理テスト**: AppStorageと@Publishedの動作確認

### 1.3 除外範囲
- Radiko API連携テスト（Phase 2で実装）
- 実際の録音機能テスト（Phase 3で実装）
- パフォーマンステスト（Phase 4で実装）

## 2. テスト戦略

### 2.1 テストレベル別戦略

#### ユニットテスト（Swift Testing）
- **対象**: ViewModel, Model, Utility
- **方針**: 単一機能の動作確認、境界値テスト
- **カバレッジ目標**: 90%以上

#### 統合テスト（Swift Testing）
- **対象**: ViewModel-View間連携、状態同期
- **方針**: コンポーネント間の協調動作確認
- **カバレッジ目標**: 85%以上

#### UIテスト（XCTest）
- **対象**: 画面遷移、ユーザーインタラクション
- **方針**: エンドツーエンドシナリオテスト
- **カバレッジ目標**: 主要ユーザーフロー100%

### 2.2 TDDサイクル適用

```
1. テストリスト作成 → 2. Red（失敗テスト） → 3. Green（最小実装） → 4. Refactor → 5. Repeat
```

**適用原則**:
- 実装前に必ずテストケース作成
- 1つの機能につき1つのテストから開始
- 失敗を確認してから実装開始
- リファクタリング時のテスト維持

## 3. モックデータ・テストデータ仕様

### 3.1 テストデータ設計

#### 3.1.1 MockRadioStation
```swift
extension RadioStation {
    static let mockTBS = RadioStation(
        id: "TBS",
        name: "TBSラジオ",
        displayName: "TBS",
        logoURL: "https://mock.example.com/tbs.png",
        areaId: "JP13"
    )
    
    static let mockQRR = RadioStation(
        id: "QRR", 
        name: "文化放送",
        displayName: "QRR",
        logoURL: "https://mock.example.com/qrr.png",
        areaId: "JP13"
    )
    
    static let mockStations = [mockTBS, mockQRR]
    static let emptyStations: [RadioStation] = []
}
```

#### 3.1.2 MockRadioProgram
```swift
extension RadioProgram {
    static let mockMorningShow = RadioProgram(
        id: "prog_001",
        title: "モーニングテスト番組",
        description: "テスト用朝番組",
        startTime: Date().setTime(hour: 6, minute: 0),
        endTime: Date().setTime(hour: 9, minute: 0),
        personalities: ["テストパーソナリティA"],
        stationId: "TBS"
    )
    
    static let mockLateNightShow = RadioProgram(
        id: "prog_002", 
        title: "深夜テスト番組",
        description: "25時間表記テスト用",
        startTime: Date().setTime(hour: 1, minute: 0), // 実際の25:00
        endTime: Date().setTime(hour: 3, minute: 0),   // 実際の27:00
        personalities: ["テストパーソナリティB"],
        stationId: "TBS"
    )
    
    static let mockPrograms = [mockMorningShow, mockLateNightShow]
}
```

#### 3.1.3 MockArea
```swift
extension Area {
    static let mockTokyo = Area(id: "JP13", name: "東京", displayName: "東京")
    static let mockKanagawa = Area(id: "JP14", name: "神奈川", displayName: "神奈川")
    static let mockAreas = [mockTokyo, mockKanagawa]
}
```

### 3.2 MockService実装

#### 3.2.1 MockRadikoAPIService
```swift
class MockRadikoAPIService: RadikoAPIServiceProtocol {
    var shouldReturnError = false
    var networkDelay: TimeInterval = 0.1
    var mockStations: [RadioStation] = RadioStation.mockStations
    var mockPrograms: [RadioProgram] = RadioProgram.mockPrograms
    
    func fetchStations(for areaId: String) async throws -> [RadioStation] {
        try await Task.sleep(nanoseconds: UInt64(networkDelay * 1_000_000_000))
        
        if shouldReturnError {
            throw APIError.networkError
        }
        
        return mockStations.filter { $0.areaId == areaId }
    }
    
    func fetchPrograms(stationId: String, date: Date) async throws -> [RadioProgram] {
        try await Task.sleep(nanoseconds: UInt64(networkDelay * 1_000_000_000))
        
        if shouldReturnError {
            throw APIError.networkError
        }
        
        return mockPrograms.filter { $0.stationId == stationId }
    }
}

enum APIError: Error {
    case networkError
    case parseError
    case unauthorized
}
```

## 4. ユニットテスト仕様

### 4.1 Model層テスト

#### 4.1.1 RadioStation Tests
```swift
import Testing
@testable import RecRadiko2

struct RadioStationTests {
    
    @Test("RadioStation初期化テスト")
    func testRadioStationInitialization() {
        // Given
        let id = "TBS"
        let name = "TBSラジオ"
        let displayName = "TBS"
        let logoURL = "https://example.com/logo.png"
        let areaId = "JP13"
        
        // When
        let station = RadioStation(
            id: id,
            name: name,
            displayName: displayName,
            logoURL: logoURL,
            areaId: areaId
        )
        
        // Then
        #expect(station.id == id)
        #expect(station.name == name)
        #expect(station.displayName == displayName)
        #expect(station.logoURL == logoURL)
        #expect(station.areaId == areaId)
    }
    
    @Test("RadioStation Identifiable準拠テスト")
    func testRadioStationIdentifiable() {
        // Given
        let station1 = RadioStation.mockTBS
        let station2 = RadioStation.mockQRR
        
        // When & Then
        #expect(station1.id != station2.id)
        #expect(station1.id == "TBS")
        #expect(station2.id == "QRR")
    }
    
    @Test("RadioStation Equatable準拠テスト")
    func testRadioStationEquatable() {
        // Given
        let station1 = RadioStation.mockTBS
        let station2 = RadioStation.mockTBS
        let station3 = RadioStation.mockQRR
        
        // When & Then
        #expect(station1 == station2)
        #expect(station1 != station3)
    }
}
```

#### 4.1.2 RadioProgram Tests
```swift
struct RadioProgramTests {
    
    @Test("深夜番組の25時間表記変換テスト")
    func testLateNightTimeDisplay() {
        // Given
        let lateNightProgram = RadioProgram.mockLateNightShow
        
        // When
        let displayTime = lateNightProgram.displayTime
        
        // Then
        #expect(displayTime == "25:00")
    }
    
    @Test("通常番組の時刻表示テスト") 
    func testNormalTimeDisplay() {
        // Given
        let morningProgram = RadioProgram.mockMorningShow
        
        // When
        let displayTime = morningProgram.displayTime
        
        // Then
        #expect(displayTime == "06:00")
    }
    
    @Test("番組時間長計算テスト")
    func testProgramDuration() {
        // Given
        let program = RadioProgram.mockMorningShow
        
        // When
        let duration = program.duration
        
        // Then
        #expect(duration == 10800) // 3時間 = 3 * 60 * 60
    }
}
```

### 4.2 ViewModel層テスト

#### 4.2.1 StationListViewModel Tests
```swift
@MainActor
struct StationListViewModelTests {
    
    @Test("初期状態テスト")
    func testInitialState() {
        // Given & When
        let viewModel = StationListViewModel()
        
        // Then
        #expect(viewModel.stations.isEmpty)
        #expect(viewModel.selectedArea == Area.tokyo)
        #expect(viewModel.isLoading == false)
    }
    
    @Test("放送局読み込み成功テスト")
    func testLoadStationsSuccess() async {
        // Given
        let mockService = MockRadikoAPIService()
        let viewModel = StationListViewModel(apiService: mockService)
        
        // When
        await viewModel.loadStations()
        
        // Then
        #expect(viewModel.stations.count == 2)
        #expect(viewModel.stations.contains { $0.id == "TBS" })
        #expect(viewModel.isLoading == false)
    }
    
    @Test("放送局読み込み失敗テスト")
    func testLoadStationsFailure() async {
        // Given
        let mockService = MockRadikoAPIService()
        mockService.shouldReturnError = true
        let viewModel = StationListViewModel(apiService: mockService)
        
        // When
        await viewModel.loadStations()
        
        // Then
        #expect(viewModel.stations.isEmpty)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.isLoading == false)
    }
    
    @Test("地域選択テスト")
    func testAreaSelection() async {
        // Given
        let viewModel = StationListViewModel()
        let kanagawa = Area.mockKanagawa
        
        // When
        await viewModel.selectArea(kanagawa)
        
        // Then
        #expect(viewModel.selectedArea == kanagawa)
    }
    
    @Test("放送局選択テスト")
    func testStationSelection() {
        // Given
        let viewModel = StationListViewModel()
        let station = RadioStation.mockTBS
        let expectation = Expectation()
        
        // Notification監視
        let cancellable = NotificationCenter.default.publisher(for: .stationSelected)
            .sink { notification in
                if let selectedStation = notification.object as? RadioStation {
                    #expect(selectedStation == station)
                    expectation.fulfill()
                }
            }
        
        // When
        viewModel.selectStation(station)
        
        // Then
        await expectation.fulfillment(timeout: 1.0)
        cancellable.cancel()
    }
}
```

#### 4.2.2 ProgramListViewModel Tests  
```swift
@MainActor
struct ProgramListViewModelTests {
    
    @Test("初期状態テスト")
    func testInitialState() {
        // Given & When
        let viewModel = ProgramListViewModel()
        
        // Then
        #expect(viewModel.currentStation == nil)
        #expect(viewModel.programs.isEmpty)
        #expect(viewModel.selectedProgram == nil)
        #expect(Calendar.current.isDate(viewModel.selectedDate, inSameDayAs: Date()))
    }
    
    @Test("利用可能日付計算テスト")
    func testAvailableDates() {
        // Given
        let viewModel = ProgramListViewModel()
        
        // When
        let availableDates = viewModel.availableDates
        
        // Then
        #expect(availableDates.count == 7)
        #expect(Calendar.current.isDate(availableDates[0], inSameDayAs: Date()))
        #expect(availableDates[6] < availableDates[0]) // 過去日付順
    }
    
    @Test("放送局設定テスト")
    func testSetStation() async {
        // Given
        let viewModel = ProgramListViewModel()
        let station = RadioStation.mockTBS
        
        // When
        await viewModel.setStation(station)
        
        // Then
        #expect(viewModel.currentStation == station)
        #expect(!viewModel.programs.isEmpty)
    }
    
    @Test("番組選択テスト")
    func testSelectProgram() {
        // Given
        let viewModel = ProgramListViewModel()
        let program = RadioProgram.mockMorningShow
        
        // When
        viewModel.selectProgram(program)
        
        // Then
        #expect(viewModel.selectedProgram == program)
    }
    
    @Test("録音開始通知テスト")
    func testStartRecording() {
        // Given
        let viewModel = ProgramListViewModel()
        let program = RadioProgram.mockMorningShow
        viewModel.selectProgram(program)
        let expectation = Expectation()
        
        // Notification監視
        let cancellable = NotificationCenter.default.publisher(for: .recordingStarted)
            .sink { notification in
                if let recordingProgram = notification.object as? RadioProgram {
                    #expect(recordingProgram == program)
                    expectation.fulfill()
                }
            }
        
        // When
        viewModel.startRecording()
        
        // Then
        await expectation.fulfillment(timeout: 1.0)
        cancellable.cancel()
    }
}
```

#### 4.2.3 SettingsViewModel Tests
```swift
@MainActor
struct SettingsViewModelTests {
    
    @Test("初期設定値テスト")
    func testInitialSettings() {
        // Given & When
        let viewModel = SettingsViewModel()
        
        // Then
        #expect(viewModel.saveDirectoryPath.contains("Desktop"))
        #expect(viewModel.premiumEmail.isEmpty)
        #expect(viewModel.premiumPassword.isEmpty)
    }
    
    @Test("保存先ディレクトリ更新テスト")
    func testUpdateSaveDirectory() {
        // Given
        let viewModel = SettingsViewModel()
        let newPath = "/Users/test/Documents"
        let url = URL(fileURLWithPath: newPath)
        
        // When
        viewModel.updateSaveDirectory(url)
        
        // Then
        #expect(viewModel.saveDirectoryPath == newPath)
    }
    
    @Test("プレミアム認証情報検証テスト - 有効")
    func testValidatePremiumCredentialsValid() {
        // Given
        let viewModel = SettingsViewModel()
        viewModel.premiumEmail = "test@example.com"
        viewModel.premiumPassword = "password123"
        
        // When
        let isValid = viewModel.validatePremiumCredentials()
        
        // Then
        #expect(isValid == true)
    }
    
    @Test("プレミアム認証情報検証テスト - 無効")
    func testValidatePremiumCredentialsInvalid() {
        // Given
        let viewModel = SettingsViewModel()
        // 空の認証情報
        
        // When
        let isValid = viewModel.validatePremiumCredentials()
        
        // Then
        #expect(isValid == false)
    }
}
```

#### 4.2.4 RecordingViewModel Tests
```swift
@MainActor
struct RecordingViewModelTests {
    
    @Test("初期状態テスト")
    func testInitialState() {
        // Given & When
        let viewModel = RecordingViewModel()
        
        // Then
        #expect(viewModel.isRecording == false)
        #expect(viewModel.recordingProgress == 0.0)
        #expect(viewModel.elapsedTime == 0)
        #expect(viewModel.currentProgram == nil)
    }
    
    @Test("録音開始テスト")
    func testStartRecording() {
        // Given
        let viewModel = RecordingViewModel()
        let program = RadioProgram.mockMorningShow
        
        // When
        viewModel.startRecording(program: program)
        
        // Then
        #expect(viewModel.isRecording == true)
        #expect(viewModel.currentProgram == program)
    }
    
    @Test("録音キャンセルテスト")
    func testCancelRecording() {
        // Given
        let viewModel = RecordingViewModel()
        let program = RadioProgram.mockMorningShow
        viewModel.startRecording(program: program)
        
        // When
        viewModel.cancelRecording()
        
        // Then
        #expect(viewModel.isRecording == false)
        #expect(viewModel.recordingProgress == 0.0)
        #expect(viewModel.elapsedTime == 0)
        #expect(viewModel.currentProgram == nil)
    }
    
    @Test("経過時間文字列変換テスト")
    func testElapsedTimeString() {
        // Given
        let viewModel = RecordingViewModel()
        
        // When & Then
        viewModel.elapsedTime = 0
        #expect(viewModel.elapsedTimeString == "00:00")
        
        viewModel.elapsedTime = 65 // 1分5秒
        #expect(viewModel.elapsedTimeString == "01:05")
        
        viewModel.elapsedTime = 3661 // 1時間1分1秒
        #expect(viewModel.elapsedTimeString == "61:01")
    }
}
```

### 4.3 Utility層テスト

#### 4.3.1 TimeConverter Tests
```swift
struct TimeConverterTests {
    
    @Test("25時間表記変換テスト - 深夜")
    func testConvertTo25HourFormat() {
        // Given
        let date = Date().setTime(hour: 1, minute: 30) // 01:30
        
        // When
        let result = TimeConverter.convertTo25HourFormat(date)
        
        // Then
        #expect(result == "25:30")
    }
    
    @Test("25時間表記変換テスト - 通常時間")
    func testConvertTo25HourFormatNormal() {
        // Given
        let date = Date().setTime(hour: 15, minute: 45) // 15:45
        
        // When
        let result = TimeConverter.convertTo25HourFormat(date)
        
        // Then
        #expect(result == "15:45")
    }
    
    @Test("実時刻から25時間表記への変換テスト")
    func testConvertFromRealTimeTo25Hour() {
        // Given
        let midnight = Date().setTime(hour: 0, minute: 0)   // 00:00 → 24:00
        let earlyMorning = Date().setTime(hour: 4, minute: 30) // 04:30 → 28:30
        let normal = Date().setTime(hour: 12, minute: 0)    // 12:00 → 12:00
        
        // When & Then
        #expect(TimeConverter.convertTo25HourFormat(midnight) == "24:00")
        #expect(TimeConverter.convertTo25HourFormat(earlyMorning) == "28:30")
        #expect(TimeConverter.convertTo25HourFormat(normal) == "12:00")
    }
    
    @Test("25時間表記から実時刻への変換テスト")
    func testConvertFrom25HourToRealTime() {
        // Given
        let baseDate = Date()
        
        // When & Then
        let result24 = TimeConverter.convertFrom25HourFormat("24:00", baseDate: baseDate)
        #expect(Calendar.current.component(.hour, from: result24) == 0)
        
        let result25 = TimeConverter.convertFrom25HourFormat("25:30", baseDate: baseDate)
        #expect(Calendar.current.component(.hour, from: result25) == 1)
        #expect(Calendar.current.component(.minute, from: result25) == 30)
    }
}
```

#### 4.3.2 FileNameSanitizer Tests
```swift
struct FileNameSanitizerTests {
    
    @Test("ファイル名禁止文字変換テスト")
    func testSanitizeFileName() {
        // Given
        let originalName = "テスト/番組<名>:録音*.mp3"
        
        // When
        let sanitized = FileNameSanitizer.sanitize(originalName)
        
        // Then
        #expect(sanitized == "テスト_番組_名__録音_.mp3")
        #expect(!sanitized.contains("/"))
        #expect(!sanitized.contains("<"))
        #expect(!sanitized.contains(">"))
        #expect(!sanitized.contains(":"))
        #expect(!sanitized.contains("*"))
    }
    
    @Test("空文字・nil処理テスト")
    func testSanitizeEmptyString() {
        // When & Then
        #expect(FileNameSanitizer.sanitize("") == "untitled")
        #expect(FileNameSanitizer.sanitize("   ") == "untitled")
    }
    
    @Test("ファイル名長制限テスト")
    func testFileNameLengthLimit() {
        // Given
        let longName = String(repeating: "あ", count: 300)
        
        // When
        let sanitized = FileNameSanitizer.sanitize(longName)
        
        // Then
        #expect(sanitized.count <= 255) // macOSファイル名制限
    }
}
```

## 5. 統合テスト仕様

### 5.1 ViewModel-View連携テスト

#### 5.1.1 StationListView Integration Tests
```swift
@MainActor
struct StationListViewIntegrationTests {
    
    @Test("放送局一覧表示統合テスト")
    func testStationListDisplay() async {
        // Given
        let mockService = MockRadikoAPIService()
        let viewModel = StationListViewModel(apiService: mockService)
        
        // When
        await viewModel.loadStations()
        
        // Then
        #expect(viewModel.stations.count == 2)
        #expect(viewModel.stations.first?.displayName == "TBS")
    }
    
    @Test("地域選択→放送局更新統合テスト")
    func testAreaChangeStationUpdate() async {
        // Given
        let mockService = MockRadikoAPIService()
        mockService.mockStations = [
            RadioStation(id: "OSK1", name: "大阪局1", displayName: "OSK1", logoURL: nil, areaId: "JP27")
        ]
        let viewModel = StationListViewModel(apiService: mockService)
        
        // When
        await viewModel.selectArea(Area(id: "JP27", name: "大阪", displayName: "大阪"))
        
        // Then
        #expect(viewModel.selectedArea.id == "JP27")
        #expect(viewModel.stations.count == 1)
        #expect(viewModel.stations.first?.areaId == "JP27")
    }
}
```

### 5.2 状態同期テスト

#### 5.2.1 AppStorage同期テスト
```swift
struct AppStorageSyncTests {
    
    @Test("設定変更自動保存テスト")
    func testSettingsAutoSave() {
        // Given
        let viewModel = SettingsViewModel()
        let testPath = "/Users/test/TestDirectory"
        
        // When
        viewModel.saveDirectoryPath = testPath
        
        // Then - AppStorageによる自動保存確認
        let newViewModel = SettingsViewModel()
        #expect(newViewModel.saveDirectoryPath == testPath)
    }
    
    @Test("地域設定永続化テスト")
    func testAreaPersistence() {
        // Given
        let viewModel = StationListViewModel()
        let kanagawa = Area.mockKanagawa
        
        // When
        viewModel.selectedArea = kanagawa
        
        // Then
        let newViewModel = StationListViewModel()
        #expect(newViewModel.selectedArea.id == kanagawa.id)
    }
}
```

### 5.3 Notification連携テスト

#### 5.3.1 画面間通信テスト
```swift
struct NotificationIntegrationTests {
    
    @Test("放送局選択→番組画面遷移テスト")
    func testStationSelectionNavigation() async {
        // Given
        let stationViewModel = StationListViewModel()
        let programViewModel = ProgramListViewModel()
        let station = RadioStation.mockTBS
        let expectation = Expectation()
        
        // Notification受信設定
        let cancellable = NotificationCenter.default.publisher(for: .stationSelected)
            .sink { notification in
                if let selectedStation = notification.object as? RadioStation {
                    Task { @MainActor in
                        await programViewModel.setStation(selectedStation)
                        #expect(programViewModel.currentStation == station)
                        expectation.fulfill()
                    }
                }
            }
        
        // When
        stationViewModel.selectStation(station)
        
        // Then
        await expectation.fulfillment(timeout: 2.0)
        cancellable.cancel()
    }
}
```

## 6. UIテスト仕様

### 6.1 画面遷移テストシナリオ

#### 6.1.1 基本ナビゲーションテスト
```swift
import XCTest

final class NavigationUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    func testTabBarNavigation() throws {
        // Given - アプリ起動時は放送局一覧画面
        let stationTab = app.buttons["ラジオ局を選ぶ"]
        let programTab = app.buttons["ラジオ局"] 
        let settingsTab = app.buttons["設定"]
        
        // When & Then - 各タブの切り替え確認
        XCTAssertTrue(stationTab.isSelected)
        
        programTab.tap()
        XCTAssertTrue(programTab.isSelected)
        XCTAssertFalse(stationTab.isSelected)
        
        settingsTab.tap()
        XCTAssertTrue(settingsTab.isSelected)
        XCTAssertFalse(programTab.isSelected)
        
        stationTab.tap()
        XCTAssertTrue(stationTab.isSelected)
        XCTAssertFalse(settingsTab.isSelected)
    }
    
    func testStationSelectionFlow() throws {
        // Given - 放送局一覧画面
        let stationGrid = app.scrollViews.firstMatch
        let tbsStation = stationGrid.buttons.matching(identifier: "TBS").firstMatch
        
        // When - 放送局選択
        XCTAssertTrue(tbsStation.exists)
        tbsStation.tap()
        
        // Then - 番組一覧画面に遷移
        let programTab = app.buttons["ラジオ局"]
        XCTAssertTrue(programTab.isSelected)
        
        let stationName = app.staticTexts["TBSラジオ"]
        XCTAssertTrue(stationName.exists)
    }
}
```

#### 6.1.2 設定画面UIテスト
```swift
final class SettingsUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    func testFileLocationSetting() throws {
        // Given - 設定画面に移動
        app.buttons["設定"].tap()
        
        // When - 保存先変更ボタンタップ
        let changeButton = app.buttons["変更"]
        XCTAssertTrue(changeButton.exists)
        changeButton.tap()
        
        // Then - ファイル選択ダイアログ表示確認
        let fileDialog = app.sheets.firstMatch
        XCTAssertTrue(fileDialog.waitForExistence(timeout: 3.0))
    }
    
    func testPremiumSettingsForm() throws {
        // Given - 設定画面
        app.buttons["設定"].tap()
        
        // When - プレミアム設定フォーム操作
        let emailField = app.textFields.matching(identifier: "premiumEmail").firstMatch
        let passwordField = app.secureTextFields.matching(identifier: "premiumPassword").firstMatch
        
        XCTAssertTrue(emailField.exists)
        XCTAssertTrue(passwordField.exists)
        
        emailField.tap()
        emailField.typeText("test@example.com")
        
        passwordField.tap()
        passwordField.typeText("testpassword")
        
        // Then - 入力値確認
        XCTAssertEqual(emailField.value as? String, "test@example.com")
    }
}
```

### 6.2 ユーザーインタラクションテスト

#### 6.2.1 放送局グリッドインタラクション
```swift
final class StationGridUITests: XCTestCase {
    
    func testStationCellHoverEffect() throws {
        // Note: macOSでのホバーエフェクトはXCUITestでは直接テストが困難
        // 代替として、要素の存在とアクセシビリティ属性を確認
        
        // Given
        app.launch()
        let stationGrid = app.scrollViews.firstMatch
        let stationCells = stationGrid.buttons.matching(NSPredicate(format: "identifier CONTAINS 'station_'"))
        
        // When & Then
        XCTAssertGreaterThan(stationCells.count, 0)
        
        let firstCell = stationCells.firstMatch
        XCTAssertTrue(firstCell.exists)
        XCTAssertTrue(firstCell.isHittable)
    }
    
    func testStationGridScrolling() throws {
        // Given
        app.launch()
        let stationGrid = app.scrollViews.firstMatch
        
        // When - 下方向スクロール
        stationGrid.swipeUp()
        
        // Then - スクロール動作確認（画面が変化することを確認）
        XCTAssertTrue(stationGrid.exists)
    }
}
```

#### 6.2.2 番組リストインタラクション
```swift
final class ProgramListUITests: XCTestCase {
    
    func testProgramSelection() throws {
        // Given - 番組一覧画面に移動
        app.launch()
        let stationGrid = app.scrollViews.firstMatch
        let tbsStation = stationGrid.buttons.matching(identifier: "TBS").firstMatch
        tbsStation.tap()
        
        // When - 番組選択
        let programList = app.tables.firstMatch
        let firstProgram = programList.cells.firstMatch
        XCTAssertTrue(firstProgram.waitForExistence(timeout: 3.0))
        firstProgram.tap()
        
        // Then - 選択状態確認
        let radioButton = firstProgram.images.matching(identifier: "circle.inset.filled").firstMatch
        XCTAssertTrue(radioButton.exists)
    }
    
    func testRecordingButtonEnabled() throws {
        // Given - 番組選択済み状態
        app.launch()
        // ... 番組選択まで ...
        
        // When & Then - 録音ボタンが有効
        let recordButton = app.buttons.matching(identifier: "record").firstMatch
        XCTAssertTrue(recordButton.exists)
        XCTAssertTrue(recordButton.isEnabled)
    }
}
```

## 7. モック・スタブ戦略

### 7.1 APIモック戦略

#### 7.1.1 成功パターンモック
```swift
class SuccessMockRadikoAPIService: RadikoAPIServiceProtocol {
    func fetchStations(for areaId: String) async throws -> [RadioStation] {
        // 成功レスポンスを即座に返す
        return RadioStation.mockStations.filter { $0.areaId == areaId }
    }
    
    func fetchPrograms(stationId: String, date: Date) async throws -> [RadioProgram] {
        return RadioProgram.mockPrograms.filter { $0.stationId == stationId }
    }
}
```

#### 7.1.2 エラーパターンモック
```swift
class ErrorMockRadikoAPIService: RadikoAPIServiceProtocol {
    let errorType: APIError
    
    init(errorType: APIError) {
        self.errorType = errorType
    }
    
    func fetchStations(for areaId: String) async throws -> [RadioStation] {
        throw errorType
    }
    
    func fetchPrograms(stationId: String, date: Date) async throws -> [RadioProgram] {
        throw errorType
    }
}
```

#### 7.1.3 遅延モック
```swift
class SlowMockRadikoAPIService: RadikoAPIServiceProtocol {
    let delay: TimeInterval
    
    init(delay: TimeInterval) {
        self.delay = delay
    }
    
    func fetchStations(for areaId: String) async throws -> [RadioStation] {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        return RadioStation.mockStations
    }
    
    func fetchPrograms(stationId: String, date: Date) async throws -> [RadioProgram] {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        return RadioProgram.mockPrograms
    }
}
```

### 7.2 テスト環境設定

#### 7.2.1 テスト用DI Container
```swift
class TestContainer {
    static func createStationListViewModel(
        with mockService: RadikoAPIServiceProtocol = SuccessMockRadikoAPIService()
    ) -> StationListViewModel {
        return StationListViewModel(apiService: mockService)
    }
    
    static func createProgramListViewModel(
        with mockService: RadikoAPIServiceProtocol = SuccessMockRadikoAPIService()
    ) -> ProgramListViewModel {
        return ProgramListViewModel(apiService: mockService)
    }
}
```

#### 7.2.2 テストデータクリーンアップ
```swift
class TestDataManager {
    static func clearAppStorage() {
        UserDefaults.standard.removeObject(forKey: "saveDirectoryPath")
        UserDefaults.standard.removeObject(forKey: "selectedAreaId")
        UserDefaults.standard.removeObject(forKey: "premiumEmail")
        UserDefaults.standard.removeObject(forKey: "premiumPassword")
    }
    
    static func setupTestDefaults() {
        UserDefaults.standard.set("~/Desktop/TestRecordings", forKey: "saveDirectoryPath")
        UserDefaults.standard.set("JP13", forKey: "selectedAreaId")
    }
}
```

## 8. テスト実行・継続的統合

### 8.1 テスト実行戦略

#### テスト実行順序
1. **ユニットテスト**: 最優先、高速実行
2. **統合テスト**: 中優先、中速実行  
3. **UIテスト**: 低優先、低速実行

#### パラレル実行設定
```swift
// Swift Testingのパラレル実行設定
@Test(.serialized) // 順次実行が必要なテスト
func testAppStorageModification() {
    // AppStorage変更テストは順次実行
}

@Test // 並列実行可能なテスト（デフォルト）
func testModelInitialization() {
    // Modelの初期化テストは並列実行可能
}
```

### 8.2 テストカバレッジ監視

#### カバレッジ目標
- **Model層**: 95%以上
- **ViewModel層**: 90%以上
- **View層**: 60%以上（宣言的UIのため）
- **Utility層**: 95%以上

#### 未カバー部分の対応
```swift
// テストが困難な部分は明示的にマーク
// swiftlint:disable:next unavailable_function
private func untestableSystemCall() {
    // システムコール等、テストが困難な処理
}
```

### 8.3 継続的品質監視

#### テスト失敗時の対応
1. **Red状態の維持**: 失敗テストは即座に修正
2. **リグレッション防止**: 新機能追加時の既存テスト確認
3. **テストメンテナンス**: 仕様変更時のテスト同期更新

#### 品質ゲート
- すべてのテストが成功しない限り、次フェーズに進まない
- カバレッジ目標未達成の場合は実装を見直し
- UIテスト失敗時は実装とテストの両方を検証

---

## まとめ

Phase 1テスト仕様書では、UI基盤とViewModel層の品質保証を目的とした包括的なテスト戦略を定義しました。TDD手法に基づく段階的なテスト実装により、堅牢な基盤構築を目指します。

**次のステップ**: この仕様に基づいてテストケースを実装し、TDDサイクルを開始してPhase 1の実装に取りかかります。