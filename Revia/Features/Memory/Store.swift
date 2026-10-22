import Foundation
import Combine

@MainActor
final class Store: ObservableObject {
    @Published private(set) var sentences: [Sentence] = []
    @Published private(set) var reviews: [Review] = []
    @Published private(set) var ready = false
    @Published var error: String?
    @Published var editing: SentenceEdit?
    @Published var notice: String?
    let speech = SpeechController()
    private var database: Database?
    init() { load() }
    func load() {
        do {
            let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if database == nil { database = try Database(path: directory.appendingPathComponent("revia.db").path) }
            try speech.configure(database: database!, directory: directory)
            try refresh()
            ready = true
            error = nil
        } catch { self.error = error.localizedDescription }
    }
    private func refresh() throws {
        guard let database else { throw ReviaError.message(L("db_not_ready")) }
        let sentences = try database.sentences()
        let reviews = try database.reviews()
        self.sentences = sentences; self.reviews = reviews
    }
    @discardableResult
    func add(text: String, translation: String, date: Date, plan: StudyPlan = .defaultPlan) throws -> Sentence {
        guard let database else { throw ReviaError.message(L("db_not_ready")) }
        let id = try database.add(text: text, translation: translation, date: Schedule.key(date), plan: plan)
        try refresh()
        guard let sentence = sentences.first(where: { $0.id == id }) else { throw ReviaError.message(L("sentence_read_failed")) }
        return sentence
    }
    func beginEditing(_ sentence: Sentence) {
        do {
            guard let database else { throw ReviaError.message(L("db_not_ready")) }
            let plan = try database.resetCycles(sentenceID: sentence.id).last?.studyPlan ?? sentence.studyPlan ?? .defaultPlan
            editing = SentenceEdit(sentence: sentence, plan: plan)
        } catch { self.error = error.localizedDescription }
    }
    func edit(_ original: Sentence, text: String, translation: String, plan: StudyPlan, keepHistory: Bool) throws -> Sentence {
        guard let database else { throw ReviaError.message(L("db_not_ready")) }
        var updated = false
        do {
            try speech.mutateSentence(original.id) {
                try database.editSentence(id: original.id, text: text, translation: translation, on: Schedule.key(Date()), plan: plan, keepHistory: keepHistory)
                updated = true
            }
        } catch {
            if !updated { throw error }
            // The database change succeeded; do not invite a second save if file cleanup failed.
            self.error = error.localizedDescription
        }
        try refresh()
        guard let sentence = sentences.first(where: { $0.id == original.id }) else { throw ReviaError.message(L("sentence_read_failed")) }
        return sentence
    }
    func delete(_ sentence: Sentence) {
        do {
            guard let database else { throw ReviaError.message(L("db_not_ready")) }
            var deletionError: Error?
            do { try speech.mutateSentence(sentence.id) { try database.delete(id: sentence.id) } }
            catch { deletionError = error }
            try refresh()
            if let deletionError { throw deletionError }
        } catch { self.error = error.localizedDescription }
    }
    @discardableResult
    func resetReviews(_ sentence: Sentence, plan: StudyPlan? = nil) -> Bool {
        do {
            guard let database else { throw ReviaError.message(L("db_not_ready")) }
            try database.resetReviews(sentenceID: sentence.id, on: Schedule.key(Date()), plan: plan)
            try refresh()
            notice = (plan ?? sentence.studyPlan)?.offsets.map { L("reset_custom_note", $0.map(String.init).joined(separator: "、")) } ?? L("reset_note")
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
    func exportBackup() throws -> Data {
        guard let database else { throw ReviaError.message(L("db_not_ready")) }
        return try database.exportBackup().encoded()
    }
    func importBackup(_ data: Data) throws -> Int {
        guard let database else { throw ReviaError.message(L("db_not_ready")) }
        let count = try database.importBackup(ReviaBackup.decode(data))
        try refresh()
        return count
    }
    func newSentences(on day: String) -> [Sentence] { sentences.filter { $0.learningDate == day } }
    func reviewSentences(on day: String) -> [Sentence] {
        let ids = Set(reviews.filter { $0.date == day }.map(\.sentenceID))
        return sentences.filter { ids.contains($0.id) }
    }
}
