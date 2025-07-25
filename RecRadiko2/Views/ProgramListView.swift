//
//  ProgramListView.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/24.
//

import SwiftUI

/// 番組一覧画面
struct ProgramListView: View {
    // MARK: - ViewModel
    @StateObject private var viewModel = ProgramListViewModel()
    @EnvironmentObject private var navigationManager: NavigationManager
    
    // MARK: - Body
    var body: some View {
        HStack(spacing: 0) {
            // 左パネル（番組詳細）
            leftPanel
            
            Divider()
                .background(Color.appDivider)
            
            // 右パネル（番組リスト）
            rightPanel
        }
        .background(Color.appBackground)
        .frame(minWidth: 900, minHeight: 700)
        .onAppear {
            if let station = navigationManager.selectedStation {
                Task {
                    await viewModel.setStation(station)
                }
            }
        }
        .overlay(
            // ローディング表示
            Group {
                if viewModel.isLoading {
                    LoadingView(message: "番組表を読み込み中...")
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
    /// 左パネル（番組詳細）
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
    
    /// ヘッダーセクション
    private var headerSection: some View {
        Button(action: {
            viewModel.backToStationList()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 16))
                
                Text(viewModel.currentStation?.name ?? "放送局")
                    .font(.appHeadline)
            }
            .foregroundColor(.appPrimaryText)
        }
        .buttonStyle(NavigationButtonStyle())
        .accessibilityLabel("放送局一覧に戻る")
    }
    
    /// 放送局ロゴ
    private var stationLogo: some View {
        Group {
            if let station = viewModel.currentStation,
               let logoURL = station.logoURL {
                AsyncImage(url: URL(string: logoURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    stationPlaceholder
                }
            } else {
                stationPlaceholder
            }
        }
        .frame(width: 120, height: 80)
        .background(Color.appUIBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.appBorder, lineWidth: 1)
        )
    }
    
    /// 放送局プレースホルダー
    private var stationPlaceholder: some View {
        VStack {
            Image(systemName: "radio")
                .font(.title2)
                .foregroundColor(.appSecondaryText)
            
            if let station = viewModel.currentStation {
                Text(station.displayName)
                    .font(.appCaption)
                    .foregroundColor(.appSecondaryText)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    /// 番組詳細
    private var programDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let program = viewModel.selectedProgram {
                // 放送時間
                Text("放送時間:")
                    .font(.appCaption)
                    .foregroundColor(.appSecondaryText)
                
                Text("\(program.displayTime)～\(TimeConverter.formatProgramTime(program.endTime))")
                    .font(.appBody)
                    .foregroundColor(.appPrimaryText)
                
                // 番組名
                Text(program.title)
                    .font(.appHeadlineLarge)
                    .foregroundColor(.appPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
                
                // 出演者
                if !program.personalities.isEmpty {
                    Text(program.personalitiesText)
                        .font(.appCaption)
                        .foregroundColor(.appSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("番組を選択してください")
                    .font(.appBody)
                    .foregroundColor(.appSecondaryText)
            }
        }
    }
    
    /// 右パネル（番組リスト）
    private var rightPanel: some View {
        VStack(spacing: 0) {
            // 操作ボタンバー
            controlBar
            
            // 日付選択バー
            dateSelector
            
            // 番組リスト
            programList
        }
        .background(Color(white: 0.1))
    }
    
    /// 操作ボタンバー
    private var controlBar: some View {
        HStack(spacing: 20) {
            Button(action: {
                // Phase 3で実装予定
            }) {
                Image(systemName: "play.fill")
                    .font(.title2)
                    .foregroundColor(.appSecondaryText)
            }
            .buttonStyle(.plain)
            .disabled(true)
            .accessibilityLabel("再生")
            
            Button(action: {
                viewModel.startRecording()
            }) {
                Image(systemName: "record.circle")
                    .font(.title2)
                    .foregroundColor(viewModel.canStartRecording ? .appDanger : .appSecondaryText)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canStartRecording)
            .accessibilityLabel("録音開始")
            
            Spacer()
        }
        .frame(height: 50)
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(Color(white: 0.15))
    }
    
    /// 日付選択バー
    private var dateSelector: some View {
        HStack(spacing: 16) {
            Text("番組表")
                .font(.appBody)
                .foregroundColor(.appSecondaryText)
            
            Text("日付")
                .font(.appBody)
                .foregroundColor(.appSecondaryText)
            
            DatePicker(
                "",
                selection: $viewModel.selectedDate,
                in: viewModel.availableDates.last!...viewModel.availableDates.first!,
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(CompactDatePickerStyle())
            .onChange(of: viewModel.selectedDate) { _, newDate in
                viewModel.selectDate(newDate)
            }
            
            Spacer()
        }
        .frame(height: 40)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(white: 0.12))
    }
    
    /// 番組リスト
    private var programList: some View {
        Group {
            if viewModel.programs.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    icon: "tv",
                    title: "番組が見つかりません",
                    message: "選択された日付に番組情報がありません。",
                    actionTitle: "再読み込み",
                    action: {
                        Task {
                            await viewModel.loadPrograms()
                        }
                    }
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.programs) { program in
                            ProgramRow(
                                program: program,
                                isSelected: viewModel.selectedProgram?.id == program.id
                            ) {
                                viewModel.selectProgram(program)
                            }
                        }
                    }
                }
            }
        }
        .background(Color(white: 0.1))
    }
}

// MARK: - Preview
#Preview {
    ProgramListView()
        .environmentObject(NavigationManager())
}