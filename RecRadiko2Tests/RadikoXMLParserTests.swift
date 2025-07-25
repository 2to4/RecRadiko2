//
//  RadikoXMLParserTests.swift
//  RecRadiko2Tests
//
//  Created by Claude on 2025/07/25.
//

import Testing
import Foundation
@testable import RecRadiko2

@Suite("RadikoXMLParser Tests")
struct RadikoXMLParserTests {
    
    // MARK: - 放送局リストパーステスト
    
    @Test("放送局XMLの正常パース")
    func parseStationListXML() throws {
        // Given
        let xmlString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <stations area_id="JP13" area_name="東京都">
            <station id="TBS" area_id="JP13">
                <name>TBSラジオ</name>
                <ascii_name>TBS RADIO</ascii_name>
                <logo>https://example.com/tbs_logo.png</logo>
                <banner>https://example.com/tbs_banner.png</banner>
                <href>https://www.tbsradio.jp/</href>
            </station>
            <station id="QRR" area_id="JP13">
                <name>文化放送</name>
                <ascii_name>JOQR</ascii_name>
                <logo>https://example.com/qrr_logo.png</logo>
                <banner>https://example.com/qrr_banner.png</banner>
                <href>https://www.joqr.co.jp/</href>
            </station>
        </stations>
        """
        
        let xmlData = xmlString.data(using: .utf8)!
        let parser = RadikoXMLParser()
        
        // When
        let stations = try parser.parseStationList(from: xmlData)
        
        // Then
        #expect(stations.count == 2)
        
        let tbsStation = stations.first { $0.id == "TBS" }
        #expect(tbsStation?.name == "TBSラジオ")
        #expect(tbsStation?.displayName == "TBS RADIO")
        #expect(tbsStation?.areaId == "JP13")
        #expect(tbsStation?.logoURL == "https://example.com/tbs_logo.png")
        #expect(tbsStation?.bannerURL == "https://example.com/tbs_banner.png")
        #expect(tbsStation?.href == "https://www.tbsradio.jp/")
        
        let qrrStation = stations.first { $0.id == "QRR" }
        #expect(qrrStation?.name == "文化放送")
        #expect(qrrStation?.displayName == "JOQR")
        #expect(qrrStation?.areaId == "JP13")
    }
    
    @Test("最小限の放送局XML")
    func parseMinimalStationXML() throws {
        // Given
        let xmlString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <stations area_id="JP13">
            <station id="TBS">
                <name>TBSラジオ</name>
                <ascii_name>TBS</ascii_name>
            </station>
        </stations>
        """
        
        let xmlData = xmlString.data(using: .utf8)!
        let parser = RadikoXMLParser()
        
        // When
        let stations = try parser.parseStationList(from: xmlData)
        
        // Then
        #expect(stations.count == 1)
        let station = stations[0]
        #expect(station.id == "TBS")
        #expect(station.name == "TBSラジオ")
        #expect(station.displayName == "TBS")
        #expect(station.logoURL == nil)
        #expect(station.bannerURL == nil)
        #expect(station.href == nil)
        #expect(station.areaId == "JP13")
    }
    
    @Test("空の放送局リスト")
    func parseEmptyStationList() throws {
        // Given
        let xmlString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <stations area_id="JP13" area_name="東京都">
        </stations>
        """
        
        let xmlData = xmlString.data(using: .utf8)!
        let parser = RadikoXMLParser()
        
        // When
        let stations = try parser.parseStationList(from: xmlData)
        
        // Then
        #expect(stations.isEmpty)
    }
    
    @Test("不正な放送局XMLのエラーハンドリング")
    func parseInvalidStationXML() throws {
        // Given
        let invalidXMLString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <invalid_root>
            <wrong_structure>
        """
        
        let xmlData = invalidXMLString.data(using: .utf8)!
        let parser = RadikoXMLParser()
        
        // When & Then
        #expect(throws: ParsingError.invalidXML) {
            try parser.parseStationList(from: xmlData)
        }
    }
    
    @Test("ID属性がない放送局の処理")
    func parseStationWithoutId() throws {
        // Given
        let xmlString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <stations area_id="JP13">
            <station>
                <name>TBSラジオ</name>
                <ascii_name>TBS</ascii_name>
            </station>
            <station id="QRR">
                <name>文化放送</name>
                <ascii_name>QRR</ascii_name>
            </station>
        </stations>
        """
        
        let xmlData = xmlString.data(using: .utf8)!
        let parser = RadikoXMLParser()
        
        // When
        let stations = try parser.parseStationList(from: xmlData)
        
        // Then - ID がない放送局は除外される
        #expect(stations.count == 1)
        #expect(stations[0].id == "QRR")
    }
    
    // MARK: - 番組リストパーステスト
    
    @Test("番組XMLの正常パース")
    func parseProgramListXML() throws {
        // Given
        let xmlString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <radiko>
            <stations>
                <station id="TBS">
                    <progs>
                        <date>20250725</date>
                        <prog id="prog_001" ft="20250725220000" to="20250726000000" ts="1" station_id="TBS">
                            <title>荻上チキ・Session</title>
                            <info>平日22時から放送中のニュース番組</info>
                            <pfm>荻上チキ,南部広美</pfm>
                            <img>https://example.com/program_image.jpg</img>
                        </prog>
                        <prog id="prog_002" ft="20250726010000" to="20250726020000" ts="1" station_id="TBS">
                            <title>深夜番組テスト</title>
                            <info>深夜1時の番組</info>
                            <pfm>深夜パーソナリティ</pfm>
                        </prog>
                    </progs>
                </station>
            </stations>
        </radiko>
        """
        
        let xmlData = xmlString.data(using: .utf8)!
        let parser = RadikoXMLParser()
        
        // When
        let programs = try parser.parseProgramList(from: xmlData)
        
        // Then
        #expect(programs.count == 2)
        
        let sessionProgram = programs.first { $0.id == "prog_001" }
        #expect(sessionProgram?.title == "荻上チキ・Session")
        #expect(sessionProgram?.description == "平日22時から放送中のニュース番組")
        #expect(sessionProgram?.personalities == ["荻上チキ", "南部広美"])
        #expect(sessionProgram?.isTimeFree == true)
        #expect(sessionProgram?.stationId == "TBS")
        #expect(sessionProgram?.imageURL == "https://example.com/program_image.jpg")
        
        let midnightProgram = programs.first { $0.id == "prog_002" }
        #expect(midnightProgram?.title == "深夜番組テスト")
        #expect(midnightProgram?.isMidnightProgram == true)
        #expect(midnightProgram?.personalities == ["深夜パーソナリティ"])
    }
    
    @Test("時刻フォーマットの処理")
    func parseTimeFormat() throws {
        // Given
        let xmlString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <radiko>
            <stations>
                <station id="TBS">
                    <progs>
                        <date>20250725</date>
                        <prog id="prog_001" ft="20250725220000" to="20250726000000" ts="1" station_id="TBS">
                            <title>テスト番組</title>
                        </prog>
                    </progs>
                </station>
            </stations>
        </radiko>
        """
        
        let xmlData = xmlString.data(using: .utf8)!
        let parser = RadikoXMLParser()
        
        // When
        let programs = try parser.parseProgramList(from: xmlData)
        
        // Then
        let program = programs.first!
        
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: program.startTime)
        #expect(startComponents.year == 2025)
        #expect(startComponents.month == 7)
        #expect(startComponents.day == 25)
        #expect(startComponents.hour == 22)
        #expect(startComponents.minute == 0)
        
        let endComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: program.endTime)
        #expect(endComponents.hour == 0) // 翌日0時
        #expect(endComponents.day == 26)
        
        // 継続時間の確認（2時間）
        #expect(program.duration == 7200.0)
    }
    
    @Test("パーソナリティの解析")
    func parsePersonalities() throws {
        // Given
        let xmlString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <radiko>
            <stations>
                <station id="TBS">
                    <progs>
                        <date>20250725</date>
                        <prog id="prog_001" ft="20250725140000" to="20250725150000" ts="1" station_id="TBS">
                            <title>単一パーソナリティ</title>
                            <pfm>伊集院光</pfm>
                        </prog>
                        <prog id="prog_002" ft="20250725150000" to="20250725160000" ts="1" station_id="TBS">
                            <title>複数パーソナリティ</title>
                            <pfm>荻上チキ,南部広美,袋とじ</pfm>
                        </prog>
                        <prog id="prog_003" ft="20250725160000" to="20250725170000" ts="1" station_id="TBS">
                            <title>空白パーソナリティ</title>
                            <pfm>  パーソナリティA  ,  パーソナリティB  </pfm>
                        </prog>
                        <prog id="prog_004" ft="20250725170000" to="20250725180000" ts="1" station_id="TBS">
                            <title>パーソナリティなし</title>
                        </prog>
                    </progs>
                </station>
            </stations>
        </radiko>
        """
        
        let xmlData = xmlString.data(using: .utf8)!
        let parser = RadikoXMLParser()
        
        // When
        let programs = try parser.parseProgramList(from: xmlData)
        
        // Then
        let singlePersonality = programs.first { $0.id == "prog_001" }
        #expect(singlePersonality?.personalities == ["伊集院光"])
        
        let multiplePersonalities = programs.first { $0.id == "prog_002" }
        #expect(multiplePersonalities?.personalities == ["荻上チキ", "南部広美", "袋とじ"])
        
        let trimmedPersonalities = programs.first { $0.id == "prog_003" }
        #expect(trimmedPersonalities?.personalities == ["パーソナリティA", "パーソナリティB"])
        
        let noPersonalities = programs.first { $0.id == "prog_004" }
        #expect(noPersonalities?.personalities.isEmpty == true)
    }
    
    @Test("タイムフリーフラグの処理")
    func parseTimeFreeFlag() throws {
        // Given
        let xmlString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <radiko>
            <stations>
                <station id="TBS">
                    <progs>
                        <date>20250725</date>
                        <prog id="prog_001" ft="20250725140000" to="20250725150000" ts="1" station_id="TBS">
                            <title>タイムフリー対応</title>
                        </prog>
                        <prog id="prog_002" ft="20250725150000" to="20250725160000" ts="0" station_id="TBS">
                            <title>タイムフリー非対応</title>
                        </prog>
                        <prog id="prog_003" ft="20250725160000" to="20250725170000" station_id="TBS">
                            <title>フラグなし</title>
                        </prog>
                    </progs>
                </station>
            </stations>
        </radiko>
        """
        
        let xmlData = xmlString.data(using: .utf8)!
        let parser = RadikoXMLParser()
        
        // When
        let programs = try parser.parseProgramList(from: xmlData)
        
        // Then
        let timeFreeProgram = programs.first { $0.id == "prog_001" }
        #expect(timeFreeProgram?.isTimeFree == true)
        
        let nonTimeFreeProgram = programs.first { $0.id == "prog_002" }
        #expect(nonTimeFreeProgram?.isTimeFree == false)
        
        let noFlagProgram = programs.first { $0.id == "prog_003" }
        #expect(noFlagProgram?.isTimeFree == false) // デフォルトはfalse
    }
    
    @Test("無効な時刻フォーマットの処理")
    func parseInvalidTimeFormat() throws {
        // Given
        let xmlString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <radiko>
            <stations>
                <station id="TBS">
                    <progs>
                        <date>20250725</date>
                        <prog id="prog_001" ft="invalid_time" to="20250725150000" ts="1" station_id="TBS">
                            <title>無効な開始時刻</title>
                        </prog>
                        <prog id="prog_002" ft="20250725140000" to="invalid_time" ts="1" station_id="TBS">
                            <title>無効な終了時刻</title>
                        </prog>
                        <prog id="prog_003" ft="20250725160000" to="20250725170000" ts="1" station_id="TBS">
                            <title>正常な番組</title>
                        </prog>
                    </progs>
                </station>
            </stations>
        </radiko>
        """
        
        let xmlData = xmlString.data(using: .utf8)!
        let parser = RadikoXMLParser()
        
        // When
        let programs = try parser.parseProgramList(from: xmlData)
        
        // Then - 無効な時刻の番組は除外される
        #expect(programs.count == 1)
        #expect(programs[0].id == "prog_003")
        #expect(programs[0].title == "正常な番組")
    }
    
    @Test("ID属性がない番組の処理")
    func parseProgramWithoutId() throws {
        // Given
        let xmlString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <radiko>
            <stations>
                <station id="TBS">
                    <progs>
                        <date>20250725</date>
                        <prog ft="20250725140000" to="20250725150000" ts="1" station_id="TBS">
                            <title>IDなし番組</title>
                        </prog>
                        <prog id="prog_002" ft="20250725150000" to="20250725160000" ts="1" station_id="TBS">
                            <title>正常な番組</title>
                        </prog>
                    </progs>
                </station>
            </stations>
        </radiko>
        """
        
        let xmlData = xmlString.data(using: .utf8)!
        let parser = RadikoXMLParser()
        
        // When
        let programs = try parser.parseProgramList(from: xmlData)
        
        // Then - IDがない番組は除外される
        #expect(programs.count == 1)
        #expect(programs[0].id == "prog_002")
    }
    
    // MARK: - バリデーションテスト
    
    @Test("放送局データの妥当性チェック - 正常系")
    func validateStationsSuccess() throws {
        // Given
        let parser = RadikoXMLParser()
        let stations = [
            createTestRadioStation(id: "TBS", name: "TBSラジオ"),
            createTestRadioStation(id: "QRR", name: "文化放送")
        ]
        
        // When
        let result = parser.validateStations(stations)
        
        // Then
        #expect(result.isValid == true)
        #expect(result.message == nil)
        if case .success = result {
            #expect(true)
        } else {
            #expect(Bool(false), "Expected success result")
        }
    }
    
    @Test("放送局データの妥当性チェック - 空のリスト")
    func validateEmptyStations() throws {
        // Given
        let parser = RadikoXMLParser()
        let stations: [RadioStation] = []
        
        // When
        let result = parser.validateStations(stations)
        
        // Then
        #expect(result.isValid == false)
        if case .error(let message) = result {
            #expect(message == "放送局データが見つかりません")
        } else {
            #expect(Bool(false), "Expected error result")
        }
    }
    
    @Test("放送局データの妥当性チェック - 重複ID")
    func validateDuplicateStationIds() throws {
        // Given
        let parser = RadikoXMLParser()
        let stations = [
            createTestRadioStation(id: "TBS", name: "TBSラジオ1"),
            createTestRadioStation(id: "TBS", name: "TBSラジオ2"),
            createTestRadioStation(id: "QRR", name: "文化放送")
        ]
        
        // When
        let result = parser.validateStations(stations)
        
        // Then
        #expect(result.isValid == true) // 警告レベル
        if case .warning(let message) = result {
            #expect(message.contains("重複する放送局ID"))
            #expect(message.contains("TBS"))
        } else {
            #expect(Bool(false), "Expected warning result")
        }
    }
    
    @Test("番組データの妥当性チェック - 正常系")
    func validateProgramsSuccess() throws {
        // Given
        let parser = RadikoXMLParser()
        let programs = [
            createTestRadioProgram(id: "prog_001", title: "番組1", startHour: 14),
            createTestRadioProgram(id: "prog_002", title: "番組2", startHour: 16)
        ]
        
        // When
        let result = parser.validatePrograms(programs)
        
        // Then
        #expect(result.isValid == true)
        if case .success = result {
            #expect(true)
        } else {
            #expect(Bool(false), "Expected success result")
        }
    }
    
    @Test("番組データの妥当性チェック - 空のタイトル")
    func validateProgramsEmptyTitle() throws {
        // Given
        let parser = RadikoXMLParser()
        let programs = [
            createTestRadioProgram(id: "prog_001", title: "", startHour: 14),
            createTestRadioProgram(id: "prog_002", title: "正常な番組", startHour: 16)
        ]
        
        // When
        let result = parser.validatePrograms(programs)
        
        // Then
        #expect(result.isValid == true) // 警告レベル
        if case .warning(let message) = result {
            #expect(message.contains("タイトルが空の番組"))
        } else {
            #expect(Bool(false), "Expected warning result")
        }
    }
    
    @Test("時間重複する番組の検出")
    func findOverlappingPrograms() throws {
        // Given
        let parser = RadikoXMLParser()
        let baseDate = Date()
        
        let programs = [
            // 14:00-15:00
            createTestRadioProgram(id: "prog_001", title: "番組1", 
                                 startTime: baseDate, 
                                 endTime: baseDate.addingTimeInterval(3600)),
            // 14:30-15:30 (重複)
            createTestRadioProgram(id: "prog_002", title: "番組2",
                                 startTime: baseDate.addingTimeInterval(1800),
                                 endTime: baseDate.addingTimeInterval(5400)),
            // 16:00-17:00 (重複なし)
            createTestRadioProgram(id: "prog_003", title: "番組3",
                                 startTime: baseDate.addingTimeInterval(7200),
                                 endTime: baseDate.addingTimeInterval(10800))
        ]
        
        // When
        let result = parser.validatePrograms(programs)
        
        // Then
        #expect(result.isValid == true) // 警告レベル
        if case .warning(let message) = result {
            #expect(message.contains("時間が重複する番組"))
        } else {
            #expect(Bool(false), "Expected warning result")
        }
    }
    
    // MARK: - XMLElement拡張テスト
    
    @Test("XMLElement childElement 拡張")
    func xmlElementChildElementExtension() throws {
        // Given
        let xmlString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <station id="TBS">
            <name>TBSラジオ</name>
            <ascii_name>TBS</ascii_name>
        </station>
        """
        
        let xmlDoc = try XMLDocument(data: xmlString.data(using: .utf8)!, options: [])
        let rootElement = xmlDoc.rootElement()!
        
        // When & Then
        let nameElement = rootElement.childElement(name: "name")
        #expect(nameElement?.stringValue == "TBSラジオ")
        
        let asciiNameElement = rootElement.childElement(name: "ascii_name")
        #expect(asciiNameElement?.stringValue == "TBS")
        
        let nonExistentElement = rootElement.childElement(name: "non_existent")
        #expect(nonExistentElement == nil)
    }
    
    @Test("XMLElement childElementText 拡張")
    func xmlElementChildElementTextExtension() throws {
        // Given
        let xmlString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <station id="TBS">
            <name>TBSラジオ</name>
            <description></description>
        </station>
        """
        
        let xmlDoc = try XMLDocument(data: xmlString.data(using: .utf8)!, options: [])
        let rootElement = xmlDoc.rootElement()!
        
        // When & Then
        #expect(rootElement.childElementText(name: "name") == "TBSラジオ")
        #expect(rootElement.childElementText(name: "description") == "")
        #expect(rootElement.childElementText(name: "non_existent") == nil)
    }
    
    @Test("XMLElement safeAttributeValue 拡張")
    func xmlElementSafeAttributeValueExtension() throws {
        // Given
        let xmlString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <station id="TBS" area_id="">
            <name>TBSラジオ</name>
        </station>
        """
        
        let xmlDoc = try XMLDocument(data: xmlString.data(using: .utf8)!, options: [])
        let rootElement = xmlDoc.rootElement()!
        
        // When & Then
        #expect(rootElement.safeAttributeValue(name: "id") == "TBS")
        #expect(rootElement.safeAttributeValue(name: "area_id") == "")
        #expect(rootElement.safeAttributeValue(name: "non_existent") == "")
    }
    
    // MARK: - ヘルパーメソッド
    
    private func createTestRadioStation(id: String, name: String) -> RadioStation {
        return RadioStation(
            id: id,
            name: name,
            displayName: id,
            logoURL: "https://example.com/\(id.lowercased())_logo.png",
            areaId: "JP13"
        )
    }
    
    private func createTestRadioProgram(id: String, 
                                      title: String, 
                                      startHour: Int) -> RadioProgram {
        let calendar = Calendar.current
        let today = Date()
        let startTime = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: today)!
        let endTime = calendar.date(byAdding: .hour, value: 1, to: startTime)!
        
        return createTestRadioProgram(id: id, title: title, startTime: startTime, endTime: endTime)
    }
    
    private func createTestRadioProgram(id: String,
                                      title: String,
                                      startTime: Date,
                                      endTime: Date) -> RadioProgram {
        return RadioProgram(
            id: id,
            title: title,
            description: "テスト用番組",
            startTime: startTime,
            endTime: endTime,
            personalities: ["テストパーソナリティ"],
            stationId: "TBS",
            imageURL: nil,
            isTimeFree: true
        )
    }
}