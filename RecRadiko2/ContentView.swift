//
//  ContentView.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/24.
//

import SwiftUI
import Combine

/// アプリケーションのメインコンテンツビュー
struct ContentView: View {
    // MARK: - State
    @State private var selectedTab: CustomTabBar.TabItem = .stationList
    @StateObject private var navigationManager = NavigationManager()
    @StateObject private var folderAccessManager = FolderAccessManager()
    @StateObject private var recordingManager = RecordingManager()
    @FocusState private var focusedElement: FocusableElement?
    
    // MARK: - Focus Elements
    enum FocusableElement: Hashable {
        case tabBar
        case content
        case recording
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // カスタムタブバー
            CustomTabBar(selectedTab: $selectedTab)
                .focused($focusedElement, equals: .tabBar)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("タブバー")
                .accessibilityHint("矢印キーでタブを切り替え、スペースキーで選択")
            
            // コンテンツエリア
            contentView
                .focused($focusedElement, equals: .content)
                .accessibilityElement(children: .contain)
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
        // メニューコマンド通知の受信
        .onReceive(NotificationCenter.default.publisher(for: .showStationList)) { _ in
            selectedTab = .stationList
            focusedElement = .content
        }
        .onReceive(NotificationCenter.default.publisher(for: .showProgramSchedule)) { _ in
            if navigationManager.selectedStation != nil {
                selectedTab = .program
                focusedElement = .content
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showSettings)) { _ in
            selectedTab = .settings
            focusedElement = .content
        }
        .sheet(isPresented: $navigationManager.showingRecordingProgress) {
            RecordingProgressView(recordingManager: recordingManager)
                .environmentObject(navigationManager)
                .accessibilityAddTraits(.isModal)
        }
        // キーボードショートカット（ショートカットキーはメニューバーで定義済み）
        .focusable()
        .focusEffectDisabled()
    }
    
    // MARK: - Subviews
    /// 選択されたタブに応じたコンテンツ表示
    @ViewBuilder
    private var contentView: some View {
        ZStack {
            switch selectedTab {
            case .stationList:
                StationListView()
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        )
                    )
                    .zIndex(selectedTab == .stationList ? 1 : 0)
                
            case .program:
                ProgramScheduleView(
                    recordingManager: recordingManager,
                    selectedStation: $navigationManager.selectedStation
                )
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .scale(scale: 1.05).combined(with: .opacity)
                    )
                )
                .zIndex(selectedTab == .program ? 1 : 0)
                
            case .settings:
                SettingsView()
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        )
                    )
                    .zIndex(selectedTab == .settings ? 1 : 0)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0), value: selectedTab)
    }
}

// MARK: - Navigation Manager
/// ナビゲーション状態を管理するクラス
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

// MARK: - Preview
#Preview {
    ContentView()
}
