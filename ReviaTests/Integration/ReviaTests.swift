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
