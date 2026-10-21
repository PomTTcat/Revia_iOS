import Foundation

struct StudyPlan: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let offsets: [Int]?
    static let defaultPlan = StudyPlan(id: "default", name: "", offsets: nil)
    static let dayBlocks = [1, 2, 3, 4, 5, 6, 7, 15, 30]
    var isDefault: Bool { offsets == nil }
    var title: String { isDefault ? L("default_plan") : name }
    func validate() throws {
        if isDefault {
            guard id == "default" else { throw ReviaError.message(L("plan_invalid")) }
            return
        }
        guard !id.isEmpty, id != "default", !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let offsets, (1...15).contains(offsets.count), offsets.allSatisfy({ $0 > 0 && $0 <= 365000 }),
              zip(offsets, offsets.dropFirst()).allSatisfy({ $0 < $1 }) else { throw ReviaError.message(L("plan_invalid")) }
    }
    func dates(from day: String) throws -> [String] {
        try validate()
        guard let offsets else { return try Schedule.reviews(for: day) }
        let origin = try Schedule.date(day)
        return try offsets.map {
            guard let date = Schedule.calendar.date(byAdding: .day, value: $0, to: origin) else { throw ReviaError.message(L("plan_invalid")) }
            return Schedule.key(date)
        }
    }
    static func offsets(for blocks: [Int]) throws -> [Int] {
        var total = 0, last = 0, result: [Int] = []
        for block in blocks {
            if block == 0 {
                guard total > last, result.count < 15 else { throw ReviaError.message(L("plan_invalid")) }
                result.append(total); last = total
            } else {
                guard dayBlocks.contains(block), total <= 365000 - block else { throw ReviaError.message(L("plan_invalid")) }
                total += block
            }
        }
        guard !result.isEmpty, blocks.last == 0 else { throw ReviaError.message(L("plan_invalid")) }
        return result
    }
    var blocks: [Int] {
        var previous = 0, result: [Int] = []
        for offset in offsets ?? [] {
            var gap = offset - previous
            for value in Self.dayBlocks.reversed() {
                while gap >= value { result.append(value); gap -= value }
            }
            result.append(0); previous = offset
        }
        return result
    }
}
