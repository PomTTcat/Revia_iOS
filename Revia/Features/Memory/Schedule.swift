import Foundation

/// Calendar dates are stored independently of a clock time or UTC conversion.
enum Schedule {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        calendar.firstWeekday = 2
        return calendar
    }
    static func key(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }
    static func date(_ key: String) throws -> Date {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, key.count == 10,
              let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12)),
              self.key(date) == key else { throw ReviaError.message(L("invalid_date")) }
        return date
    }
    static func monthDays(_ month: Date, fixedRows: Bool = false) -> [Date?] {
        let start = monthStart(month)
        let count = calendar.range(of: .day, in: .month, for: start)!.count
        let padding = (calendar.component(.weekday, from: start) + 5) % 7
        let cells = fixedRows ? 42 : ((padding + count + 6) / 7) * 7
        return (0..<cells).map { index in
            guard index >= padding, index < padding + count else { return nil }
            return calendar.date(byAdding: .day, value: index - padding, to: start)
        }
    }
    static func isFresh(learningDate: String, on day: Date, now: Date) -> Bool {
        learningDate == key(day) && key(day) == key(now)
    }
    static func reviews(for key: String) throws -> [String] {
        let origin = try date(key)
        let initial = [1, 3, 7, 14, 30].map { calendar.date(byAdding: .day, value: $0, to: origin)! }
        let anchor = initial[4]
        let day = calendar.component(.day, from: anchor)
        let first = monthStart(anchor)
        let monthly = (1...10).map { offset -> Date in
            let month = calendar.date(byAdding: .month, value: offset, to: first)!
            let last = calendar.range(of: .day, in: .month, for: month)!.count
            return calendar.date(byAdding: .day, value: min(day, last) - 1, to: month)!
        }
        return (initial + monthly).map(self.key)
    }
    static func monthStart(_ date: Date) -> Date {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: DateComponents(year: parts.year, month: parts.month, day: 1, hour: 12))!
    }
    static func title(_ date: Date) -> String {
        Localization.date(date)
    }
}

enum ReviaError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

struct Sentence: Identifiable, Equatable {
    let id: Int64
    let text: String
    let translation: String
    let learningDate: String
    let createdAt: Date?
    let studyPlan: StudyPlan?
    let isFavorite: Bool
    init(id: Int64, text: String, translation: String, learningDate: String, createdAt: Date? = nil, studyPlan: StudyPlan? = nil, isFavorite: Bool = false) {
        self.id = id; self.text = text; self.translation = translation
        self.learningDate = learningDate; self.createdAt = createdAt; self.studyPlan = studyPlan; self.isFavorite = isFavorite
    }
}

struct SentenceEdit: Identifiable {
    let sentence: Sentence
    let plan: StudyPlan
    var id: Int64 { sentence.id }
}

struct SentenceDayGroup: Identifiable {
    let date: String
    let sentences: [Sentence]
    var id: String { date }
}

enum SentenceLibrary {
    /// Group already-filtered, newest-first results without reordering rows within a day.
    static func groupedByLearningDate(_ sentences: [Sentence]) -> [SentenceDayGroup] {
        Dictionary(grouping: sentences, by: \.learningDate)
            .map { SentenceDayGroup(date: $0.key, sentences: $0.value) }
            .sorted { $0.date > $1.date }
    }
    static func results(_ sentences: [Sentence], query: String, favoritesOnly: Bool = false) -> [Sentence] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return sentences.filter {
            (!favoritesOnly || $0.isFavorite) && (query.isEmpty || $0.text.localizedStandardContains(query) || $0.translation.localizedStandardContains(query))
        }.sorted {
            let left = $0.createdAt ?? (try? Schedule.date($0.learningDate)) ?? .distantPast
            let right = $1.createdAt ?? (try? Schedule.date($1.learningDate)) ?? .distantPast
            return left == right ? $0.id > $1.id : left > right
        }
    }
}
struct Review: Equatable {
    let sentenceID: Int64
    let date: String
}
