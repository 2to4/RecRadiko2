//
//  ProgramRow.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/24.
//

import SwiftUI

/// 番組行コンポーネント
struct ProgramRow: View {
    // MARK: - Properties
    let program: RadioProgram
    let isSelected: Bool
    let onTap: () -> Void
    
    // MARK: - Body
    var body: some View {
        HStack(spacing: 16) {
            // ラジオボタン
            radioButton
            
            // 時刻表示
            timeDisplay
            
            // 番組名
            programTitle
        }
        .frame(height: 32)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isSelected ? Color.appSelectedBackground : Color.clear)
        .contentShape(Rectangle()) // タップ範囲を全体に拡張
        .onTapGesture {
            onTap()
        }
        .accessibilityLabel("\(program.displayTime), \(program.title)")
        .accessibilityHint(isSelected ? "選択済み" : "タップして選択")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
    
    // MARK: - Subviews
    /// ラジオボタン
    private var radioButton: some View {
        Image(systemName: isSelected ? "circle.inset.filled" : "circle")
            .foregroundColor(isSelected ? .appAccent : .appSecondaryText)
            .frame(width: 16, height: 16)
            .accessibilityHidden(true) // 親のアクセシビリティラベルで対応
    }
    
    /// 時刻表示
    private var timeDisplay: some View {
        Text(program.displayTime)
            .font(.appMonospacedRegular)
            .foregroundColor(.appSecondaryText)
            .frame(width: 50, alignment: .leading)
            .accessibilityHidden(true) // 親のアクセシビリティラベルで対応
    }
    
    /// 番組名
    private var programTitle: some View {
        Text(program.title)
            .font(.appBody)
            .foregroundColor(.appPrimaryText)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityHidden(true) // 親のアクセシビリティラベルで対応
    }
}

// MARK: - Preview
#Preview {
    VStack(alignment: .leading, spacing: 4) {
        // 通常番組
        ProgramRow(
            program: .mockMorningShow,
            isSelected: false
        ) {
            print("Morning show selected")
        }
        
        // 選択状態の番組
        ProgramRow(
            program: .mockSessionShow,
            isSelected: true
        ) {
            print("Session selected")
        }
        
        // 深夜番組（25時間表記）
        ProgramRow(
            program: .mockLateNightShow,
            isSelected: false
        ) {
            print("Late night show selected")
        }
        
        // 長いタイトルのテスト
        ProgramRow(
            program: RadioProgram(
                id: "test_long",
                title: "非常に長い番組名のテストケースでタイトルが切り詰められることを確認するためのサンプル",
                description: "テスト",
                startTime: Date(),
                endTime: Date().addingTimeInterval(3600),
                personalities: ["テスト"],
                stationId: "TBS"
            ),
            isSelected: false
        ) {
            print("Long title selected")
        }
    }
    .background(Color.appBackground)
}