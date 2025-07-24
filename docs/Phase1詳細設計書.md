# RecRadiko2 Phase 1 詳細設計書
## UI・基盤設計

**作成日**: 2025年7月24日  
**最終更新**: 2025年7月24日  
**バージョン**: 1.1 (ナビゲーション設計変更反映)  
**対象フェーズ**: Phase 1 - 基盤構築・UI実装  
**期間**: 2週間（事前設計2日 + 実装12日）

## 1. Phase 1 概要

### 1.1 目標
動作するUIプロトタイプの完成を目指し、全画面のレイアウトとナビゲーション、基本的な状態管理を実装します。

### 1.2 実装範囲
- **プロジェクト基盤**: Xcode設定、MVVM基盤、依存関係設定
- **UI実装**: 全4画面の基本レイアウト（モックデータ使用）
- **ナビゲーション**: タブバー、画面遷移ロジック
- **状態管理**: 基本的な状態管理基盤

### 1.3 除外範囲
- Radiko API連携（Phase 2で実装）
- 実際の録音機能（Phase 3で実装）
- エラーハンドリングの詳細（Phase 4で強化）

## 2. UIコンポーネント詳細設計

### 2.1 画面階層構造

```
ContentView (Root)
├── CustomTabBar (カスタムタブバー)
└── コンテンツエリア
    ├── StationListView (放送局一覧)
    ├── ProgramListView (番組一覧)
    └── SettingsView (設定)
└── RecordingProgressView (Sheet Modal)
```

**設計変更点**:
- macOS互換性のため、標準TabViewから独自CustomTabBarに変更
- NavigationViewStyleの問題を解決するため、カスタムナビゲーション実装
- NavigationManagerによる状態管理でタブ切り替えを制御

### 2.2 共通UIコンポーネント設計

#### 2.2.1 CustomTabBar
```swift
struct CustomTabBar: View {
    @Binding var selectedTab: TabItem
    
    enum TabItem: String, CaseIterable {
        case stationList = "ラジオ局を選ぶ"
        case program = "ラジオ局"
        case settings = "設定"
        
        var iconName: String {
            switch self {
            case .stationList: return "radio"
            case .program: return "list.bullet"
            case .settings: return "gearshape"
            }
        }
    }
}
```

**設計仕様**:
- **位置**: アプリケーション上部固定
- **高さ**: 50px固定
- **選択状態管理**: `@Binding var selectedTab`（ContentViewから制御）
- **スタイル**: 独自実装のフラットタブバー
- **アニメーション**: インディケーターの0.3秒スムーズ移動

#### 2.2.2 StationCell（放送局セル）
```swift
struct StationCell: View {
    let station: RadioStation
    @State private var isHovered: Bool = false
    
    var body: some View {
        VStack(spacing: 8) {
            // ロゴ画像 (120x80px)
            AsyncImage(url: URL(string: station.logoURL ?? "")) { image in
                image.resizable()
            } placeholder: {
                Rectangle()
                    .fill(Color(white: 0.3))
            }
            .frame(width: 120, height: 80)
            .cornerRadius(8)
            
            // 放送局名
            Text(station.displayName)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
```

**設計仕様**:
- **サイズ**: 120x80px（ロゴ部分）+ 8px間隔 + テキスト高
- **ホバーエフェクト**: 1.05倍拡大、0.2秒アニメーション
- **非同期画像読み込み**: AsyncImageによるレイジーローディング
- **プレースホルダー**: ロゴ未取得時のグレー矩形

#### 2.2.3 ProgramRow（番組行）
```swift
struct ProgramRow: View {
    let program: RadioProgram
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // ラジオボタン
            Image(systemName: isSelected ? "circle.inset.filled" : "circle")
                .foregroundColor(isSelected ? .blue : .gray)
                .frame(width: 16, height: 16)
            
            // 時刻表示
            Text(program.displayTime)
                .font(.system(size: 14, family: .monospaced))
                .foregroundColor(.gray)
                .frame(width: 50, alignment: .leading)
            
            // 番組名
            Text(program.title)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 32)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isSelected ? Color(white: 0.2) : Color.clear)
        .onTapGesture {
            onTap()
        }
    }
}
```

**設計仕様**:
- **高さ**: 32px固定
- **ラジオボタン**: システムアイコン使用、16x16px
- **時刻表示**: 等幅フォント、50px幅、左寄せ
- **番組名**: システムフォント、残り幅、行数制限1
- **選択状態**: 背景色変更による視覚フィードバック

### 2.3 各画面の詳細設計

#### 2.3.1 StationListView（放送局一覧画面）

```swift
struct StationListView: View {
    @StateObject private var viewModel = StationListViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // 説明セクション (200px固定高)
            explanationSection
            
            Divider()
            
            // 放送局グリッド
            stationGrid
        }
        .background(Color.black)
    }
    
    private var explanationSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            areaSelection
            explanationText
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(white: 0.15))
    }
    
    private var stationGrid: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 20) {
                ForEach(viewModel.stations) { station in
                    StationCell(station: station)
                        .onTapGesture {
                            viewModel.selectStation(station)
                        }
                }
            }
            .padding(20)
        }
        .background(Color(white: 0.1))
    }
}
```

**設計仕様**:
- **レイアウト**: VStack（説明部200px + 分割線 + スクロール部残り）
- **グリッド**: 5列固定、間隔20px
- **スクロール**: LazyVGridによる仮想化
- **背景色**: 説明部0.15、グリッド部0.1

#### 2.3.2 ProgramListView（番組一覧画面）

```swift
struct ProgramListView: View {
    @StateObject private var viewModel = ProgramListViewModel()
    
    var body: some View {
        HStack(spacing: 0) {
            // 左パネル (300px固定幅)
            leftPanel
            
            Divider()
            
            // 右パネル
            rightPanel
        }
        .background(Color.black)
    }
    
    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            // ヘッダー（戻るボタン + 放送局名）
            headerSection
            
            // 放送局ロゴ
            stationLogo
            
            // 番組詳細
            programDetails
            
            Spacer()
        }
        .frame(width: 300)
        .padding(20)
        .background(Color(white: 0.18))
    }
    
    private var rightPanel: some View {
        VStack(spacing: 0) {
            // 操作ボタンバー (50px)
            controlBar
            
            // 日付選択バー (40px)
            dateSelector
            
            // 番組リスト
            programList
        }
        .background(Color(white: 0.1))
    }
}
```

**設計仕様**:
- **レイアウト**: HStack（左300px + 分割線 + 右残り幅）
- **左パネル**: 固定幅、番組詳細表示
- **右パネル**: 可変幅、操作部50px + 日付部40px + リスト部残り
- **背景色**: 左0.18、右0.1

#### 2.3.3 SettingsView（設定画面）

```swift
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            // ファイル保存場所セクション
            fileLocationSection
            
            // ラジコプレミアムセクション
            premiumSection
            
            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(white: 0.15))
    }
    
    private var fileLocationSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("ファイル保存場所")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(spacing: 16) {
                Button("変更") {
                    viewModel.selectSaveDirectory()
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Text(viewModel.saveDirectoryPath)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
        }
    }
}
```

**設計仕様**:
- **レイアウト**: VStack、上部配置、40pxパディング
- **セクション間隔**: 30px
- **フォーム構造**: ラベル + 入力欄のペア構成
- **ボタンスタイル**: カスタムセカンダリボタンスタイル

#### 2.3.4 RecordingProgressView（録音進捗ポップアップ）

```swift
struct RecordingProgressView: View {
    @StateObject private var viewModel = RecordingViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            // タイトル
            Text("録音中...")
                .font(.title2)
                .foregroundColor(.white)
            
            // 番組名
            Text(viewModel.currentProgram?.title ?? "")
                .font(.headline)
                .foregroundColor(.gray)
            
            // プログレスバー
            ProgressView(value: viewModel.recordingProgress)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(width: 300)
            
            // 経過時間
            Text(viewModel.elapsedTimeString)
                .font(.title3)
                .fontDesign(.monospaced)
                .foregroundColor(.white)
            
            // キャンセルボタン
            Button("キャンセル") {
                viewModel.cancelRecording()
            }
            .buttonStyle(DangerButtonStyle())
        }
        .frame(width: 400, height: 250)
        .background(Color(white: 0.2))
        .cornerRadius(12)
        .shadow(radius: 10)
    }
}
```

**設計仕様**:
- **サイズ**: 400x250px固定
- **レイアウト**: VStack、中央配置、20px間隔
- **進捗表示**: LinearProgressViewStyle、300px幅
- **時刻表示**: 等幅フォント、MM:SS形式
- **モーダル表示**: .sheet()による表示

## 3. View・ViewModel構造設計

### 3.1 MVVM基盤クラス

#### 3.1.1 BaseViewModel
```swift
import Foundation
import Combine

@MainActor
class BaseViewModel: ObservableObject {
    // 共通状態
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // Combine関連
    protected var cancellables = Set<AnyCancellable>()
    
    // 共通メソッド
    func showError(_ message: String) {
        errorMessage = message
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    deinit {
        cancellables.removeAll()
    }
}
```

### 3.2 各ViewModelの設計

#### 3.2.1 StationListViewModel
```swift
@MainActor
final class StationListViewModel: BaseViewModel {
    // 状態
    @Published var stations: [RadioStation] = []
    @Published var selectedArea: Area = Area.tokyo
    @Published var areas: [Area] = Area.allCases
    
    // Dependencies（Phase 2で注入）
    private let apiService: RadikoAPIServiceProtocol = MockRadikoAPIService()
    
    // Actions
    func loadStations() {
        isLoading = true
        // Phase 1: モックデータ使用
        stations = MockData.stations
        isLoading = false
    }
    
    func selectArea(_ area: Area) {
        selectedArea = area
        loadStations()
    }
    
    func selectStation(_ station: RadioStation) {
        // NavigationPathによる画面遷移（Phase 1で基盤実装）
        NotificationCenter.default.post(
            name: .stationSelected,
            object: station
        )
    }
}
```

#### 3.2.2 ProgramListViewModel
```swift
@MainActor
final class ProgramListViewModel: BaseViewModel {
    // 状態
    @Published var currentStation: RadioStation?
    @Published var programs: [RadioProgram] = []
    @Published var selectedDate: Date = Date()
    @Published var selectedProgram: RadioProgram?
    
    // Dependencies
    private let apiService: RadikoAPIServiceProtocol = MockRadikoAPIService()
    
    // Computed properties
    var availableDates: [Date] {
        // 過去1週間の日付配列生成
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: Date()) }
    }
    
    // Actions
    func setStation(_ station: RadioStation) {
        currentStation = station
        loadPrograms()
    }
    
    func loadPrograms() {
        guard let station = currentStation else { return }
        isLoading = true
        // Phase 1: モックデータ使用
        programs = MockData.programs(for: station.id, date: selectedDate)
        isLoading = false
    }
    
    func selectProgram(_ program: RadioProgram) {
        selectedProgram = program
    }
    
    func startRecording() {
        guard let program = selectedProgram else { return }
        // Phase 3で録音ロジック実装
        NotificationCenter.default.post(
            name: .recordingStarted,
            object: program
        )
    }
}
```

#### 3.2.3 SettingsViewModel
```swift
@MainActor
final class SettingsViewModel: BaseViewModel {
    // 設定項目
    @AppStorage("saveDirectoryPath") var saveDirectoryPath: String = "~/Desktop"
    @AppStorage("premiumEmail") var premiumEmail: String = ""
    @AppStorage("premiumPassword") var premiumPassword: String = ""
    
    // 一時状態
    @Published var showingDirectoryPicker = false
    
    // Actions
    func selectSaveDirectory() {
        showingDirectoryPicker = true
    }
    
    func updateSaveDirectory(_ url: URL) {
        saveDirectoryPath = url.path
    }
    
    func validatePremiumCredentials() -> Bool {
        !premiumEmail.isEmpty && !premiumPassword.isEmpty
    }
    
    func testPremiumConnection() {
        // Phase 2で実装予定
        showError("プレミアム認証は将来実装予定です")
    }
}
```

#### 3.2.4 RecordingViewModel
```swift
@MainActor
final class RecordingViewModel: BaseViewModel {
    // 録音状態
    @Published var isRecording: Bool = false
    @Published var recordingProgress: Double = 0.0
    @Published var elapsedTime: TimeInterval = 0
    @Published var currentProgram: RadioProgram?
    
    // Dependencies（Phase 3で実装）
    private let recordingService: RecordingServiceProtocol = MockRecordingService()
    
    // Timer
    private var progressTimer: Timer?
    
    // Computed properties
    var elapsedTimeString: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // Actions
    func startRecording(program: RadioProgram) {
        currentProgram = program
        isRecording = true
        startProgressTimer()
    }
    
    func cancelRecording() {
        isRecording = false
        stopProgressTimer()
        recordingProgress = 0.0
        elapsedTime = 0
        currentProgram = nil
    }
    
    private func startProgressTimer() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.elapsedTime += 1
            // Phase 1: モック進捗更新
            self.recordingProgress = min(self.elapsedTime / 3600.0, 1.0)
        }
    }
    
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
}
```

## 4. 状態管理方式詳細

### 4.1 状態管理階層

```
App Level State (AppStorage)
├── saveDirectoryPath
├── selectedAreaId
└── isFirstLaunch

Screen Level State (ViewModel @Published)
├── StationListViewModel
│   ├── stations: [RadioStation]
│   ├── selectedArea: Area
│   └── isLoading: Bool
├── ProgramListViewModel
│   ├── programs: [RadioProgram]
│   ├── selectedProgram: RadioProgram?
│   └── selectedDate: Date
└── SettingsViewModel
    ├── showingDirectoryPicker: Bool
    └── premiumCredentials: (email, password)
```

### 4.2 状態同期戦略

#### 4.2.1 画面間データ受け渡し
```swift
// NotificationCenterによるイベント駆動
extension Notification.Name {
    static let stationSelected = Notification.Name("stationSelected")
    static let recordingStarted = Notification.Name("recordingStarted")
    static let recordingCompleted = Notification.Name("recordingCompleted")
}

// ViewModelでの受信処理
private func setupNotifications() {
    NotificationCenter.default.publisher(for: .stationSelected)
        .compactMap { $0.object as? RadioStation }
        .sink { [weak self] station in
            self?.setStation(station)
        }
        .store(in: &cancellables)
}
```

#### 4.2.2 設定値の自動同期
```swift
// AppStorageによる自動永続化・同期
@AppStorage("saveDirectoryPath") var saveDirectoryPath: String = "~/Desktop" {
    didSet {
        // 設定変更時の追加処理
        validateSaveDirectory()
    }
}
```

## 5. ナビゲーション仕組み設計

### 5.1 カスタムタブナビゲーション（macOS対応）

```swift
struct ContentView: View {
    @State private var selectedTab: CustomTabBar.TabItem = .stationList
    @StateObject private var navigationManager = NavigationManager()
    
    var body: some View {
        VStack(spacing: 0) {
            // カスタムタブバー
            CustomTabBar(selectedTab: $selectedTab)
            
            // コンテンツエリア
            contentView
        }
        .background(Color.appBackground)
        .environmentObject(navigationManager)
        .onReceive(NotificationCenter.default.publisher(for: .stationSelected)) { notification in
            if let _ = notification.object as? RadioStation {
                selectedTab = .program
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .backToStationList)) { _ in
            selectedTab = .stationList
        }
        .sheet(isPresented: $navigationManager.showingRecordingProgress) {
            RecordingProgressView()
                .environmentObject(navigationManager)
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .stationList:
            StationListView()
                .transition(.asymmetric(
                    insertion: .move(edge: .leading),
                    removal: .move(edge: .trailing)
                ))
        case .program:
            if navigationManager.selectedStation != nil {
                ProgramListView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            } else {
                StationListView()
                    .onAppear {
                        selectedTab = .stationList
                    }
            }
        case .settings:
            SettingsView()
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom),
                    removal: .move(edge: .top)
                ))
        }
    }
}
```

**設計変更理由**:
- **macOS互換性**: NavigationViewのStackNavigationViewStyleがmacOSで利用不可のため
- **カスタム実装**: 独自タブバーによる柔軟なナビゲーション制御
- **NotificationCenter**: 画面間の疎結合な連携を実現

### 5.2 NavigationManager設計

```swift
@MainActor
final class NavigationManager: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedStation: RadioStation?
    @Published var showingRecordingProgress = false
    
    // MARK: - Initializer
    init() {
        setupNotifications()
    }
    
    // MARK: - Setup
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .stationSelected)
            .compactMap { $0.object as? RadioStation }
            .assign(to: &$selectedStation)
        
        NotificationCenter.default.publisher(for: .recordingStarted)
            .sink { [weak self] _ in
                self?.showingRecordingProgress = true
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .recordingCompleted)
            .sink { [weak self] _ in
                self?.showingRecordingProgress = false
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .recordingCancelled)
            .sink { [weak self] _ in
                self?.showingRecordingProgress = false
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    deinit {
        cancellables.removeAll()
    }
}
```

**設計変更点**:
- **NotificationCenter駆動**: イベント駆動型アーキテクチャで画面間連携
- **状態の自動同期**: Combineを活用した宣言的状態管理
- **メモリリーク対策**: weak selfとdeinitでのcancellables管理

### 5.3 モーダル表示管理

```swift
// RecordingProgressViewのSheet表示（ContentView）
.sheet(isPresented: $navigationManager.showingRecordingProgress) {
    RecordingProgressView()
        .environmentObject(navigationManager)
}

// ファイル選択ダイアログ（SettingsView）
.fileImporter(
    isPresented: $viewModel.showingDirectoryPicker,
    allowedContentTypes: [.folder]
) { result in
    switch result {
    case .success(let url):
        viewModel.updateSaveDirectory(url)
    case .failure(let error):
        viewModel.showError("フォルダの選択に失敗しました: \(error.localizedDescription)")
    }
}

// エラーアラート表示（各View共通）
.alert("エラー", isPresented: .constant(viewModel.errorMessage != nil)) {
    Button("OK") {
        viewModel.clearError()
    }
} message: {
    if let errorMessage = viewModel.errorMessage {
        Text(errorMessage)
    }
}
```

**モーダル表示の特徴**:
- **Sheet**: 録音進捗表示に使用、半透明背景でオーバーレイ
- **FileImporter**: ディレクトリ選択用のシステムダイアログ
- **Alert**: エラー表示用の標準アラートダイアログ

## 6. テーマ・Style設計

### 6.1 カラーパレット定義

```swift
extension Color {
    // アプリケーション固有カラー
    static let appBackground = Color.black
    static let appSecondaryBackground = Color(white: 0.15)
    static let appUIBackground = Color(white: 0.2)
    static let appInputBackground = Color(white: 0.3)
    
    static let appPrimaryText = Color.white
    static let appSecondaryText = Color.gray
    static let appAccent = Color.blue
    static let appDanger = Color.red
}
```

### 6.2 フォントスタイル定義

```swift
extension Font {
    // アプリケーション固有フォント
    static let appTitle = Font.title2
    static let appHeadline = Font.headline
    static let appBody = Font.system(size: 14)
    static let appCaption = Font.caption
    static let appMonospaced = Font.system(size: 14, family: .monospaced)
}
```

### 6.3 ボタンスタイル定義

```swift
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.appAccent)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.black)
            .padding(.horizontal, 20)
            .padding(.vertical, 5)
            .background(Color.gray.opacity(0.8))
            .cornerRadius(5)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct DangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(.horizontal, 30)
            .padding(.vertical, 10)
            .background(Color.appDanger)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
```

## 7. モックデータ設計

### 7.1 MockData構造

```swift
struct MockData {
    // 放送局モックデータ
    static let stations: [RadioStation] = [
        RadioStation(
            id: "TBS",
            name: "TBSラジオ",
            displayName: "TBS",
            logoURL: "https://example.com/tbs_logo.png",
            areaId: "JP13"
        ),
        RadioStation(
            id: "QRR",
            name: "文化放送",
            displayName: "QRR",
            logoURL: "https://example.com/qrr_logo.png",
            areaId: "JP13"
        ),
        // ... 他の放送局
    ]
    
    // 番組モックデータ生成
    static func programs(for stationId: String, date: Date) -> [RadioProgram] {
        [
            RadioProgram(
                id: "prog_001",
                title: "荻上チキ・Session",
                description: "平日22時から放送中",
                startTime: date.addingHours(22),
                endTime: date.addingHours(24),
                personalities: ["荻上チキ", "南部広美"],
                stationId: stationId
            ),
            // ... 他の番組
        ]
    }
    
    // 地域モックデータ
    static let areas: [Area] = [
        Area(id: "JP13", name: "東京", displayName: "東京"),
        Area(id: "JP14", name: "神奈川", displayName: "神奈川"),
        Area(id: "JP27", name: "大阪", displayName: "大阪"),
        // ... 他の地域
    ]
}
```

### 7.2 MockService実装

```swift
protocol RadikoAPIServiceProtocol {
    func fetchStations(for areaId: String) async throws -> [RadioStation]
    func fetchPrograms(stationId: String, date: Date) async throws -> [RadioProgram]
}

class MockRadikoAPIService: RadikoAPIServiceProtocol {
    func fetchStations(for areaId: String) async throws -> [RadioStation] {
        // 0.5秒の遅延をシミュレート
        try await Task.sleep(nanoseconds: 500_000_000)
        return MockData.stations.filter { $0.areaId == areaId }
    }
    
    func fetchPrograms(stationId: String, date: Date) async throws -> [RadioProgram] {
        try await Task.sleep(nanoseconds: 500_000_000)
        return MockData.programs(for: stationId, date: date)
    }
}
```

## 8. レスポンシブ設計

### 8.1 ウィンドウサイズ対応

```swift
struct AdaptiveLayout: View {
    @State private var windowSize: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            content(for: geometry.size)
                .onAppear {
                    windowSize = geometry.size
                }
                .onChange(of: geometry.size) { newSize in
                    windowSize = newSize
                }
        }
    }
    
    @ViewBuilder
    private func content(for size: CGSize) -> some View {
        if size.width < 900 {
            // 最小サイズ以下の場合の対応
            MinimumSizeWarning()
        } else {
            // 通常レイアウト
            MainContent()
        }
    }
}
```

### 8.2 グリッドレスポンシブデザイン

```swift
// 画面幅に応じた列数調整
private var gridColumns: [GridItem] {
    let minColumnWidth: CGFloat = 140 // セル幅 + 間隔
    let availableWidth = windowSize.width - 40 // パディング分除外
    let columnCount = max(Int(availableWidth / minColumnWidth), 1)
    return Array(repeating: GridItem(.flexible()), count: columnCount)
}
```

## 9. アクセシビリティ設計

### 9.1 VoiceOver対応

```swift
// 適切なアクセシビリティラベル設定
StationCell(station: station)
    .accessibilityLabel("\(station.displayName)放送局")
    .accessibilityHint("タップして番組一覧を表示")
    .accessibilityAddTraits(.isButton)

ProgramRow(program: program, isSelected: isSelected) {
    selectProgram(program)
}
.accessibilityLabel("\(program.displayTime), \(program.title)")
.accessibilityHint(isSelected ? "選択済み" : "タップして選択")
.accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
```

### 9.2 キーボードナビゲーション

```swift
// フォーカス管理
@FocusState private var focusedField: Field?

enum Field: Hashable {
    case areaSelector
    case stationGrid
    case programList
}

// タブキーでのフォーカス移動
.focusable()
.focused($focusedField, equals: .stationGrid)
.onKeyPress(.tab) {
    focusedField = .programList
    return .handled
}
```

## 10. パフォーマンス最適化

### 10.1 レイジーローディング

```swift
// LazyVGridによる仮想化
LazyVGrid(columns: gridColumns, spacing: 20) {
    ForEach(viewModel.stations) { station in
        StationCell(station: station)
            .onAppear {
                // 必要に応じてプリロード処理
                viewModel.preloadStationData(station)
            }
    }
}
```

### 10.2 画像キャッシュ戦略

```swift
// AsyncImageの効率的使用
AsyncImage(url: URL(string: station.logoURL ?? "")) { phase in
    switch phase {
    case .success(let image):
        image
            .resizable()
            .aspectRatio(contentMode: .fit)
    case .failure(_):
        Image(systemName: "radio")
            .foregroundColor(.gray)
    case .empty:
        ProgressView()
            .frame(width: 20, height: 20)
    @unknown default:
        EmptyView()
    }
}
.frame(width: 120, height: 80)
```

---

## まとめ

Phase 1の詳細設計では、SwiftUIとMVVMアーキテクチャを基盤とした堅牢なUI実装を目指します。モックデータを活用したプロトタイプ開発により、Phase 2以降の実装基盤を確立し、ユーザーエクスペリエンスの早期検証を可能にします。

**次のステップ**: この設計に基づいてPhase 1テスト仕様書を作成し、TDD開発の準備を整えます。