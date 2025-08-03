//
//  AppLogger.swift
//  RecRadiko2
//
//  Created by Claude on 2025/08/03.
//

import Foundation
import AppKit
import os.log

/// ログレベル列挙型
public enum LogLevel: Int, CaseIterable, Comparable {
    case verbose = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4
    
    var emoji: String {
        switch self {
        case .verbose: return "💬"
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }
    
    var description: String {
        switch self {
        case .verbose: return "VERBOSE"
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        }
    }
    
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// 高性能・スレッドセーフなアプリケーションロガー
public final class AppLogger {
    
    // MARK: - Singleton
    public static let shared = AppLogger()
    
    // MARK: - Properties
    private let isDebugBuild: Bool
    private let logQueue: DispatchQueue
    private let fileManager: FileManager
    private let dateFormatter: DateFormatter
    private let timeFormatter: DateFormatter
    
    private var logDirectory: URL
    private var currentLogFile: URL?
    private var logFileHandle: FileHandle?
    
    // 設定可能なプロパティ
    public var minimumLogLevel: LogLevel = .debug
    public var enableConsoleOutput: Bool = true
    public var enableFileOutput: Bool = true
    public var maxLogFileSize: Int = 10 * 1024 * 1024 // 10MB
    public var maxLogFiles: Int = 5
    
    // MARK: - Initialization
    private init() {
        print("🚀 [AppLogger] 初期化開始")
        
        // デバッグビルド判定
        #if DEBUG
        isDebugBuild = true
        print("✅ [AppLogger] デバッグビルドを検出")
        #else
        isDebugBuild = false
        print("⚠️ [AppLogger] リリースビルドのため、ログ無効")
        #endif
        
        // 専用キューでスレッドセーフを保証
        logQueue = DispatchQueue(label: "AppLogger.queue", qos: .utility)
        fileManager = FileManager.default
        
        // 日付フォーマッター設定
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss.SSS"
        
        // ログディレクトリ初期化（アプリサンドボックス対応）
        do {
            // Application Support ディレクトリを取得
            let appSupportURL = try fileManager.url(for: .applicationSupportDirectory,
                                                   in: .userDomainMask,
                                                   appropriateFor: nil,
                                                   create: true)
            // アプリ専用ディレクトリ作成
            logDirectory = appSupportURL.appendingPathComponent("RecRadiko2").appendingPathComponent("logs")
            print("📁 [AppLogger] ログディレクトリ: \(logDirectory.path)")
        } catch {
            // フォールバック：一時ディレクトリを使用
            let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            logDirectory = tempDir.appendingPathComponent("RecRadiko2-logs")
            print("⚠️ [AppLogger] Application Supportディレクトリ取得失敗、一時ディレクトリを使用: \(logDirectory.path)")
            print("⚠️ [AppLogger] エラー: \(error)")
        }
        
        // 初期化処理
        initializeLogDirectory()
        setupCurrentLogFile()
        
        print("✅ [AppLogger] 初期化完了")
        
        // アプリ終了時のクリーンアップ
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }
    
    deinit {
        closeLogFile()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Logging Methods
    
    /// エラーログ出力
    public func error(_ message: String, category: String = "General", file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, message: message, category: category, file: file, function: function, line: line)
    }
    
    /// 警告ログ出力
    public func warning(_ message: String, category: String = "General", file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, message: message, category: category, file: file, function: function, line: line)
    }
    
    /// 情報ログ出力
    public func info(_ message: String, category: String = "General", file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, message: message, category: category, file: file, function: function, line: line)
    }
    
    /// デバッグログ出力
    public func debug(_ message: String, category: String = "General", file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, message: message, category: category, file: file, function: function, line: line)
    }
    
    /// 詳細ログ出力
    public func verbose(_ message: String, category: String = "General", file: String = #file, function: String = #function, line: Int = #line) {
        log(.verbose, message: message, category: category, file: file, function: function, line: line)
    }
    
    // MARK: - Core Logging Method
    
    private func log(_ level: LogLevel, message: String, category: String, file: String, function: String, line: Int) {
        // デバッグビルドのみで動作
        guard isDebugBuild else { return }
        
        // ログレベルフィルタリング
        guard level >= minimumLogLevel else { return }
        
        let timestamp = timeFormatter.string(from: Date())
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let location = "\(fileName):\(function):\(line)"
        
        let logEntry = "[\(timestamp)] \(level.emoji) [\(level.description)] [\(category)] \(message) - \(location)"
        
        // 非同期でログ処理（UIブロック防止）
        logQueue.async { [weak self] in
            self?.processLog(logEntry)
        }
    }
    
    // MARK: - Log Processing
    
    private func processLog(_ logEntry: String) {
        // コンソール出力
        if enableConsoleOutput {
            print(logEntry)
        }
        
        // ファイル出力
        if enableFileOutput {
            writeToFile(logEntry)
        }
    }
    
    // MARK: - File Management
    
    private func initializeLogDirectory() {
        print("📁 [AppLogger] ログディレクトリ作成開始: \(logDirectory.path)")
        do {
            try fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
            print("✅ [AppLogger] ログディレクトリ作成成功")
        } catch {
            print("❌ [AppLogger] ログディレクトリ作成失敗: \(error)")
        }
    }
    
    private func setupCurrentLogFile() {
        let today = dateFormatter.string(from: Date())
        let fileName = "RecRadiko2_\(today).log"
        currentLogFile = logDirectory.appendingPathComponent(fileName)
        
        print("📝 [AppLogger] ログファイル設定: \(fileName)")
        
        guard let logFile = currentLogFile else { 
            print("❌ [AppLogger] ログファイルパス設定失敗")
            return 
        }
        
        print("📝 [AppLogger] ログファイルパス: \(logFile.path)")
        
        // 既存ファイルのサイズチェック
        if fileManager.fileExists(atPath: logFile.path) {
            print("📄 [AppLogger] 既存ログファイル検出")
            do {
                let attributes = try fileManager.attributesOfItem(atPath: logFile.path)
                if let fileSize = attributes[.size] as? Int, fileSize > maxLogFileSize {
                    print("📄 [AppLogger] ファイルサイズ超過、ローテーション実行")
                    rotateLogFile()
                    return
                }
            } catch {
                print("❌ [AppLogger] ファイルサイズ取得失敗: \(error)")
            }
        } else {
            print("📝 [AppLogger] 新規ログファイル作成")
        }
        
        openLogFile()
    }
    
    private func openLogFile() {
        guard let logFile = currentLogFile else { 
            print("❌ [AppLogger] ログファイルパスが設定されていません")
            return 
        }
        
        print("📂 [AppLogger] ログファイル開始: \(logFile.path)")
        
        // ファイルが存在しない場合は作成
        if !fileManager.fileExists(atPath: logFile.path) {
            print("📄 [AppLogger] ログファイル新規作成")
            print("📄 [AppLogger] 作成パス: \(logFile.path)")
            print("📄 [AppLogger] 親ディレクトリ存在確認: \(fileManager.fileExists(atPath: logFile.deletingLastPathComponent().path))")
            
            let created = fileManager.createFile(atPath: logFile.path, contents: nil, attributes: nil)
            print("📄 [AppLogger] ファイル作成結果: \(created)")
            
            if !created {
                print("❌ [AppLogger] ファイル作成失敗の詳細調査")
                // ディレクトリの書き込み権限確認
                let directoryPath = logFile.deletingLastPathComponent().path
                let directoryAttributes = try? fileManager.attributesOfItem(atPath: directoryPath)
                print("📄 [AppLogger] ディレクトリ属性: \(String(describing: directoryAttributes))")
                
                // 空のDataで強制的にファイル書き込みテスト
                do {
                    try Data().write(to: logFile)
                    print("✅ [AppLogger] Data.write()でファイル作成成功")
                } catch {
                    print("❌ [AppLogger] Data.write()も失敗: \(error)")
                }
            }
        } else {
            print("📄 [AppLogger] 既存ログファイルを開く")
        }
        
        do {
            logFileHandle = try FileHandle(forWritingTo: logFile)
            logFileHandle?.seekToEndOfFile()
            print("✅ [AppLogger] ログファイルハンドル取得成功")
            
            // ヘッダー追加
            let header = "=== RecRadiko2 Debug Log Session Started at \(Date()) ===\n"
            writeRawToFile(header)
            print("✅ [AppLogger] ログファイルヘッダー書き込み完了")
        } catch {
            print("❌ [AppLogger] ログファイル開始失敗: \(error)")
            logFileHandle = nil
        }
    }
    
    private func writeToFile(_ logEntry: String) {
        writeRawToFile(logEntry + "\n")
        
        // ファイルサイズチェック
        checkLogFileRotation()
    }
    
    private func writeRawToFile(_ content: String) {
        guard let handle = logFileHandle,
              let data = content.data(using: .utf8) else { return }
        
        handle.write(data)
        handle.synchronizeFile()
    }
    
    private func checkLogFileRotation() {
        guard let logFile = currentLogFile else { return }
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: logFile.path)
            if let fileSize = attributes[.size] as? Int, fileSize > maxLogFileSize {
                rotateLogFile()
            }
        } catch {
            print("❌ [AppLogger] ファイルサイズチェック失敗: \(error)")
        }
    }
    
    private func rotateLogFile() {
        closeLogFile()
        cleanupOldLogFiles()
        setupCurrentLogFile()
    }
    
    private func closeLogFile() {
        logFileHandle?.closeFile()
        logFileHandle = nil
    }
    
    private func cleanupOldLogFiles() {
        do {
            let logFiles = try fileManager.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: [.creationDateKey])
                .filter { $0.pathExtension == "log" }
                .sorted { file1, file2 in
                    let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    return date1 > date2
                }
            
            // 制限を超えた古いログファイルを削除
            if logFiles.count > maxLogFiles {
                let filesToDelete = Array(logFiles.dropFirst(maxLogFiles))
                for file in filesToDelete {
                    try fileManager.removeItem(at: file)
                    print("🗑️ [AppLogger] 古いログファイル削除: \(file.lastPathComponent)")
                }
            }
        } catch {
            print("❌ [AppLogger] ログファイルクリーンアップ失敗: \(error)")
        }
    }
    
    @objc private func applicationWillTerminate() {
        logQueue.sync {
            writeRawToFile("=== RecRadiko2 Debug Log Session Ended at \(Date()) ===\n")
            closeLogFile()
        }
    }
    
    // MARK: - Public Utilities
    
    /// 現在のログファイルパスを取得
    public var currentLogFilePath: String? {
        return currentLogFile?.path
    }
    
    /// ログディレクトリパスを取得
    public var logDirectoryPath: String {
        return logDirectory.path
    }
    
    /// ログファイル一覧を取得
    public func getLogFiles() -> [URL] {
        do {
            return try fileManager.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "log" }
                .sorted { $0.lastPathComponent > $1.lastPathComponent }
        } catch {
            print("❌ [AppLogger] ログファイル一覧取得失敗: \(error)")
            return []
        }
    }
}

// MARK: - 便利な拡張

extension AppLogger {
    /// カテゴリ付きロガーを作成
    public func category(_ name: String) -> CategoryLogger {
        return CategoryLogger(logger: self, category: name)
    }
}

/// カテゴリ専用ロガー
public struct CategoryLogger {
    private let logger: AppLogger
    private let category: String
    
    init(logger: AppLogger, category: String) {
        self.logger = logger
        self.category = category
    }
    
    public func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logger.error(message, category: category, file: file, function: function, line: line)
    }
    
    public func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logger.warning(message, category: category, file: file, function: function, line: line)
    }
    
    public func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logger.info(message, category: category, file: file, function: function, line: line)
    }
    
    public func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logger.debug(message, category: category, file: file, function: function, line: line)
    }
    
    public func verbose(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logger.verbose(message, category: category, file: file, function: function, line: line)
    }
}