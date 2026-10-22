import Foundation
import SQLite3

final class Database {
    private var connection: OpaquePointer?
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    init(path: String) throws {
        guard sqlite3_open(path, &connection) == SQLITE_OK else {
            let message = connection.map { String(cString: sqlite3_errmsg($0)) } ?? L("db_open_failed")
            sqlite3_close(connection)
            connection = nil
            throw ReviaError.message(message)
        }
        do {
            try execute("""
                PRAGMA foreign_keys = ON;
                PRAGMA journal_mode = WAL;
                CREATE TABLE IF NOT EXISTS sentences (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  japanese TEXT NOT NULL CHECK(length(trim(japanese)) > 0),
                  translation TEXT NOT NULL DEFAULT '',
                  learning_date TEXT NOT NULL,
                  created_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS sentence_plans (
                  sentence_id INTEGER PRIMARY KEY REFERENCES sentences(id) ON DELETE CASCADE,
                  plan_json TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS reviews (
                  sentence_id INTEGER NOT NULL REFERENCES sentences(id) ON DELETE CASCADE,
                  review_date TEXT NOT NULL,
                  PRIMARY KEY(sentence_id, review_date)
                );
                CREATE TABLE IF NOT EXISTS audio_records (
                  sentence_id INTEGER NOT NULL REFERENCES sentences(id) ON DELETE CASCADE,
                  text TEXT NOT NULL,
                  voice_id TEXT NOT NULL,
                  model_id TEXT NOT NULL,
                  filename TEXT NOT NULL,
                  version INTEGER NOT NULL,
                  created_at TEXT NOT NULL,
                  PRIMARY KEY(sentence_id, voice_id, model_id, version)
                );
                CREATE TABLE IF NOT EXISTS review_cycles (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  sentence_id INTEGER NOT NULL REFERENCES sentences(id) ON DELETE CASCADE,
                  started_on TEXT NOT NULL,
                  created_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS cycle_reviews (
                  cycle_id INTEGER NOT NULL REFERENCES review_cycles(id) ON DELETE CASCADE,
                  review_date TEXT NOT NULL,
                  PRIMARY KEY(cycle_id, review_date)
                );
                CREATE INDEX IF NOT EXISTS cycles_sentence ON review_cycles(sentence_id);
                CREATE INDEX IF NOT EXISTS audio_filename ON audio_records(filename);
                CREATE INDEX IF NOT EXISTS reviews_date ON reviews(review_date);
                CREATE INDEX IF NOT EXISTS sentences_date ON sentences(learning_date);
                """)
            // Also accepts the existing Revia SQLite structure if manually restored.
            try transaction {
                let versionQuery = try statement("PRAGMA user_version")
                let schemaVersion = sqlite3_step(versionQuery) == SQLITE_ROW ? sqlite3_column_int(versionQuery, 0) : 0
                sqlite3_finalize(versionQuery)
                // Backfill only legacy databases. Imported schedules must survive reopening unchanged.
                if schemaVersion < 3 {
                    for sentence in try sentences() {
                        for date in try Schedule.reviews(for: sentence.learningDate) {
                            try run("INSERT OR IGNORE INTO reviews VALUES (?, ?)", [.integer(sentence.id), .text(date)])
                        }
                    }
                }
                try migrateCycles()
                try execute("""
                    CREATE TABLE IF NOT EXISTS cycle_plans (
                      cycle_id INTEGER PRIMARY KEY REFERENCES review_cycles(id) ON DELETE CASCADE,
                      plan_json TEXT NOT NULL
                    );
                    PRAGMA user_version = 6;
                    """)
            }
        } catch {
            sqlite3_close(connection); connection = nil
            throw error
        }
    }
    deinit { sqlite3_close(connection) }
    private var failure: ReviaError { .message(String(cString: sqlite3_errmsg(connection))) }
    private func execute(_ sql: String) throws {
        guard sqlite3_exec(connection, sql, nil, nil, nil) == SQLITE_OK else { throw failure }
    }
    private enum Value { case text(String), integer(Int64) }
    private func statement(_ sql: String, _ values: [Value] = []) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw failure }
        for (index, value) in values.enumerated() {
            let result: Int32
            switch value {
            case .text(let text): result = sqlite3_bind_text(statement, Int32(index + 1), text, -1, transient)
            case .integer(let number): result = sqlite3_bind_int64(statement, Int32(index + 1), number)
            }
            guard result == SQLITE_OK else { sqlite3_finalize(statement); throw failure }
        }
        return statement
    }
    private func run(_ sql: String, _ values: [Value]) throws {
        let statement = try statement(sql, values)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_DONE else { throw failure }
    }
    private func transaction(_ body: () throws -> Void) throws {
        try execute("BEGIN IMMEDIATE")
        do { try body(); try execute("COMMIT") }
        catch { try? execute("ROLLBACK"); throw error }
    }
    private func migrateCycles() throws {
        let query = try statement("SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'review_cycles'")
        let sql = sqlite3_step(query) == SQLITE_ROW ? String(cString: sqlite3_column_text(query, 0)) : ""
        sqlite3_finalize(query)
        guard sql.uppercased().filter({ !$0.isWhitespace }).contains("UNIQUE(SENTENCE_ID,STARTED_ON)") else { return }
        // Preserve IDs and dates while allowing a different plan to start again on the same day.
        try execute("""
            CREATE TABLE review_cycles_v6 (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              sentence_id INTEGER NOT NULL REFERENCES sentences(id) ON DELETE CASCADE,
              started_on TEXT NOT NULL, created_at TEXT NOT NULL
            );
            INSERT INTO review_cycles_v6 SELECT id, sentence_id, started_on, created_at FROM review_cycles;
            CREATE TABLE cycle_reviews_v6 (
              cycle_id INTEGER NOT NULL REFERENCES review_cycles_v6(id) ON DELETE CASCADE,
              review_date TEXT NOT NULL, PRIMARY KEY(cycle_id, review_date)
            );
            INSERT INTO cycle_reviews_v6 SELECT cycle_id, review_date FROM cycle_reviews;
            DROP TABLE cycle_reviews;
            DROP TABLE review_cycles;
            ALTER TABLE review_cycles_v6 RENAME TO review_cycles;
            ALTER TABLE cycle_reviews_v6 RENAME TO cycle_reviews;
            CREATE INDEX cycles_sentence ON review_cycles(sentence_id);
            """)
    }
    private static func timestamp(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions.insert(.withFractionalSeconds)
        return formatter.date(from: value)
    }
    func sentences() throws -> [Sentence] {
        let statement = try statement("SELECT s.id, s.japanese, s.translation, s.learning_date, s.created_at, p.plan_json FROM sentences s LEFT JOIN sentence_plans p ON p.sentence_id = s.id ORDER BY s.learning_date DESC, s.id DESC")
        defer { sqlite3_finalize(statement) }
        var results: [Sentence] = []
        var result = sqlite3_step(statement)
        while result == SQLITE_ROW {
            func text(_ index: Int32) -> String { String(cString: sqlite3_column_text(statement, index)) }
            let plan = sqlite3_column_type(statement, 5) == SQLITE_NULL ? nil : try JSONDecoder().decode(StudyPlan.self, from: Data(text(5).utf8))
            results.append(Sentence(id: sqlite3_column_int64(statement, 0), text: text(1), translation: text(2), learningDate: text(3), createdAt: Self.timestamp(text(4)), studyPlan: plan))
            result = sqlite3_step(statement)
        }
        guard result == SQLITE_DONE else { throw failure }
        return results
    }
    func reviews() throws -> [Review] {
        let statement = try statement("""
            SELECT r.sentence_id, r.review_date FROM reviews r
            WHERE NOT EXISTS (SELECT 1 FROM review_cycles c WHERE c.sentence_id = r.sentence_id AND c.started_on < r.review_date)
            UNION
            SELECT c.sentence_id, r.review_date FROM cycle_reviews r JOIN review_cycles c ON c.id = r.cycle_id
            WHERE NOT EXISTS (SELECT 1 FROM review_cycles newer WHERE newer.sentence_id = c.sentence_id AND newer.id > c.id AND newer.started_on < r.review_date)
            UNION
            SELECT c.sentence_id, c.started_on AS review_date FROM review_cycles c
            JOIN sentences s ON s.id = c.sentence_id WHERE c.started_on <> s.learning_date
            ORDER BY review_date
            """)
        defer { sqlite3_finalize(statement) }
        var results: [Review] = []
        var result = sqlite3_step(statement)
        while result == SQLITE_ROW {
            results.append(Review(sentenceID: sqlite3_column_int64(statement, 0), date: String(cString: sqlite3_column_text(statement, 1))))
            result = sqlite3_step(statement)
        }
        guard result == SQLITE_DONE else { throw failure }
        return results
    }
    @discardableResult
    func add(text: String, translation: String, date: String, plan: StudyPlan = .defaultPlan) throws -> Int64 {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw ReviaError.message(L("enter_sentence")) }
        let dates = try plan.dates(from: date)
        var insertedID: Int64 = 0
        try transaction {
            try run("INSERT INTO sentences (japanese, translation, learning_date, created_at) VALUES (?, ?, ?, ?)", [.text(text), .text(translation.trimmingCharacters(in: .whitespacesAndNewlines)), .text(date), .text(ISO8601DateFormatter().string(from: Date()))])
            let id = sqlite3_last_insert_rowid(connection)
            insertedID = id
            try savePlan(plan, sentenceID: id)
            for day in dates { try run("INSERT INTO reviews VALUES (?, ?)", [.integer(id), .text(day)]) }
        }
    return insertedID
    }
    func exportBackup() throws -> ReviaBackup {
        let query = try statement("SELECT sentence_id, review_date FROM reviews ORDER BY review_date")
        defer { sqlite3_finalize(query) }
        var originals: [Review] = []
        var result = sqlite3_step(query)
        while result == SQLITE_ROW {
            originals.append(Review(sentenceID: sqlite3_column_int64(query, 0), date: String(cString: sqlite3_column_text(query, 1))))
            result = sqlite3_step(query)
        }
        guard result == SQLITE_DONE else { throw failure }
        let grouped = Dictionary(grouping: originals, by: \.sentenceID)
        return ReviaBackup(sentences: try sentences().map { sentence in
            guard let created = sentence.createdAt else { throw ReviaError.message(L("backup_invalid")) }
            let cycles = try resetCycles(sentenceID: sentence.id)
            return BackupSentence(text: sentence.text, translation: sentence.translation,
                                  learningDate: sentence.learningDate, createdAt: created,
                                  reviewDates: (grouped[sentence.id] ?? []).map(\.date).sorted(),
                                  resetCycles: cycles.isEmpty ? nil : cycles, studyPlan: sentence.studyPlan)
        })
    }
    @discardableResult
    func importBackup(_ backup: ReviaBackup) throws -> Int {
        try backup.validate()
        try transaction {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions.insert(.withFractionalSeconds)
            for sentence in backup.sentences {
                try run("INSERT INTO sentences (japanese, translation, learning_date, created_at) VALUES (?, ?, ?, ?)",
                        [.text(sentence.text), .text(sentence.translation), .text(sentence.learningDate), .text(formatter.string(from: sentence.createdAt))])
                let id = sqlite3_last_insert_rowid(connection)
                if let plan = sentence.studyPlan { try savePlan(plan, sentenceID: id) }
                for day in sentence.reviewDates {
                    try run("INSERT INTO reviews VALUES (?, ?)", [.integer(id), .text(day)])
                }
                for cycle in sentence.resetCycles ?? [] { try insertCycle(sentenceID: id, cycle: cycle) }
            }
        }
        return backup.sentences.count
    }
    func resetReviews(sentenceID: Int64, on day: String, plan: StudyPlan? = nil) throws {
        guard let sentence = try sentences().first(where: { $0.id == sentenceID }) else { throw ReviaError.message(L("sentence_read_failed")) }
        try transaction {
            let existing = try resetCycles(sentenceID: sentenceID)
            let current = existing.last?.studyPlan ?? sentence.studyPlan ?? .defaultPlan
            let selected = plan ?? current
            let dates = try selected.dates(from: day)
            if existing.last?.startedOn == day && selected == current { return }
            if let previous = existing.last, day < previous.startedOn { throw ReviaError.message(L("reset_date_error")) }
            // Legacy calls preserve their previous backup format; explicit selections save a cycle snapshot.
            let snapshot = plan != nil || existing.last?.studyPlan != nil ? selected : nil
            try insertCycle(sentenceID: sentenceID, cycle: BackupCycle(startedOn: day, createdAt: Date(), reviewDates: dates, studyPlan: snapshot))
        }
    }
    private func savePlan(_ plan: StudyPlan, sentenceID: Int64) throws {
        try plan.validate()
        guard !plan.isDefault else { return }
        let json = String(decoding: try JSONEncoder().encode(plan), as: UTF8.self)
        try run("INSERT INTO sentence_plans VALUES (?, ?)", [.integer(sentenceID), .text(json)])
    }
    private func insertCycle(sentenceID: Int64, cycle: BackupCycle) throws {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions.insert(.withFractionalSeconds)
        try run("INSERT INTO review_cycles (sentence_id, started_on, created_at) VALUES (?, ?, ?)",
                [.integer(sentenceID), .text(cycle.startedOn), .text(formatter.string(from: cycle.createdAt))])
        let id = sqlite3_last_insert_rowid(connection)
        if let plan = cycle.studyPlan {
            let json = String(decoding: try JSONEncoder().encode(plan), as: UTF8.self)
            try run("INSERT INTO cycle_plans VALUES (?, ?)", [.integer(id), .text(json)])
        }
        for day in cycle.reviewDates {
            try run("INSERT INTO cycle_reviews VALUES (?, ?)", [.integer(id), .text(day)])
        }
    }
    func resetCycles(sentenceID: Int64) throws -> [BackupCycle] {
        let query = try statement("SELECT c.id, c.started_on, c.created_at, p.plan_json FROM review_cycles c LEFT JOIN cycle_plans p ON p.cycle_id = c.id WHERE c.sentence_id = ? ORDER BY c.id", [.integer(sentenceID)])
        defer { sqlite3_finalize(query) }
        var cycles: [BackupCycle] = []
        var result = sqlite3_step(query)
        while result == SQLITE_ROW {
            let id = sqlite3_column_int64(query, 0)
            let started = String(cString: sqlite3_column_text(query, 1))
            guard let created = Self.timestamp(String(cString: sqlite3_column_text(query, 2))) else { throw ReviaError.message(L("backup_invalid")) }
            let days = try statement("SELECT review_date FROM cycle_reviews WHERE cycle_id = ? ORDER BY review_date", [.integer(id)])
            var dates: [String] = []
            var step = sqlite3_step(days)
            while step == SQLITE_ROW {
                dates.append(String(cString: sqlite3_column_text(days, 0)))
                step = sqlite3_step(days)
            }
            sqlite3_finalize(days)
            guard step == SQLITE_DONE else { throw failure }
            let plan = sqlite3_column_type(query, 3) == SQLITE_NULL ? nil : try JSONDecoder().decode(StudyPlan.self, from: Data(String(cString: sqlite3_column_text(query, 3)).utf8))
            cycles.append(BackupCycle(startedOn: started, createdAt: created, reviewDates: dates, studyPlan: plan))
            result = sqlite3_step(query)
        }
        guard result == SQLITE_DONE else { throw failure }
        return cycles
    }
    func delete(id: Int64) throws { try run("DELETE FROM sentences WHERE id = ?", [.integer(id)]) }
    func audioRecords(sentenceID: Int64? = nil) throws -> [AudioRecord] {
        let sql = "SELECT sentence_id, text, voice_id, model_id, filename, version FROM audio_records" + (sentenceID == nil ? "" : " WHERE sentence_id = ?") + " ORDER BY created_at DESC"
        let query = try statement(sql, sentenceID.map { [.integer($0)] } ?? [])
        defer { sqlite3_finalize(query) }
        var rows: [AudioRecord] = []
        var result = sqlite3_step(query)
        while result == SQLITE_ROW {
            func text(_ column: Int32) -> String { String(cString: sqlite3_column_text(query, column)) }
            rows.append(AudioRecord(sentenceID: sqlite3_column_int64(query, 0), text: text(1), voiceID: text(2), modelID: text(3), filename: text(4), version: Int(sqlite3_column_int(query, 5))))
            result = sqlite3_step(query)
        }
        guard result == SQLITE_DONE else { throw failure }
        return rows
    }
    func saveAudio(_ record: AudioRecord) throws {
        try run("INSERT OR REPLACE INTO audio_records (sentence_id, text, voice_id, model_id, filename, version, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)", [.integer(record.sentenceID), .text(record.text), .text(record.voiceID), .text(record.modelID), .text(record.filename), .integer(Int64(record.version)), .text(ISO8601DateFormatter().string(from: Date()))])
    }

}
