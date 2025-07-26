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
    @StateObject private var recordingManager = RecordingManager()
    
    // MARK: - Body
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
            RecordingProgressView(recordingManager: recordingManager)
                .environmentObject(navigationManager)
        }
    }
    
    // MARK: - Subviews
    /// 選択されたタブに応じたコンテンツ表示
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
            ProgramScheduleView(
                recordingManager: recordingManager,
                selectedStation: $navigationManager.selectedStation
            )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
            
        case .settings:
            SettingsView()
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom),
                    removal: .move(edge: .top)
                ))
        }
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
