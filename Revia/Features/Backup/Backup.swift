import Foundation

struct ReviaBackup: Codable {
    let format: String
    let version: Int
    let exportedAt: Date
    let sentences: [BackupSentence]
    init(sentences: [BackupSentence]) {
        format = "revia"; version = 1; exportedAt = Date(); self.sentences = sentences
    }
    func validate() throws {
        guard format == "revia", version == 1 else { throw ReviaError.message(L("backup_format")) }
        for sentence in sentences {
            guard !sentence.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  sentence.reviewDates.count == 15,
                  Set(sentence.reviewDates).count == 15 else { throw ReviaError.message(L("backup_invalid")) }
            _ = try Schedule.date(sentence.learningDate)
            for day in sentence.reviewDates {
                _ = try Schedule.date(day)
                guard day > sentence.learningDate else { throw ReviaError.message(L("backup_invalid")) }
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
}
