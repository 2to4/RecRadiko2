//
//  RadikoXMLParser.swift
//  RecRadiko2
//
//  Created by Claude on 2025/07/25.
//

import Foundation

/// XMLパーサープロトコル
protocol XMLParserProtocol {
    /// 放送局リストXMLをパース
    /// - Parameter data: XMLデータ
    /// - Returns: 放送局配列
    func parseStationList(from data: Data) throws -> [RadioStation]
    
    /// 番組リストXMLをパース
    /// - Parameter data: XMLデータ
    /// - Returns: 番組配列
    func parseProgramList(from data: Data) throws -> [RadioProgram]
}

/// Radiko XMLパーサー実装
class RadikoXMLParser: XMLParserProtocol {
    
    // MARK: - XMLParserProtocol Implementation
    
    func parseStationList(from data: Data) throws -> [RadioStation] {
        let xml: XMLDocument
        do {
            xml = try XMLDocument(data: data, options: [])
        } catch {
            throw ParsingError.invalidXML
        }
        
        guard let root = xml.rootElement() else {
            throw ParsingError.invalidXML
        }
        
        let stationNodes: [XMLNode]
        do {
            stationNodes = try root.nodes(forXPath: "//station")
        } catch {
            throw ParsingError.invalidXML
        }
        
        return stationNodes.compactMap { node in
            guard let element = node as? XMLElement else { return nil }
            return parseStation(from: element, areaId: root.attribute(forName: "area_id")?.stringValue)
        }
    }
    
    func parseProgramList(from data: Data) throws -> [RadioProgram] {
        let xml: XMLDocument
        do {
            xml = try XMLDocument(data: data, options: [])
        } catch {
            throw ParsingError.invalidXML
        }
        
        guard let root = xml.rootElement() else {
            throw ParsingError.invalidXML
        }
        
        let programNodes: [XMLNode]
        do {
            programNodes = try root.nodes(forXPath: "//prog")
        } catch {
            throw ParsingError.invalidXML
        }
        
        return programNodes.compactMap { node in
            guard let element = node as? XMLElement else { return nil }
            return parseProgram(from: element)
        }
    }
    
    // MARK: - Private Methods
    
    /// 放送局要素をパース
    /// - Parameters:
    ///   - element: XMLElement
    ///   - areaId: エリアID
    /// - Returns: RadioStation（パース失敗時はnil）
    private func parseStation(from element: XMLElement, areaId: String?) -> RadioStation? {
        guard let stationId = element.attribute(forName: "id")?.stringValue,
              !stationId.isEmpty else {
            return nil
        }
        
        let name = element.childElement(name: "name")?.stringValue ?? ""
        let displayName = element.childElement(name: "ascii_name")?.stringValue ?? ""
        let logoURL = element.childElement(name: "logo")?.stringValue
        let stationAreaId = element.attribute(forName: "area_id")?.stringValue ?? areaId ?? ""
        let bannerURL = element.childElement(name: "banner")?.stringValue
        let href = element.childElement(name: "href")?.stringValue
        
        return RadioStation(
            id: stationId,
            name: name,
            displayName: displayName,
            logoURL: logoURL,
            areaId: stationAreaId,
            bannerURL: bannerURL,
            href: href
        )
    }
    
    /// 番組要素をパース
    /// - Parameter element: XMLElement
    /// - Returns: RadioProgram（パース失敗時はnil）
    private func parseProgram(from element: XMLElement) -> RadioProgram? {
        guard let programId = element.attribute(forName: "id")?.stringValue,
              !programId.isEmpty else {
            return nil
        }
        
        let title = element.childElement(name: "title")?.stringValue ?? ""
        let description = element.childElement(name: "info")?.stringValue ?? ""
        let imageURL = element.childElement(name: "img")?.stringValue
        let stationId = element.attribute(forName: "station_id")?.stringValue ?? ""
        let isTimeFree = element.attribute(forName: "ts")?.stringValue == "1"
        
        // 時刻解析
        guard let startTimeStr = element.attribute(forName: "ft")?.stringValue,
              let endTimeStr = element.attribute(forName: "to")?.stringValue,
              let startTime = TimeConverter.parseRadikoTime(startTimeStr),
              let endTime = TimeConverter.parseRadikoTime(endTimeStr) else {
            return nil
        }
        
        // パーソナリティ解析
        let personalities = parsePfm(element.childElement(name: "pfm")?.stringValue)
        
        return RadioProgram(
            id: programId,
            title: title,
            description: description,
            startTime: startTime,
            endTime: endTime,
            personalities: personalities,
            stationId: stationId,
            imageURL: imageURL,
            isTimeFree: isTimeFree
        )
    }
    
    /// パーソナリティ文字列をパース
    /// - Parameter pfmString: パーソナリティ文字列（カンマ区切り）
    /// - Returns: パーソナリティ配列
    private func parsePfm(_ pfmString: String?) -> [String] {
        guard let pfm = pfmString, !pfm.isEmpty else { return [] }
        
        return pfm.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - XMLElement Helper Extension
extension XMLElement {
    /// 指定名の子要素を取得
    /// - Parameter name: 要素名
    /// - Returns: 子要素（見つからない場合はnil）
    func childElement(name: String) -> XMLElement? {
        return self.elements(forName: name).first
    }
    
    /// 指定名の子要素のテキスト内容を取得
    /// - Parameter name: 要素名
    /// - Returns: テキスト内容（見つからない場合はnil）
    func childElementText(name: String) -> String? {
        return childElement(name: name)?.stringValue
    }
    
    /// 属性値を安全に取得
    /// - Parameter name: 属性名
    /// - Returns: 属性値（見つからない場合は空文字）
    func safeAttributeValue(name: String) -> String {
        return attribute(forName: name)?.stringValue ?? ""
    }
}

// MARK: - Validation Extensions
extension RadikoXMLParser {
    
    /// 放送局データの妥当性チェック
    /// - Parameter stations: 放送局配列
    /// - Returns: 検証結果
    func validateStations(_ stations: [RadioStation]) -> ValidationResult {
        if stations.isEmpty {
            return .error("放送局データが見つかりません")
        }
        
        let duplicateIds = Dictionary(grouping: stations, by: { $0.id })
            .filter { $1.count > 1 }
            .keys
        
        if !duplicateIds.isEmpty {
            return .warning("重複する放送局ID: \(duplicateIds.joined(separator: ", "))")
        }
        
        let invalidStations = stations.filter { $0.name.isEmpty }
        if !invalidStations.isEmpty {
            return .warning("名前が空の放送局が\(invalidStations.count)件あります")
        }
        
        return .success
    }
    
    /// 番組データの妥当性チェック
    /// - Parameter programs: 番組配列
    /// - Returns: 検証結果
    func validatePrograms(_ programs: [RadioProgram]) -> ValidationResult {
        if programs.isEmpty {
            return .warning("番組データが見つかりません")
        }
        
        let invalidPrograms = programs.filter { $0.title.isEmpty }
        if !invalidPrograms.isEmpty {
            return .warning("タイトルが空の番組が\(invalidPrograms.count)件あります")
        }
        
        let overlappingPrograms = findOverlappingPrograms(programs)
        if !overlappingPrograms.isEmpty {
            return .warning("時間が重複する番組が\(overlappingPrograms.count)組あります")
        }
        
        return .success
    }
    
    /// 時間重複する番組を検出
    /// - Parameter programs: 番組配列
    /// - Returns: 重複する番組ペア
    private func findOverlappingPrograms(_ programs: [RadioProgram]) -> [(RadioProgram, RadioProgram)] {
        var overlapping: [(RadioProgram, RadioProgram)] = []
        
        for i in 0..<programs.count {
            for j in (i+1)..<programs.count {
                let program1 = programs[i]
                let program2 = programs[j]
                
                // 同じ放送局の番組のみチェック
                if program1.stationId == program2.stationId &&
                   TimeConverter.isTimeOverlapping(program1, program2) {
                    overlapping.append((program1, program2))
                }
            }
        }
        
        return overlapping
    }
    
    /// 検証結果
    enum ValidationResult {
        case success
        case warning(String)
        case error(String)
        
        var isValid: Bool {
            switch self {
            case .success, .warning:
                return true
            case .error:
                return false
            }
        }
        
        var message: String? {
            switch self {
            case .success:
                return nil
            case .warning(let message), .error(let message):
                return message
            }
        }
    }
}