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
                CREATE INDEX IF NOT EXISTS audio_filename ON audio_records(filename);
                CREATE INDEX IF NOT EXISTS reviews_date ON reviews(review_date);
                CREATE INDEX IF NOT EXISTS sentences_date ON sentences(learning_date);
                """)
            // Also accepts the existing Revia SQLite structure if manually restored.
            try transaction {
                for sentence in try sentences() {
                    for date in try Schedule.reviews(for: sentence.learningDate) {
                        try run("INSERT OR IGNORE INTO reviews VALUES (?, ?)", [.integer(sentence.id), .text(date)])
                    }
                }
                try execute("PRAGMA user_version = 3")
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
    func sentences() throws -> [Sentence] {
        let statement = try statement("SELECT id, japanese, translation, learning_date FROM sentences ORDER BY learning_date DESC, id DESC")
        defer { sqlite3_finalize(statement) }
        var results: [Sentence] = []
        var result = sqlite3_step(statement)
        while result == SQLITE_ROW {
            func text(_ index: Int32) -> String { String(cString: sqlite3_column_text(statement, index)) }
            results.append(Sentence(id: sqlite3_column_int64(statement, 0), text: text(1), translation: text(2), learningDate: text(3)))
            result = sqlite3_step(statement)
        }
        guard result == SQLITE_DONE else { throw failure }
        return results
    }
    func reviews() throws -> [Review] {
        let statement = try statement("SELECT sentence_id, review_date FROM reviews ORDER BY review_date")
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
    func add(text: String, translation: String, date: String) throws -> Int64 {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw ReviaError.message(L("enter_sentence")) }
        let dates = try Schedule.reviews(for: date)
        var insertedID: Int64 = 0
        try transaction {
            try run("INSERT INTO sentences (japanese, translation, learning_date, created_at) VALUES (?, ?, ?, ?)", [.text(text), .text(translation.trimmingCharacters(in: .whitespacesAndNewlines)), .text(date), .text(ISO8601DateFormatter().string(from: Date()))])
            let id = sqlite3_last_insert_rowid(connection)
            insertedID = id
            for day in dates { try run("INSERT INTO reviews VALUES (?, ?)", [.integer(id), .text(day)]) }
        }
    return insertedID
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
