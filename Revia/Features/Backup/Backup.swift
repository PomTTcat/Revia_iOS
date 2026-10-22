import Foundation

struct ReviaBackup: Codable {
    let format: String
    let version: Int
    let exportedAt: Date
    let sentences: [BackupSentence]
    init(sentences: [BackupSentence]) {
        format = "revia"
        if sentences.contains(where: { ($0.resetCycles ?? []).contains { $0.studyPlan != nil } }) { version = 4 }
        else if sentences.contains(where: { $0.studyPlan != nil }) { version = 3 }
        else if sentences.contains(where: { !($0.resetCycles ?? []).isEmpty }) { version = 2 }
        else { version = 1 }
        exportedAt = Date()
        self.sentences = sentences
    }
    func validate() throws {
        guard format == "revia", (1...4).contains(version) else { throw ReviaError.message(L("backup_format")) }
        for sentence in sentences {
            if let plan = sentence.studyPlan {
                guard version >= 3 else { throw ReviaError.message(L("backup_invalid")) }
                try plan.validate()
            }
            let count = sentence.studyPlan?.offsets?.count ?? 15
            guard !sentence.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  sentence.reviewDates.count == count,
                  Set(sentence.reviewDates).count == count else { throw ReviaError.message(L("backup_invalid")) }
            _ = try Schedule.date(sentence.learningDate)
            for day in sentence.reviewDates {
                _ = try Schedule.date(day)
                guard day > sentence.learningDate else { throw ReviaError.message(L("backup_invalid")) }
            }
            let cycles = sentence.resetCycles ?? []
            guard version >= 2 || cycles.isEmpty else { throw ReviaError.message(L("backup_invalid")) }
            var previous: String?
            for cycle in cycles {
                _ = try Schedule.date(cycle.startedOn)
                if let plan = cycle.studyPlan {
                    guard version >= 4 else { throw ReviaError.message(L("backup_invalid")) }
                    try plan.validate()
                }
                let cycleCount = cycle.studyPlan.map { $0.offsets?.count ?? 15 } ?? count
                guard previous.map({ cycle.startedOn >= $0 }) ?? true,
                      cycle.reviewDates.count == cycleCount, Set(cycle.reviewDates).count == cycleCount else { throw ReviaError.message(L("backup_invalid")) }
                for day in cycle.reviewDates {
                    _ = try Schedule.date(day)
                    guard day > cycle.startedOn else { throw ReviaError.message(L("backup_invalid")) }
                }
                previous = cycle.startedOn
            }
        }
    }
    func encoded() throws -> Data {
        try validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions.insert(.withFractionalSeconds)
            try container.encode(formatter.string(from: date))
        }
        return try encoder.encode(self)
    }
    static func decode(_ data: Data) throws -> ReviaBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions.insert(.withFractionalSeconds)
            if let date = formatter.date(from: value) { return date }
            formatter.formatOptions.remove(.withFractionalSeconds)
            guard let date = formatter.date(from: value) else { throw ReviaError.message(L("backup_invalid")) }
            return date
        }
        do {
            let backup = try decoder.decode(ReviaBackup.self, from: data)
            try backup.validate()
            return backup
        } catch let error as ReviaError { throw error }
        catch { throw ReviaError.message(L("backup_invalid")) }
    }
}
struct BackupSentence: Codable {
    let text: String
    let translation: String
    let learningDate: String
    let createdAt: Date
    let reviewDates: [String]
    var resetCycles: [BackupCycle]? = nil
    var studyPlan: StudyPlan? = nil
}
struct BackupCycle: Codable {
    let startedOn: String
    let createdAt: Date
    let reviewDates: [String]
    var studyPlan: StudyPlan? = nil
}
