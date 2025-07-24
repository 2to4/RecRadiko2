//
//  StationListView.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/24.
//

import SwiftUI

/// 放送局一覧画面
struct StationListView: View {
    // MARK: - ViewModel
    @StateObject private var viewModel = StationListViewModel()
    
    // MARK: - State
    @State private var windowSize: CGSize = .zero
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // 説明セクション
            explanationSection
            
            Divider()
                .background(Color.appDivider)
            
            // 放送局グリッド
            stationGrid
        }
        .background(Color.appBackground)
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            viewModel.loadInitialData()
        }
        .overlay(
            // ローディング表示
            Group {
                if viewModel.isLoading {
                    LoadingView(message: "放送局を読み込み中...")
                }
            }
        )
        .alert("エラー", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Subviews
    /// 説明セクション
    private var explanationSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            areaSelection
            explanationText
        }
        .frame(height: 150)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.appSecondaryBackground)
    }
    
    
    /// 地域選択部分
    private var areaSelection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("1) エリアの選択")
                .font(.appBody)
                .foregroundColor(.appSecondaryText)
            
            Picker("エリア", selection: $viewModel.selectedArea) {
                ForEach(viewModel.areas, id: \.id) { area in
                    Text(area.displayName)
                        .tag(area)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .frame(width: 200)
            .background(Color.appAccent)
            .cornerRadius(5)
            .foregroundColor(.appPrimaryText)
        }
    }
    
    /// 説明文
    private var explanationText: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("（ラジコプレミアムアカウントをお持ちの方は「設定」でアカウント情報を登録することでエリアフリーが有効になります）")
                .font(.appCaption)
                .foregroundColor(.appSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
            
            Text("2) ラジオ局を選ぶ")
                .font(.appBody)
                .foregroundColor(.appSecondaryText)
        }
    }
    
    /// 放送局グリッド
    private var stationGrid: some View {
        GeometryReader { geometry in
            Group {
                if viewModel.stations.isEmpty && !viewModel.isLoading {
                    EmptyStateView(
                        icon: "radio",
                        title: "放送局が見つかりません",
                        message: "選択された地域に利用可能な放送局がありません。",
                        actionTitle: "再試行",
                        action: {
                            Task {
                                await viewModel.loadStations()
                            }
                        }
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: gridColumns(for: geometry.size), spacing: 20) {
                            ForEach(viewModel.stations) { station in
                                StationCell(station: station) {
                                    viewModel.selectStation(station)
                                }
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .background(Color(white: 0.1))
        }
    }
    
    // MARK: - Computed Properties
    /// 画面幅に応じたグリッド列数
    private func gridColumns(for size: CGSize) -> [GridItem] {
        let minColumnWidth: CGFloat = 140 // セル幅 + 間隔
        let availableWidth = size.width - 40 // パディング分除外
        let columnCount = max(Int(availableWidth / minColumnWidth), 1)
        return Array(repeating: GridItem(.flexible()), count: min(columnCount, 5)) // 最大5列
    }
}

// MARK: - Preview
#Preview {
    StationListView()
}