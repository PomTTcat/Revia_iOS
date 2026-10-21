import Foundation
import Combine

@MainActor
final class Store: ObservableObject {
    @Published private(set) var sentences: [Sentence] = []
    @Published private(set) var reviews: [Review] = []
    @Published private(set) var ready = false
    @Published var error: String?
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
    func add(text: String, translation: String, date: Date) throws -> Sentence {
        guard let database else { throw ReviaError.message(L("db_not_ready")) }
        let id = try database.add(text: text, translation: translation, date: Schedule.key(date))
        try refresh()
        guard let sentence = sentences.first(where: { $0.id == id }) else { throw ReviaError.message(L("sentence_read_failed")) }
        return sentence
    }
    func delete(_ sentence: Sentence) {
        do {
            guard let database else { throw ReviaError.message(L("db_not_ready")) }
            var deletionError: Error?
            do { try speech.removeSentence(sentence.id) { try database.delete(id: sentence.id) } }
            catch { deletionError = error }
            try refresh()
            if let deletionError { throw deletionError }
        } catch { self.error = error.localizedDescription }
    }
    func newSentences(on day: String) -> [Sentence] { sentences.filter { $0.learningDate == day } }
    func reviewSentences(on day: String) -> [Sentence] {
        let ids = Set(reviews.filter { $0.date == day }.map(\.sentenceID))
        return sentences.filter { ids.contains($0.id) }
    }
}
