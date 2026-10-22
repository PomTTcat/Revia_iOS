import XCTest
import SQLite3
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

final class ReviewResetTests: XCTestCase {
    func testResetKeepsHistoryAndArchivesOriginalFutureWithoutChangingSentenceOrAudio() throws {
        let database = try Database(path: ":memory:")
        let id = try database.add(text: "Difficult", translation: "Note", date: "2026-10-01")
        let original = try XCTUnwrap(database.sentences().first)
        let dates = try Schedule.reviews(for: "2026-10-01")
        let audio = AudioRecord(sentenceID: id, text: original.text, voiceID: "voice", modelID: ElevenLabs.model, filename: AudioCache.filename(text: original.text, voice: "voice", model: ElevenLabs.model), version: AudioCache.version)
        try database.saveAudio(audio)
        try database.resetReviews(sentenceID: id, on: "2026-10-10")
        let expected = Set(dates.filter { $0 <= "2026-10-10" } + ["2026-10-10"] + (try Schedule.reviews(for: "2026-10-10")))
        XCTAssertEqual(Set(try database.reviews().map(\.date)), expected)
        XCTAssertFalse(try database.reviews().contains { $0.date == "2026-10-15" })
        XCTAssertEqual(try database.sentences().first, original)
        XCTAssertEqual(try database.audioRecords(), [audio])
        XCTAssertEqual(try database.exportBackup().sentences.first?.reviewDates, dates)
        XCTAssertEqual(try database.resetCycles(sentenceID: id).count, 1)
        try database.resetReviews(sentenceID: id, on: "2026-10-10")
        XCTAssertEqual(try database.resetCycles(sentenceID: id).count, 1)
        try database.resetReviews(sentenceID: id, on: "2026-10-20")
        let actual = Set(try database.reviews().map(\.date))
        XCTAssertFalse(actual.contains("2026-10-15"))
        XCTAssertFalse(actual.contains("2026-10-24"))
        XCTAssertTrue(actual.contains("2026-10-17"))
        XCTAssertTrue(actual.contains("2026-10-20"))
        XCTAssertTrue(actual.contains("2026-10-21"))
        XCTAssertEqual(try database.resetCycles(sentenceID: id).first?.reviewDates, try Schedule.reviews(for: "2026-10-10"))
        XCTAssertThrowsError(try database.resetReviews(sentenceID: id, on: "2026-10-19"))
        XCTAssertEqual(try database.resetCycles(sentenceID: id).count, 2)
        try database.delete(id: id)
        XCTAssertTrue(try database.reviews().isEmpty)
        XCTAssertTrue(try database.resetCycles(sentenceID: id).isEmpty)
        XCTAssertTrue(try database.audioRecords().isEmpty)
    }
    func testResetBackupAndReopenPreserveEveryCycleAndActiveDates() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        defer { for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: path + suffix) } }
        var database: Database? = try Database(path: path)
        let id = try database!.add(text: "Memory", translation: "", date: "2026-10-01")
        try database!.resetReviews(sentenceID: id, on: "2026-10-10")
        try database!.resetReviews(sentenceID: id, on: "2026-10-20")
        let effective = Set(try database!.reviews().map(\.date))
        let backup = try database!.exportBackup()
        XCTAssertEqual(backup.version, 2)
        let data = try backup.encoded()
        database = nil
        database = try Database(path: path)
        XCTAssertEqual(Set(try database!.reviews().map(\.date)), effective)
        let destination = try Database(path: ":memory:")
        XCTAssertEqual(try destination.importBackup(ReviaBackup.decode(data)), 1)
        XCTAssertEqual(Set(try destination.reviews().map(\.date)), effective)
        let newID = try XCTUnwrap(destination.sentences().first?.id)
        XCTAssertEqual(try destination.resetCycles(sentenceID: newID).count, 2)
        XCTAssertEqual(try destination.exportBackup().sentences.first?.reviewDates, try Schedule.reviews(for: "2026-10-01"))
        let malformed = BackupSentence(text: "Invalid", translation: "", learningDate: "2026-10-01", createdAt: Date(), reviewDates: try Schedule.reviews(for: "2026-10-01"), resetCycles: [BackupCycle(startedOn: "2026-10-10", createdAt: Date(), reviewDates: ["2026-10-11"])])
        XCTAssertThrowsError(try destination.importBackup(ReviaBackup(sentences: [malformed])))
        XCTAssertEqual(try destination.sentences().count, 1)
    }
    func testResetOnOriginalLearningDayDoesNotDuplicateDailyCard() throws {
        let database = try Database(path: ":memory:")
        let id = try database.add(text: "Today", translation: "", date: "2026-10-01")
        try database.resetReviews(sentenceID: id, on: "2026-10-01")
        XCTAssertFalse(try database.reviews().contains { $0.date == "2026-10-01" })
        XCTAssertEqual(try database.reviews().count, 15)
    }
}

final class StudyPlanTests: XCTestCase {
    func testBlocksAccumulateAndRequirePositiveSpacingWithAtMostFifteenNodes() throws {
        XCTAssertEqual(try StudyPlan.offsets(for: [1, 0, 2, 0]), [1, 3])
        XCTAssertEqual(try StudyPlan.offsets(for: [3, 0, 7, 0, 30, 0]), [3, 10, 40])
        XCTAssertEqual(try StudyPlan.offsets(for: [1, 2, 0]), [3])
        XCTAssertThrowsError(try StudyPlan.offsets(for: [0]))
        XCTAssertThrowsError(try StudyPlan.offsets(for: [1, 0, 0]))
        XCTAssertThrowsError(try StudyPlan.offsets(for: [1, 0, 2]))
        XCTAssertThrowsError(try StudyPlan.offsets(for: Array(repeating: [1, 0], count: 16).flatMap { $0 }))
        XCTAssertEqual(try StudyPlan.offsets(for: Array(repeating: [1, 0], count: 15).flatMap { $0 }).count, 15)
    }
    @MainActor
    func testCatalogAllowsThreeCustomPlansAndPersistsChanges() throws {
        let suite = "PlansTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let catalog = PlanCatalog(defaults: defaults)
        let first = StudyPlan(id: "first", name: "Short", offsets: [1, 3])
        try catalog.save(first)
        try catalog.save(StudyPlan(id: "second", name: "Long", offsets: [7, 30]))
        XCTAssertTrue(catalog.canAdd)
        try catalog.save(StudyPlan(id: "third", name: "Extra", offsets: [1]))
        XCTAssertEqual(catalog.all.count, 4)
        XCTAssertFalse(catalog.canAdd)
        XCTAssertThrowsError(try catalog.save(StudyPlan(id: "fourth", name: "Too many", offsets: [1])))
        try catalog.save(StudyPlan(id: first.id, name: "Renamed", offsets: [1, 4]))
        let restored = PlanCatalog(defaults: defaults)
        XCTAssertEqual(restored.custom.first?.name, "Renamed")
        XCTAssertEqual(restored.custom.first?.offsets, [1, 4])
        restored.delete(IndexSet(integer: 0))
        XCTAssertTrue(restored.canAdd)
        XCTAssertEqual(restored.all.count, 3)
    }
    func testCustomPlanPersistsAndResetUsesOriginalSnapshot() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        defer { for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: path + suffix) } }
        let plan = StudyPlan(id: "custom", name: "My plan", offsets: [1, 3])
        var database: Database? = try Database(path: path)
        let id = try database!.add(text: "Custom sentence", translation: "", date: "2026-10-01", plan: plan)
        XCTAssertEqual(try database!.reviews().map(\.date), ["2026-10-02", "2026-10-04"])
        database = nil
        database = try Database(path: path)
        XCTAssertEqual(try database!.sentences().first?.studyPlan, plan)
        XCTAssertEqual(try database!.reviews().count, 2)
        try database!.resetReviews(sentenceID: id, on: "2026-10-10")
        XCTAssertEqual(try database!.resetCycles(sentenceID: id).first?.reviewDates, ["2026-10-11", "2026-10-13"])
        let backup = try database!.exportBackup()
        XCTAssertEqual(backup.version, 3)
        let restored = try Database(path: ":memory:")
        try restored.importBackup(ReviaBackup.decode(backup.encoded()))
        XCTAssertEqual(try restored.sentences().first?.studyPlan, plan)
        XCTAssertEqual(try restored.reviews().map(\.date), try database!.reviews().map(\.date))
        let newID = try XCTUnwrap(restored.sentences().first?.id)
        try restored.resetReviews(sentenceID: newID, on: "2026-10-20")
        XCTAssertEqual(try restored.resetCycles(sentenceID: newID).last?.reviewDates, ["2026-10-21", "2026-10-23"])
    }
    func testInvalidPlanDoesNotPartiallyInsertSentence() throws {
        let database = try Database(path: ":memory:")
        let plan = StudyPlan(id: "invalid", name: "Broken", offsets: [3, 1])
        XCTAssertThrowsError(try database.add(text: "Bad plan", translation: "", date: "2026-10-01", plan: plan))
        XCTAssertTrue(try database.sentences().isEmpty)
        XCTAssertTrue(try database.reviews().isEmpty)
    }
}

final class PlanSelectionTests: XCTestCase {
    @MainActor
    func testLastSelectedPlanPersistsAndFallsBackAfterDeletion() throws {
        let suite = "PlanSelection.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let catalog = PlanCatalog(defaults: defaults)
        let plan = StudyPlan(id: "last", name: "Remember me", offsets: [1, 3])
        try catalog.save(plan)
        catalog.remember(plan.id)
        let restored = PlanCatalog(defaults: defaults)
        XCTAssertEqual(restored.preferredPlan, plan)
        restored.delete(IndexSet(integer: 0))
        XCTAssertEqual(restored.preferredPlan, .defaultPlan)
        XCTAssertEqual(PlanCatalog(defaults: defaults).preferredPlan, .defaultPlan)
    }
    func testDifferentPlansOnSameDayAreArchivedAndRoundTripCorrectly() throws {
        let database = try Database(path: ":memory:")
        let original = StudyPlan(id: "original", name: "Original", offsets: [1, 5, 8])
        let first = StudyPlan(id: "first", name: "First", offsets: [1, 3])
        let second = StudyPlan(id: "second", name: "Second", offsets: [7])
        let id = try database.add(text: "Change my plan", translation: "", date: "2026-10-01", plan: original)
        try database.resetReviews(sentenceID: id, on: "2026-10-10", plan: first)
        try database.resetReviews(sentenceID: id, on: "2026-10-10", plan: second)
        XCTAssertEqual(try database.resetCycles(sentenceID: id).count, 2)
        XCTAssertFalse(try database.reviews().contains { $0.date == "2026-10-11" })
        XCTAssertTrue(try database.reviews().contains { $0.date == "2026-10-17" })
        try database.resetReviews(sentenceID: id, on: "2026-10-10", plan: .defaultPlan)
        try database.resetReviews(sentenceID: id, on: "2026-10-10", plan: .defaultPlan)
        XCTAssertEqual(try database.resetCycles(sentenceID: id).count, 3)
        try database.resetReviews(sentenceID: id, on: "2026-10-20")
        XCTAssertEqual(try database.resetCycles(sentenceID: id).last?.reviewDates.count, 15)
        XCTAssertEqual(try database.sentences().first?.studyPlan, original)
        let backup = try database.exportBackup()
        XCTAssertEqual(backup.version, 4)
        let restored = try Database(path: ":memory:")
        try restored.importBackup(ReviaBackup.decode(backup.encoded()))
        XCTAssertEqual(try restored.reviews().map(\.date), try database.reviews().map(\.date))
        let restoredID = try XCTUnwrap(restored.sentences().first?.id)
        XCTAssertEqual(try restored.resetCycles(sentenceID: restoredID).map { $0.reviewDates.count }, [2, 1, 15, 15])
        try restored.delete(id: restoredID)
        XCTAssertTrue(try restored.resetCycles(sentenceID: restoredID).isEmpty)
    }
    func testVersionFiveMigrationPreservesCyclesAndAllowsSameDayPlanChange() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        defer { for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: path + suffix) } }
        var database: Database? = try Database(path: path)
        let id = try database!.add(text: "Legacy", translation: "", date: "2026-10-01")
        database = nil
        var raw: OpaquePointer?
        XCTAssertEqual(sqlite3_open(path, &raw), SQLITE_OK)
        let legacyDates = try Schedule.reviews(for: "2026-10-10")
        let rows = legacyDates.map { "INSERT INTO cycle_reviews VALUES (42, '\($0)');" }.joined(separator: "\n")
        let sql = """
            PRAGMA foreign_keys = OFF;
            DROP TABLE cycle_plans;
            DROP TABLE cycle_reviews;
            DROP TABLE review_cycles;
            CREATE TABLE review_cycles (id INTEGER PRIMARY KEY AUTOINCREMENT, sentence_id INTEGER NOT NULL REFERENCES sentences(id) ON DELETE CASCADE, started_on TEXT NOT NULL, created_at TEXT NOT NULL, UNIQUE(sentence_id, started_on));
            CREATE TABLE cycle_reviews (cycle_id INTEGER NOT NULL REFERENCES review_cycles(id) ON DELETE CASCADE, review_date TEXT NOT NULL, PRIMARY KEY(cycle_id, review_date));
            INSERT INTO review_cycles VALUES (42, \(id), '2026-10-10', '2026-10-10T09:00:00Z');
            \(rows)
            PRAGMA user_version = 5;
            """
        let result = sqlite3_exec(raw, sql, nil, nil, nil)
        sqlite3_close(raw)
        XCTAssertEqual(result, SQLITE_OK)
        database = try Database(path: path)
        XCTAssertEqual(try database!.resetCycles(sentenceID: id).first?.reviewDates, legacyDates)
        let plan = StudyPlan(id: "short", name: "Short", offsets: [2])
        try database!.resetReviews(sentenceID: id, on: "2026-10-10", plan: plan)
        XCTAssertEqual(try database!.resetCycles(sentenceID: id).count, 2)
        XCTAssertTrue(try database!.reviews().contains { $0.date == "2026-10-12" })
        try database!.delete(id: id)
        XCTAssertTrue(try database!.resetCycles(sentenceID: id).isEmpty)
    }
}
