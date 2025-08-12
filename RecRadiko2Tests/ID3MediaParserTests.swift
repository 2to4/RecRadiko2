//
//  ID3MediaParserTests.swift
//  RecRadiko2Tests
//
//  Created by Claude on 2025/08/12.
//

import Testing
import Foundation
@testable import RecRadiko2

struct ID3MediaParserTests {
    
    private let parser = ID3MediaParser()
    
    // MARK: - ID3タグ付きMP3テスト
    
    @Test("ID3v2.4タグ付きMP3データの正常解析")
    func testID3TaggedMP3Parsing() async throws {
        // ID3v2.4ヘッダー + 簡易MP3フレーム
        var testData = Data()
        
        // ID3v2.4ヘッダー: "ID3" + version(2,4) + flags(0) + size(synchsafe: 100 bytes)
        testData.append(contentsOf: [0x49, 0x44, 0x33]) // "ID3"
        testData.append(contentsOf: [0x04, 0x00, 0x00]) // Version 2.4, flags 0
        testData.append(contentsOf: [0x00, 0x00, 0x00, 0x64]) // Size: 100 bytes (synchsafe)
        
        // ID3タグ内容（100バイト）
        let tagContent = Data(repeating: 0x00, count: 100)
        testData.append(tagContent)
        
        // MP3フレームヘッダー（MPEG-1 Layer 3, 44.1kHz, Stereo）
        testData.append(contentsOf: [0xFF, 0xFB, 0x90, 0x00]) // MP3 sync + header
        testData.append(Data(repeating: 0xAA, count: 100)) // MP3データ
        
        let result = try parser.extractAudioData(from: testData)
        
        #expect(result.format == .mp3)
        #expect(result.sampleRate == 44100)
        #expect(result.channelCount == 2)
        #expect(result.data.count == 104) // MP3ヘッダー + データ
    }
    
    @Test("ID3タグサイズのsynchsafe integer計算")
    func testSynchsafeIntegerCalculation() async throws {
        // Synchsafeテストデータ: 0x00 0x00 0x02 0x01 = 257
        var testData = Data()
        testData.append(contentsOf: [0x49, 0x44, 0x33, 0x04, 0x00, 0x00]) // ID3 header
        testData.append(contentsOf: [0x00, 0x00, 0x02, 0x01]) // Synchsafe: 257
        
        // 257バイトのタグ内容
        let tagContent = Data(repeating: 0x00, count: 257)
        testData.append(tagContent)
        
        // MP3データ
        testData.append(contentsOf: [0xFF, 0xFB, 0x90, 0x00])
        testData.append(Data(repeating: 0xBB, count: 50))
        
        let result = try parser.extractAudioData(from: testData)
        
        #expect(result.format == .mp3)
        #expect(result.data.count == 54) // MP3ヘッダー(4) + データ(50)
    }
    
    @Test("ID3タグなしMP3データの直接解析")
    func testDirectMP3Parsing() async throws {
        var testData = Data()
        
        // MP3フレームヘッダー（MPEG-1 Layer 3, 32kHz, Mono）
        testData.append(contentsOf: [0xFF, 0xFA, 0x48, 0xC0]) // MP3 sync + header (32kHz, Mono)
        testData.append(Data(repeating: 0xCC, count: 200))
        
        let result = try parser.extractAudioData(from: testData)
        
        #expect(result.format == .mp3)
        #expect(result.sampleRate == 32000)
        #expect(result.channelCount == 1) // Mono
        #expect(result.data.count == 204) // Full data
    }
    
    // MARK: - ADTSテスト
    
    @Test("ADTS AACデータの解析")
    func testADTSParsing() async throws {
        var testData = Data()
        
        // ADTSヘッダー（44.1kHz, 2ch）
        testData.append(contentsOf: [0xFF, 0xF1]) // ADTS sync + profile
        testData.append(contentsOf: [0x50, 0x80]) // Sample rate (44.1kHz) + channel (2ch)
        testData.append(contentsOf: [0x00, 0x1F, 0xFC]) // Frame length
        testData.append(Data(repeating: 0xDD, count: 100))
        
        let result = try parser.extractAudioData(from: testData)
        
        #expect(result.format == .adts)
        #expect(result.sampleRate == 44100)
        #expect(result.channelCount == 2)
        #expect(result.data.count == 107) // Full ADTS frame
    }
    
    // MARK: - エラーケーステスト
    
    @Test("空データでのエラーハンドリング")
    func testEmptyDataError() async throws {
        let emptyData = Data()
        
        await #expect(throws: ID3MediaParserError.invalidData) {
            try parser.extractAudioData(from: emptyData)
        }
    }
    
    @Test("不正なID3タグサイズでのエラーハンドリング")
    func testInvalidTagSizeError() async throws {
        var testData = Data()
        testData.append(contentsOf: [0x49, 0x44, 0x33, 0x04, 0x00, 0x00]) // ID3 header
        testData.append(contentsOf: [0x7F, 0x7F, 0x7F, 0x7F]) // 最大synchsafeサイズ
        // タグ内容は提供しない（不正状態）
        
        await #expect(throws: ID3MediaParserError.invalidTagSize) {
            try parser.extractAudioData(from: testData)
        }
    }
    
    @Test("最小データサイズでのエラーハンドリング")
    func testMinimumDataSizeError() async throws {
        let tinyData = Data([0x49, 0x44, 0x33]) // "ID3"のみ
        
        await #expect(throws: ID3MediaParserError.invalidData) {
            try parser.extractAudioData(from: tinyData)
        }
    }
    
    // MARK: - 実際のラジオストリーム形式テスト
    
    @Test("Radiko風ID3タグ付きMP3の解析（32kHz, Stereo）")
    func testRadikoStyleMP3() async throws {
        var testData = Data()
        
        // ID3v2.3ヘッダー（Radiko形式模倣）
        testData.append(contentsOf: [0x49, 0x44, 0x33, 0x03, 0x00, 0x00]) // ID3v2.3
        testData.append(contentsOf: [0x00, 0x00, 0x01, 0x00]) // 128バイトタグ
        
        // ID3タグ内容（128バイト）
        let tagContent = Data(repeating: 0x00, count: 128)
        testData.append(tagContent)
        
        // MP3フレームヘッダー（32kHz, Stereo, 128kbps想定）
        testData.append(contentsOf: [0xFF, 0xFB, 0x50, 0x00]) // MPEG-1, Layer 3, 32kHz, Stereo
        testData.append(Data(repeating: 0xEE, count: 300))
        
        let result = try parser.extractAudioData(from: testData)
        
        #expect(result.format == .mp3)
        #expect(result.sampleRate == 32000) // Radikoの一般的なサンプリングレート
        #expect(result.channelCount == 2) // Stereo
        #expect(result.data.count == 304) // MP3 header + data
    }
}