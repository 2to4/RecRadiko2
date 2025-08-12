//
//  M4AEncoder.swift
//  RecRadiko2
//
//  Created by Claude on 2025/08/12.
//

import Foundation
@preconcurrency import AVFoundation

/// M4Aエンコーダー
final class M4AEncoder: @unchecked Sendable {
    private let logger = AppLogger.shared.category("M4AEncoder")
    
    /// 音声セグメントデータからM4Aファイルを作成
    /// - Parameters:
    ///   - segments: 音声セグメントデータ配列
    ///   - outputURL: 出力ファイルURL
    ///   - metadata: メタデータ（タイトル、アーティストなど）
    func createM4A(from segments: [AudioSegmentData], 
                   outputURL: URL, 
                   metadata: AudioMetadata? = nil) async throws {
        
        logger.info("M4A作成開始: \(segments.count)セグメント -> \(outputURL.lastPathComponent)")
        
        guard !segments.isEmpty else {
            throw M4AEncoderError.noAudioData
        }
        
        let firstSegment = segments[0]
        logger.info("音声設定: \(firstSegment.sampleRate)Hz, \(firstSegment.channelCount)ch, 形式: \(firstSegment.format)")
        
        // 音声形式に応じた一時ファイル拡張子を決定
        let tempExtension: String
        switch firstSegment.format {
        case .mp3:
            tempExtension = "temp.mp3"
        case .adts:
            tempExtension = "temp.aac"
        case .unknown:
            tempExtension = "temp.mp3" // デフォルトはMP3として扱う
        }
        
        // 一時音声ファイルを作成
        let tempAudioURL = outputURL.appendingPathExtension(tempExtension)
        
        do {
            // 音声セグメントを結合して一時ファイル作成
            try await createCombinedAudio(from: segments, outputURL: tempAudioURL)
            
            // 音声ファイルをM4Aコンテナに変換
            if firstSegment.format == .mp3 {
                // MP3の場合はAVAssetExportSessionを使用
                try await convertMP3ToM4A(mp3URL: tempAudioURL, 
                                         m4aURL: outputURL, 
                                         metadata: metadata)
            } else {
                // AAC（ADTS）の場合は従来の方法
                try await convertAudioToM4A(audioURL: tempAudioURL, 
                                           m4aURL: outputURL, 
                                           sampleRate: firstSegment.sampleRate,
                                           channelCount: firstSegment.channelCount,
                                           metadata: metadata)
            }
            
            // 一時ファイル削除
            try? FileManager.default.removeItem(at: tempAudioURL)
            
            logger.info("M4A作成完了: \(outputURL.lastPathComponent)")
            
        } catch {
            // 一時ファイル削除
            try? FileManager.default.removeItem(at: tempAudioURL)
            logger.error("M4A作成失敗: \(error)")
            throw error
        }
    }
    
    /// ADTSフレームからM4Aファイルを作成（レガシー対応）
    /// - Parameters:
    ///   - frames: ADTSオーディオフレーム配列
    ///   - outputURL: 出力ファイルURL
    ///   - metadata: メタデータ（タイトル、アーティストなど）
    func createM4A(from frames: [ADTSFrame], 
                   outputURL: URL, 
                   metadata: AudioMetadata? = nil) async throws {
        
        logger.info("M4A作成開始: \(frames.count)フレーム -> \(outputURL.lastPathComponent)")
        
        guard !frames.isEmpty else {
            throw M4AEncoderError.noAudioData
        }
        
        let firstFrame = frames[0]
        logger.info("オーディオ設定: \(firstFrame.sampleRate)Hz, \(firstFrame.channelCount)ch")
        
        // 一時AACファイルを作成
        let tempAACURL = outputURL.appendingPathExtension("temp.aac")
        
        do {
            // ADTSフレームを結合してAACファイル作成
            try await createRawAAC(from: frames, outputURL: tempAACURL)
            
            // AACファイルをM4Aコンテナに変換
            try await convertAACToM4A(aacURL: tempAACURL, 
                                     m4aURL: outputURL, 
                                     sampleRate: firstFrame.sampleRate,
                                     channelCount: firstFrame.channelCount,
                                     metadata: metadata)
            
            // 一時ファイル削除
            try? FileManager.default.removeItem(at: tempAACURL)
            
            logger.info("M4A作成完了: \(outputURL.lastPathComponent)")
            
        } catch {
            // 一時ファイル削除
            try? FileManager.default.removeItem(at: tempAACURL)
            logger.error("M4A作成失敗: \(error)")
            throw error
        }
    }
    
    /// ADTSフレームからRaw AACファイルを作成
    private func createRawAAC(from frames: [ADTSFrame], outputURL: URL) async throws {
        logger.debug("Raw AAC作成開始: \(frames.count)フレーム")
        
        var combinedData = Data()
        
        for (index, frame) in frames.enumerated() {
            // ADTSフレーム全体を保存（ヘッダー含む）
            // これによりADTSストリーム形式のAACファイルが作成される
            combinedData.append(frame.data)
            
            if index % 1000 == 0 {
                logger.debug("AACフレーム結合中: \(index)/\(frames.count)")
            }
        }
        
        guard !combinedData.isEmpty else {
            throw M4AEncoderError.noAudioData
        }
        
        // ADTSストリーム形式として保存
        try combinedData.write(to: outputURL)
        logger.debug("Raw AAC作成完了: \(combinedData.count)バイト (ADTS形式)")
        
        // 作成されたファイルの検証
        logger.info("ADTSファイル検証開始")
        let writtenData = try Data(contentsOf: outputURL)
        logger.info("書き込み確認: \(writtenData.count)バイト")
        
        // ADTSヘッダーの存在確認（最初の数バイトをチェック）
        if writtenData.count >= 2 {
            let header = String(format: "0x%02X%02X", writtenData[0], writtenData[1])
            logger.info("ADTSヘッダー: \(header)")
            
            if writtenData[0] == 0xFF && (writtenData[1] & 0xF0) == 0xF0 {
                logger.info("✅ 有効なADTSヘッダーを確認")
            } else {
                logger.error("❌ 無効なADTSヘッダー")
            }
        }
    }
    
    /// 音声セグメントから結合音声ファイルを作成
    private func createCombinedAudio(from segments: [AudioSegmentData], outputURL: URL) async throws {
        logger.debug("音声セグメント結合開始: \(segments.count)セグメント")
        
        var combinedData = Data()
        
        for (index, segment) in segments.enumerated() {
            // セグメントデータを直接結合
            combinedData.append(segment.data)
            
            if index % 100 == 0 {
                logger.debug("音声セグメント結合中: \(index)/\(segments.count)")
            }
        }
        
        // MP3の場合は、最初のセグメント以外のID3タグを除去して結合
        if let firstSegment = segments.first, firstSegment.format == .mp3 {
            logger.debug("MP3形式のため、重複ID3タグを除去して再結合")
            combinedData = Data()
            
            for (index, segment) in segments.enumerated() {
                if index == 0 {
                    // 最初のセグメントはID3タグ付きでそのまま使用
                    combinedData.append(segment.data)
                } else {
                    // 2番目以降はID3タグを除去してMP3データのみを結合
                    if segment.data.count >= 10 && 
                       segment.data[0] == 0x49 && segment.data[1] == 0x44 && segment.data[2] == 0x33 {
                        // ID3タグサイズを計算
                        let tagSize = calculateSynchsafeInteger(from: segment.data, offset: 6)
                        let audioStartOffset = 10 + Int(tagSize)
                        
                        if audioStartOffset < segment.data.count {
                            let audioData = segment.data.subdata(in: audioStartOffset..<segment.data.count)
                            combinedData.append(audioData)
                        }
                    } else {
                        // ID3タグがない場合はそのまま結合
                        combinedData.append(segment.data)
                    }
                }
                
                if index % 100 == 0 {
                    logger.debug("MP3セグメント結合中: \(index)/\(segments.count)")
                }
            }
        }
        
        guard !combinedData.isEmpty else {
            throw M4AEncoderError.noAudioData
        }
        
        // 結合された音声データを保存
        try combinedData.write(to: outputURL)
        logger.debug("音声セグメント結合完了: \(combinedData.count)バイト")
        
        // 作成されたファイルの検証
        logger.info("音声ファイル検証開始")
        let writtenData = try Data(contentsOf: outputURL)
        logger.info("書き込み確認: \(writtenData.count)バイト")
        
        // ファイルヘッダーの確認
        if writtenData.count >= 4 {
            let header = String(format: "0x%02X%02X%02X%02X", writtenData[0], writtenData[1], writtenData[2], writtenData[3])
            logger.info("音声ヘッダー: \(header)")
        }
    }
    
    /// 音声ファイルからM4Aへの変換（AVAssetReader/Writer使用）
    private func convertAudioToM4A(audioURL: URL, 
                                  m4aURL: URL, 
                                  sampleRate: Int, 
                                  channelCount: Int,
                                  metadata: AudioMetadata?) async throws {
        
        logger.info("音声->M4A変換開始")
        
        // AVAssetで音声ファイルを読み込み
        let asset = AVURLAsset(url: audioURL)
        logger.info("音声ファイル読み込み: \(audioURL.path)")
        
        // ファイル存在確認
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            logger.error("音声ファイルが存在しません: \(audioURL.path)")
            throw M4AEncoderError.noAudioData
        }
        
        // ファイルサイズ確認
        if let attributes = try? FileManager.default.attributesOfItem(atPath: audioURL.path),
           let fileSize = attributes[.size] as? Int64 {
            logger.info("音声ファイルサイズ: \(fileSize) bytes")
        }
        
        // アセットの読み込み可能性確認
        do {
            let isReadable = try await asset.load(.isReadable)
            logger.info("アセット読み込み可能: \(isReadable)")
            
            if !isReadable {
                logger.error("アセットが読み込み不可能です")
                throw M4AEncoderError.unsupportedFormat
            }
        } catch {
            logger.error("アセット読み込み可能性チェック失敗: \(error)")
            throw M4AEncoderError.unsupportedFormat
        }
        
        // オーディオトラックを取得
        let tracks: [AVAssetTrack]
        do {
            tracks = try await asset.loadTracks(withMediaType: .audio)
            logger.info("検出されたオーディオトラック数: \(tracks.count)")
        } catch {
            logger.error("オーディオトラック取得失敗: \(error)")
            throw M4AEncoderError.noAudioData
        }
        
        guard let audioTrack = tracks.first else {
            logger.error("オーディオトラックが見つかりません")
            throw M4AEncoderError.noAudioData
        }
        
        // トラック情報をログ出力
        let formatDescriptions = try await audioTrack.load(.formatDescriptions)
        logger.info("フォーマット記述数: \(formatDescriptions.count)")
        
        for (index, formatDesc) in formatDescriptions.enumerated() {
            let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)?.pointee
            logger.info("フォーマット\(index): \(String(describing: asbd))")
        }
        
        // AVAssetReaderを作成
        let assetReader: AVAssetReader
        do {
            assetReader = try AVAssetReader(asset: asset)
            logger.info("AVAssetReader作成成功")
        } catch {
            logger.error("AVAssetReader作成失敗: \(error)")
            logger.error("エラー詳細: \(error.localizedDescription)")
            throw M4AEncoderError.encodingFailed
        }
        
        // パススルー設定（圧縮されたまま読み込み）
        let readerOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
        readerOutput.alwaysCopiesSampleData = false
        logger.info("AVAssetReaderTrackOutput作成完了")
        
        guard assetReader.canAdd(readerOutput) else {
            logger.error("リーダー出力を追加できません")
            logger.error("リーダー状態: \(assetReader.status.rawValue)")
            throw M4AEncoderError.encodingFailed
        }
        assetReader.add(readerOutput)
        logger.info("リーダー出力追加完了")
        
        // AVAssetWriterを作成
        let assetWriter: AVAssetWriter
        do {
            assetWriter = try AVAssetWriter(outputURL: m4aURL, fileType: .m4a)
            logger.info("AVAssetWriter作成成功: \(m4aURL.path)")
        } catch {
            logger.error("AVAssetWriter作成失敗: \(error)")
            logger.error("エラー詳細: \(error.localizedDescription)")
            throw M4AEncoderError.encodingFailed
        }
        
        // パススルー設定（圧縮されたまま書き込み）
        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
        audioInput.expectsMediaDataInRealTime = false
        logger.info("AVAssetWriterInput作成完了")
        
        guard assetWriter.canAdd(audioInput) else {
            logger.error("オーディオ入力を追加できません")
            logger.error("ライター状態: \(assetWriter.status.rawValue)")
            
            // AVAssetWriterStatusの詳細を出力
            switch assetWriter.status {
            case .unknown:
                logger.error("ライター状態: unknown")
            case .writing:
                logger.error("ライター状態: writing")
            case .completed:
                logger.error("ライター状態: completed")
            case .failed:
                logger.error("ライター状態: failed")
                if let error = assetWriter.error {
                    logger.error("ライターエラー: \(error)")
                }
            case .cancelled:
                logger.error("ライター状態: cancelled")
            @unknown default:
                logger.error("ライター状態: unknown default")
            }
            
            throw M4AEncoderError.encodingFailed
        }
        
        assetWriter.add(audioInput)
        logger.info("オーディオ入力追加完了")
        
        // メタデータ設定
        if let metadata = metadata {
            assetWriter.metadata = createAVMetadataItems(from: metadata)
        }
        
        // 読み込みと書き込みを開始
        guard assetReader.startReading() else {
            logger.error("読み込み開始失敗: \(assetReader.error?.localizedDescription ?? "不明")")
            if let error = assetReader.error {
                logger.error("リーダーエラー詳細: \(error)")
            }
            throw M4AEncoderError.encodingFailed
        }
        logger.info("AVAssetReader読み込み開始成功")
        
        guard assetWriter.startWriting() else {
            logger.error("書き込み開始失敗: \(assetWriter.error?.localizedDescription ?? "不明")")
            if let error = assetWriter.error {
                logger.error("ライターエラー詳細: \(error)")
            }
            throw M4AEncoderError.encodingFailed
        }
        logger.info("AVAssetWriter書き込み開始成功")
        
        assetWriter.startSession(atSourceTime: .zero)
        logger.info("セッション開始完了")
        
        // サンプルバッファをコピー
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let backgroundQueue = DispatchQueue.global(qos: .userInitiated)
            
            audioInput.requestMediaDataWhenReady(on: backgroundQueue) { [self] in
                logger.info("サンプルバッファ処理開始")
                var bufferCount = 0
                
                while audioInput.isReadyForMoreMediaData {
                    // サンプルバッファを読み込み
                    if let sampleBuffer = readerOutput.copyNextSampleBuffer() {
                        bufferCount += 1
                        
                        // そのまま書き込み（パススルー）
                        if !audioInput.append(sampleBuffer) {
                            logger.error("サンプルバッファ追加失敗 (バッファ数: \(bufferCount))")
                            continuation.resume(throwing: M4AEncoderError.encodingFailed)
                            return
                        }
                        
                        if bufferCount % 100 == 0 {
                            logger.debug("サンプルバッファ処理中: \(bufferCount)個")
                        }
                    } else {
                        // 読み込み完了
                        logger.info("サンプルバッファ読み込み完了: 総数\(bufferCount)個")
                        audioInput.markAsFinished()
                        
                        // finishWritingをバックグラウンドで実行
                        Task.detached { [self] in
                            await assetWriter.finishWriting()
                            
                            if assetWriter.status == .completed {
                                logger.info("AVAssetWriter書き込み完了")
                                continuation.resume()
                            } else {
                                let error = assetWriter.error ?? M4AEncoderError.encodingFailed
                                logger.error("AVAssetWriter書き込み失敗: \(error)")
                                continuation.resume(throwing: error)
                            }
                        }
                        break
                    }
                }
            }
        }
        
        logger.info("音声->M4A変換完了")
    }

    /// AAC から M4A への変換（AVAssetReader/Writer使用）
    private func convertAACToM4A(aacURL: URL, 
                                m4aURL: URL, 
                                sampleRate: Int, 
                                channelCount: Int,
                                metadata: AudioMetadata?) async throws {
        
        logger.info("AAC->M4A変換開始")
        
        // AVAssetでAACファイルを読み込み
        let asset = AVURLAsset(url: aacURL)
        logger.info("AACファイル読み込み: \(aacURL.path)")
        
        // ファイル存在確認
        guard FileManager.default.fileExists(atPath: aacURL.path) else {
            logger.error("AACファイルが存在しません: \(aacURL.path)")
            throw M4AEncoderError.noAudioData
        }
        
        // ファイルサイズ確認
        if let attributes = try? FileManager.default.attributesOfItem(atPath: aacURL.path),
           let fileSize = attributes[.size] as? Int64 {
            logger.info("AACファイルサイズ: \(fileSize) bytes")
        }
        
        // アセットの読み込み可能性確認
        let isReadable = try await asset.load(.isReadable)
        logger.info("アセット読み込み可能: \(isReadable)")
        
        // オーディオトラックを取得
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        logger.info("検出されたオーディオトラック数: \(tracks.count)")
        
        guard let audioTrack = tracks.first else {
            logger.error("オーディオトラックが見つかりません")
            throw M4AEncoderError.noAudioData
        }
        
        // トラック情報をログ出力
        let formatDescriptions = try await audioTrack.load(.formatDescriptions)
        logger.info("フォーマット記述数: \(formatDescriptions.count)")
        
        for (index, formatDesc) in formatDescriptions.enumerated() {
            let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)?.pointee
            logger.info("フォーマット\(index): \(String(describing: asbd))")
        }
        
        // AVAssetReaderを作成
        let assetReader: AVAssetReader
        do {
            assetReader = try AVAssetReader(asset: asset)
            logger.info("AVAssetReader作成成功")
        } catch {
            logger.error("AVAssetReader作成失敗: \(error)")
            logger.error("エラー詳細: \(error.localizedDescription)")
            throw M4AEncoderError.encodingFailed
        }
        
        // パススルー設定（圧縮されたまま読み込み）
        let readerOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
        readerOutput.alwaysCopiesSampleData = false
        logger.info("AVAssetReaderTrackOutput作成完了")
        
        guard assetReader.canAdd(readerOutput) else {
            logger.error("リーダー出力を追加できません")
            logger.error("リーダー状態: \(assetReader.status.rawValue)")
            throw M4AEncoderError.encodingFailed
        }
        assetReader.add(readerOutput)
        logger.info("リーダー出力追加完了")
        
        // AVAssetWriterを作成
        let assetWriter: AVAssetWriter
        do {
            assetWriter = try AVAssetWriter(outputURL: m4aURL, fileType: .m4a)
            logger.info("AVAssetWriter作成成功: \(m4aURL.path)")
        } catch {
            logger.error("AVAssetWriter作成失敗: \(error)")
            logger.error("エラー詳細: \(error.localizedDescription)")
            throw M4AEncoderError.encodingFailed
        }
        
        // パススルー設定（圧縮されたまま書き込み）
        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
        audioInput.expectsMediaDataInRealTime = false
        logger.info("AVAssetWriterInput作成完了")
        
        guard assetWriter.canAdd(audioInput) else {
            logger.error("オーディオ入力を追加できません")
            logger.error("ライター状態: \(assetWriter.status.rawValue)")
            
            // AVAssetWriterStatusの詳細を出力
            switch assetWriter.status {
            case .unknown:
                logger.error("ライター状態: unknown")
            case .writing:
                logger.error("ライター状態: writing")
            case .completed:
                logger.error("ライター状態: completed")
            case .failed:
                logger.error("ライター状態: failed")
                if let error = assetWriter.error {
                    logger.error("ライターエラー: \(error)")
                }
            case .cancelled:
                logger.error("ライター状態: cancelled")
            @unknown default:
                logger.error("ライター状態: unknown default")
            }
            
            throw M4AEncoderError.encodingFailed
        }
        
        assetWriter.add(audioInput)
        logger.info("オーディオ入力追加完了")
        
        // メタデータ設定
        if let metadata = metadata {
            assetWriter.metadata = createAVMetadataItems(from: metadata)
        }
        
        // 読み込みと書き込みを開始
        guard assetReader.startReading() else {
            logger.error("読み込み開始失敗: \(assetReader.error?.localizedDescription ?? "不明")")
            if let error = assetReader.error {
                logger.error("リーダーエラー詳細: \(error)")
            }
            throw M4AEncoderError.encodingFailed
        }
        logger.info("AVAssetReader読み込み開始成功")
        
        guard assetWriter.startWriting() else {
            logger.error("書き込み開始失敗: \(assetWriter.error?.localizedDescription ?? "不明")")
            if let error = assetWriter.error {
                logger.error("ライターエラー詳細: \(error)")
            }
            throw M4AEncoderError.encodingFailed
        }
        logger.info("AVAssetWriter書き込み開始成功")
        
        assetWriter.startSession(atSourceTime: .zero)
        logger.info("セッション開始完了")
        
        // サンプルバッファをコピー
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let backgroundQueue = DispatchQueue.global(qos: .userInitiated)
            
            audioInput.requestMediaDataWhenReady(on: backgroundQueue) { [self] in
                logger.info("サンプルバッファ処理開始")
                var bufferCount = 0
                
                while audioInput.isReadyForMoreMediaData {
                    // サンプルバッファを読み込み
                    if let sampleBuffer = readerOutput.copyNextSampleBuffer() {
                        bufferCount += 1
                        
                        // そのまま書き込み（パススルー）
                        if !audioInput.append(sampleBuffer) {
                            logger.error("サンプルバッファ追加失敗 (バッファ数: \(bufferCount))")
                            continuation.resume(throwing: M4AEncoderError.encodingFailed)
                            return
                        }
                        
                        if bufferCount % 100 == 0 {
                            logger.debug("サンプルバッファ処理中: \(bufferCount)個")
                        }
                    } else {
                        // 読み込み完了
                        logger.info("サンプルバッファ読み込み完了: 総数\(bufferCount)個")
                        audioInput.markAsFinished()
                        
                        // finishWritingをバックグラウンドで実行
                        Task.detached { [self] in
                            await assetWriter.finishWriting()
                            
                            if assetWriter.status == .completed {
                                logger.info("AVAssetWriter書き込み完了")
                                continuation.resume()
                            } else {
                                let error = assetWriter.error ?? M4AEncoderError.encodingFailed
                                logger.error("AVAssetWriter書き込み失敗: \(error)")
                                continuation.resume(throwing: error)
                            }
                        }
                        break
                    }
                }
            }
        }
        
        logger.info("AAC->M4A変換完了")
    }

    
    /// メタデータからAVMetadataItemを作成
    private func createAVMetadataItems(from metadata: AudioMetadata) -> [AVMetadataItem] {
        var metadataItems: [AVMetadataItem] = []
        
        if let title = metadata.title {
            let titleItem = AVMutableMetadataItem()
            titleItem.identifier = .commonIdentifierTitle
            titleItem.value = title as NSString
            metadataItems.append(titleItem)
        }
        
        if let artist = metadata.artist {
            let artistItem = AVMutableMetadataItem()
            artistItem.identifier = .commonIdentifierArtist
            artistItem.value = artist as NSString
            metadataItems.append(artistItem)
        }
        
        if let album = metadata.album {
            let albumItem = AVMutableMetadataItem()
            albumItem.identifier = .commonIdentifierAlbumName
            albumItem.value = album as NSString
            metadataItems.append(albumItem)
        }
        
        if let date = metadata.date {
            let dateItem = AVMutableMetadataItem()
            dateItem.identifier = .commonIdentifierCreationDate
            dateItem.value = date as NSDate
            metadataItems.append(dateItem)
        }
        
        return metadataItems
    }
    
    /// MP3からM4Aへの変換（AVAssetExportSession使用）
    private func convertMP3ToM4A(mp3URL: URL, 
                                 m4aURL: URL, 
                                 metadata: AudioMetadata?) async throws {
        
        logger.info("MP3->M4A変換開始（AVAssetExportSession使用）")
        
        // AVAssetでMP3ファイルを読み込み
        let asset = AVURLAsset(url: mp3URL)
        logger.info("MP3ファイル読み込み: \(mp3URL.path)")
        
        // ファイル存在確認
        guard FileManager.default.fileExists(atPath: mp3URL.path) else {
            logger.error("MP3ファイルが存在しません: \(mp3URL.path)")
            throw M4AEncoderError.noAudioData
        }
        
        // エクスポートセッションを作成
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            logger.error("AVAssetExportSession作成失敗")
            throw M4AEncoderError.encodingFailed
        }
        
        // メタデータ設定
        if let metadata = metadata {
            exportSession.metadata = createAVMetadataItems(from: metadata)
        }
        
        logger.info("エクスポート開始")
        
        // エクスポート実行（新しいAPI使用）
        do {
            try await exportSession.export(to: m4aURL, as: .m4a)
            logger.info("MP3->M4A変換完了")
            
            // 出力ファイルサイズ確認
            if let attributes = try? FileManager.default.attributesOfItem(atPath: m4aURL.path),
               let fileSize = attributes[.size] as? Int64 {
                logger.info("変換後M4Aファイルサイズ: \(fileSize) bytes")
            }
            
        } catch {
            logger.error("エクスポート失敗: \(error)")
            throw M4AEncoderError.encodingFailed
        }
    }

    /// Synchsafe integer（7bit符号化）の計算
    private func calculateSynchsafeInteger(from data: Data, offset: Int) -> UInt32 {
        guard offset + 3 < data.count else { return 0 }
        
        let byte1 = UInt32(data[offset]) & 0x7F
        let byte2 = UInt32(data[offset + 1]) & 0x7F
        let byte3 = UInt32(data[offset + 2]) & 0x7F
        let byte4 = UInt32(data[offset + 3]) & 0x7F
        
        return (byte1 << 21) | (byte2 << 14) | (byte3 << 7) | byte4
    }
}

/// オーディオメタデータ
struct AudioMetadata {
    let title: String?
    let artist: String?
    let album: String?
    let date: Date?
    
    init(title: String? = nil, artist: String? = nil, album: String? = nil, date: Date? = nil) {
        self.title = title
        self.artist = artist
        self.album = album
        self.date = date
    }
}

/// M4Aエンコーダーエラー
enum M4AEncoderError: Error, LocalizedError {
    case noAudioData
    case unsupportedFormat
    case encodingFailed
    
    var errorDescription: String? {
        switch self {
        case .noAudioData:
            return "オーディオデータがありません"
        case .unsupportedFormat:
            return "サポートされていない形式です"
        case .encodingFailed:
            return "エンコーディングに失敗しました"
        }
    }
}