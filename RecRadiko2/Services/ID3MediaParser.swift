//
//  ID3MediaParser.swift
//  RecRadiko2
//
//  Created by Claude on 2025/08/12.
//

import Foundation
import AVFoundation

/// ID3タグ付きメディアファイル（MP3/AAC）パーサー
class ID3MediaParser {
    private let logger = AppLogger.shared.category("ID3MediaParser")
    
    /// ID3タグ付きメディアセグメントから音声データを抽出
    /// - Parameter mediaData: ID3タグ付きメディアデータ
    /// - Returns: 音声形式情報とデータ
    func extractAudioData(from mediaData: Data) throws -> AudioSegmentData {
        logger.info("ID3メディア解析開始: \(mediaData.count)バイト")
        
        // データヘッダーの確認
        let headerData = mediaData.prefix(16)
        let headerHex = headerData.map { String(format: "%02X", $0) }.joined(separator: " ")
        logger.debug("メディアヘッダー: \(headerHex)")
        
        // ID3ヘッダーの確認
        guard mediaData.count >= 10 else {
            throw ID3MediaParserError.invalidData
        }
        
        if mediaData[0] == 0x49 && mediaData[1] == 0x44 && mediaData[2] == 0x33 { // "ID3"
            logger.info("ID3タグを検出しました")
            return try parseID3TaggedFile(mediaData)
        } else {
            logger.info("ID3タグが見つかりません。直接音声データとして処理します")
            return try parseDirectAudioData(mediaData)
        }
    }
    
    /// ID3タグ付きファイルの解析
    private func parseID3TaggedFile(_ data: Data) throws -> AudioSegmentData {
        // ID3v2ヘッダーの解析
        let majorVersion = data[3]
        let minorVersion = data[4]
        let flags = data[5]
        
        logger.info("ID3バージョン: v2.\(majorVersion).\(minorVersion), フラグ: 0x\(String(format: "%02X", flags))")
        
        // ID3タグサイズの計算（7bit符号化）
        let tagSize = calculateSynchsafeInteger(data: data, offset: 6)
        logger.info("ID3タグサイズ: \(tagSize)バイト")
        
        let headerSize = 10 // ID3v2ヘッダー固定サイズ
        let audioDataOffset = headerSize + Int(tagSize)
        
        guard audioDataOffset < data.count else {
            throw ID3MediaParserError.invalidTagSize
        }
        
        // 音声データ部分を抽出
        let audioData = data.subdata(in: audioDataOffset..<data.count)
        logger.info("音声データ抽出: \(audioData.count)バイト（オフセット: \(audioDataOffset)）")
        
        // 音声データの形式を判定
        return try identifyAudioFormat(audioData)
    }
    
    /// 直接音声データの解析（ID3タグなし）
    private func parseDirectAudioData(_ data: Data) throws -> AudioSegmentData {
        return try identifyAudioFormat(data)
    }
    
    /// 音声データ形式の判定
    private func identifyAudioFormat(_ audioData: Data) throws -> AudioSegmentData {
        guard audioData.count >= 4 else {
            throw ID3MediaParserError.invalidData
        }
        
        let header = audioData.prefix(4)
        let headerBytes = Array(header)
        
        // MP3フレームヘッダーチェック（0xFFFA/0xFFFA/0xFFFB）
        if headerBytes[0] == 0xFF && (headerBytes[1] & 0xE0) == 0xE0 {
            logger.info("MP3形式を検出しました")
            return try parseMP3Data(audioData)
        }
        
        // ADTSヘッダーチェック（0xFFF0-0xFFFF）
        if headerBytes[0] == 0xFF && (headerBytes[1] & 0xF0) == 0xF0 {
            logger.info("ADTS AAC形式を検出しました")
            return try parseADTSData(audioData)
        }
        
        logger.warning("不明な音声形式です。MP3として処理を試行します")
        return try parseMP3Data(audioData)
    }
    
    /// MP3データの解析
    private func parseMP3Data(_ data: Data) throws -> AudioSegmentData {
        // 簡易MP3ヘッダー解析
        guard data.count >= 4 else {
            throw ID3MediaParserError.invalidData
        }
        
        let header = Array(data.prefix(4))
        
        // MPEG Audio Layer判定
        let layer = (header[1] & 0x06) >> 1
        _ = (header[2] & 0xF0) >> 4 // ビットレートインデックス（現在未使用）
        let sampleRateIndex = (header[2] & 0x0C) >> 2
        
        // サンプリングレート取得（MPEG-1 Layer 3）
        let sampleRates = [44100, 48000, 32000]
        let sampleRate = sampleRateIndex < sampleRates.count ? sampleRates[Int(sampleRateIndex)] : 44100
        
        // チャンネル数取得
        let channelMode = (header[3] & 0xC0) >> 6
        let channelCount = channelMode == 3 ? 1 : 2 // 3=mono, それ以外=stereo
        
        logger.info("MP3解析結果: \(sampleRate)Hz, \(channelCount)ch, Layer: \(4-layer)")
        
        return AudioSegmentData(
            data: data,
            format: .mp3,
            sampleRate: sampleRate,
            channelCount: channelCount
        )
    }
    
    /// ADTS AACデータの解析
    private func parseADTSData(_ data: Data) throws -> AudioSegmentData {
        guard data.count >= 7 else {
            throw ID3MediaParserError.invalidData
        }
        
        // ADTS固定ヘッダー解析
        let header = Array(data.prefix(7))
        
        // サンプリングレート取得
        let samplingFreqIndex = (header[2] & 0x3C) >> 2
        let sampleRates = [96000, 88200, 64000, 48000, 44100, 32000, 24000, 22050, 16000, 12000, 11025, 8000, 7350]
        let sampleRate = samplingFreqIndex < sampleRates.count ? sampleRates[Int(samplingFreqIndex)] : 44100
        
        // チャンネル数取得
        let channelConfig = Int((header[2] & 0x01) << 2 | (header[3] & 0xC0) >> 6)
        
        logger.info("ADTS解析結果: \(sampleRate)Hz, \(channelConfig)ch")
        
        return AudioSegmentData(
            data: data,
            format: .adts,
            sampleRate: sampleRate,
            channelCount: channelConfig
        )
    }
    
    /// Synchsafe integer（7bit符号化）の計算
    private func calculateSynchsafeInteger(data: Data, offset: Int) -> UInt32 {
        guard offset + 3 < data.count else { return 0 }
        
        let byte1 = UInt32(data[offset]) & 0x7F
        let byte2 = UInt32(data[offset + 1]) & 0x7F
        let byte3 = UInt32(data[offset + 2]) & 0x7F
        let byte4 = UInt32(data[offset + 3]) & 0x7F
        
        return (byte1 << 21) | (byte2 << 14) | (byte3 << 7) | byte4
    }
}

/// 音声セグメントデータ
struct AudioSegmentData {
    let data: Data
    let format: AudioFormat
    let sampleRate: Int
    let channelCount: Int
}

/// 音声形式
enum AudioFormat {
    case mp3
    case adts
    case unknown
}

/// ID3メディアパーサーエラー
enum ID3MediaParserError: Error, LocalizedError {
    case invalidData
    case invalidTagSize
    case unsupportedFormat
    
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "無効なメディアデータです"
        case .invalidTagSize:
            return "ID3タグサイズが無効です"
        case .unsupportedFormat:
            return "サポートされていない音声形式です"
        }
    }
}