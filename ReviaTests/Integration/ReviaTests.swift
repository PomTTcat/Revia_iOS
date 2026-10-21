import XCTest
@testable import Revia

final class ReviaTests: XCTestCase {
    func testFifteenFixedReviewsAndMonthEnd() throws {
        let dates = try Schedule.reviews(for: "2026-10-01")
        XCTAssertEqual(dates, ["2026-10-02", "2026-10-04", "2026-10-08", "2026-10-15", "2026-10-31", "2026-11-30", "2026-12-31", "2027-01-31", "2027-02-28", "2027-03-31", "2027-04-30", "2027-05-31", "2027-06-30", "2027-07-31", "2027-08-31"])
        XCTAssertEqual(Set(dates).count, 15)
        let leap = try Schedule.reviews(for: "2027-12-31")
        XCTAssertEqual(Array(leap[4...7]), ["2028-01-30", "2028-02-29", "2028-03-30", "2028-04-30"])
        XCTAssertThrowsError(try Schedule.date("2026-02-30"))
    }
    func testPersistenceAndCascadeDelete() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        defer { for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: path + suffix) } }
        var database: Database? = try Database(path: path)
        try database!.add(text: "今日も。", translation: "今天也。", date: "2026-10-01")
        try database!.add(text: "明日も。", translation: "", date: "2026-10-02")
        XCTAssertEqual(try database!.reviews().count, 30)
        let original = try XCTUnwrap(database!.reviews().first { $0.date == "2026-10-02" })
        database = nil
        database = try Database(path: path)
        XCTAssertEqual(try database!.sentences().count, 2)
        XCTAssertEqual(try database!.reviews().count, 30)
        try database!.delete(id: original.sentenceID)
        XCTAssertEqual(try database!.sentences().count, 1)
        XCTAssertEqual(try database!.reviews().count, 15)
        XCTAssertFalse(try database!.reviews().contains { $0.sentenceID == original.sentenceID })
        XCTAssertThrowsError(try database!.add(text: "  ", translation: "", date: "2026-10-01"))
        XCTAssertEqual(try database!.sentences().count, 1)
    }
}

extension ReviaTests {
    func testAudioMetadataPersistsAndCascadesWithoutChangingSentences() throws {
        let database = try Database(path: ":memory:")
        let id = try database.add(text: "音声です。", translation: "", date: "2026-10-01")
        let filename = AudioCache.filename(text: "音声です。", voice: "voiceA", model: ElevenLabs.model)
        let record = AudioRecord(sentenceID: id, text: "音声です。", voiceID: "voiceA", modelID: ElevenLabs.model, filename: filename, version: AudioCache.version)
        try database.saveAudio(record)
        try database.saveAudio(record)
        XCTAssertEqual(try database.audioRecords(sentenceID: id), [record])
        XCTAssertEqual(try database.reviews().count, 15)
        try database.delete(id: id)
        XCTAssertTrue(try database.audioRecords().isEmpty)
        XCTAssertThrowsError(try database.saveAudio(record))
    }
    func testCacheVersionVoiceIdentityAndActualStorage() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = try AudioCache(directory: directory)
        let a = AudioCache.filename(text: "文。", voice: "voiceA", model: ElevenLabs.model)
        let b = AudioCache.filename(text: "文。", voice: "voiceB", model: ElevenLabs.model)
        XCTAssertNotEqual(a, b)
        XCTAssertNil(cache.existing(a))
        _ = try cache.write(Data([1, 2, 3]), filename: a)
        XCTAssertNotNil(cache.existing(a))
        XCTAssertEqual(try cache.bytes(), 3)
        XCTAssertThrowsError(try cache.url(for: "../escape.mp3"))
        try cache.remove(a)
        XCTAssertNil(cache.existing(a))
        XCTAssertEqual(try cache.bytes(), 0)
    }
}

extension ReviaTests {
    func testMemoryContentAcceptsMultipleLanguagesWithLegacyDatabaseColumn() throws {
        let database = try Database(path: ":memory:")
        let texts = ["A little every day.", "每天记住一点。", "毎日、少しずつ。"]
        for text in texts { try database.add(text: text, translation: "", date: "2026-10-01") }
        XCTAssertEqual(Set(try database.sentences().map(\.text)), Set(texts))
        XCTAssertEqual(try database.reviews().count, 45)
    }
}

final class CalendarFreshnessTests: XCTestCase {
    func testLearningDayTurnsGrayAfterMidnight() throws {
        let learned = try Schedule.date("2026-10-20")
        let today = try Schedule.date("2026-10-21")
        XCTAssertTrue(Schedule.isFresh(learningDate: "2026-10-20", on: learned, now: learned))
        XCTAssertFalse(Schedule.isFresh(learningDate: "2026-10-20", on: learned, now: today))
        XCTAssertFalse(Schedule.isFresh(learningDate: "2026-10-20", on: today, now: today))
        XCTAssertTrue(Schedule.isFresh(learningDate: "2026-10-21", on: today, now: today))
    }
    func testBackfilledAndFutureDatesAreNotGreen() throws {
        let today = try Schedule.date("2026-10-21")
        for day in ["2026-10-19", "2026-10-22"] {
            XCTAssertFalse(Schedule.isFresh(learningDate: day, on: try Schedule.date(day), now: today))
        }
    }
}

final class SentenceLibraryTests: XCTestCase {
    func testSearchAndCreationTimeOrderIgnoreLearningDate() {
        let old = Sentence(id: 1, text: "First sentence", translation: "晴天", learningDate: "2026-10-21", createdAt: Date(timeIntervalSince1970: 100))
        let newer = Sentence(id: 2, text: "Second sentence", translation: "雨天", learningDate: "2026-10-01", createdAt: Date(timeIntervalSince1970: 200))
        let sameTime = Sentence(id: 3, text: "THIRD", translation: "", learningDate: "2026-10-02", createdAt: newer.createdAt)
        XCTAssertEqual(SentenceLibrary.results([old, newer, sameTime], query: "  ").map(\.id), [3, 2, 1])
        XCTAssertEqual(SentenceLibrary.results([old, newer, sameTime], query: "third").map(\.id), [3])
        XCTAssertEqual(SentenceLibrary.results([old, newer], query: " 晴天 ").map(\.id), [1])
        XCTAssertTrue(SentenceLibrary.results([old, newer], query: "missing").isEmpty)
    }
    func testTimestampSurvivesDatabaseReopen() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".db")
        defer {
            for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: file.path + suffix) }
        }
        let before = Date().addingTimeInterval(-1)
        var database: Database? = try Database(path: file.path)
        try database!.add(text: "Saved sentence", translation: "", date: "2026-10-01")
        let saved = try XCTUnwrap(database!.sentences().first?.createdAt)
        XCTAssertGreaterThanOrEqual(saved, before)
        database = nil
        database = try Database(path: file.path)
        XCTAssertEqual(try database!.sentences().first?.createdAt, saved)
    }
}

final class BackupTests: XCTestCase {
    func testBackupRoundTripAndReopenPreserveActualSchedule() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        defer { for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: path + suffix) } }
        // An intentionally different valid plan must never be replaced by the current algorithm.
        let days = try (1...15).map { offset in
            Schedule.key(Schedule.calendar.date(byAdding: .day, value: offset, to: try Schedule.date("2026-10-01"))!)
        }
        let created = Date(timeIntervalSince1970: 1_790_000_000.125)
        let backup = ReviaBackup(sentences: [BackupSentence(text: "今日は晴れ。", translation: "晴天", learningDate: "2026-10-01", createdAt: created, reviewDates: days)])
        let data = try backup.encoded()
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(json.keys), ["format", "version", "exportedAt", "sentences"])
        let entry = try XCTUnwrap((json["sentences"] as? [[String: Any]])?.first)
        XCTAssertEqual(Set(entry.keys), ["text", "translation", "learningDate", "createdAt", "reviewDates"])
        var database: Database? = try Database(path: path)
        try database!.add(text: "Existing", translation: "", date: "2026-09-01")
        XCTAssertEqual(try database!.importBackup(ReviaBackup.decode(data)), 1)
        database = nil
        database = try Database(path: path)
        let restored = try XCTUnwrap(database!.sentences().first { $0.text == "今日は晴れ。" })
        XCTAssertEqual(restored.createdAt, created)
        XCTAssertEqual(restored.learningDate, "2026-10-01")
        XCTAssertEqual(restored.translation, "晴天")
        XCTAssertEqual(try database!.reviews().filter { $0.sentenceID == restored.id }.map(\.date).sorted(), days)
        XCTAssertTrue(try database!.audioRecords().isEmpty)
        let exported = try database!.exportBackup()
        XCTAssertEqual(exported.sentences.first { $0.text == restored.text }?.reviewDates, days)
        XCTAssertEqual(try database!.importBackup(ReviaBackup.decode(data)), 1)
        XCTAssertEqual(try database!.sentences().count, 3)
    }
    func testInvalidBackupImportsNothing() throws {
        let database = try Database(path: ":memory:")
        let valid = BackupSentence(text: "Valid", translation: "", learningDate: "2026-10-01", createdAt: Date(), reviewDates: try Schedule.reviews(for: "2026-10-01"))
        let invalid = BackupSentence(text: "Invalid", translation: "", learningDate: "2026-10-01", createdAt: Date(), reviewDates: ["2026-10-02"])
        XCTAssertThrowsError(try database.importBackup(ReviaBackup(sentences: [valid, invalid])))
        XCTAssertTrue(try database.sentences().isEmpty)
        XCTAssertTrue(try database.reviews().isEmpty)
        XCTAssertThrowsError(try ReviaBackup.decode(Data("{}".utf8)))
        let data = try ReviaBackup(sentences: [valid]).encoded()
        let unknown = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "\"version\" : 1", with: "\"version\" : 99")
        XCTAssertThrowsError(try ReviaBackup.decode(Data(unknown.utf8)))
    }
}
