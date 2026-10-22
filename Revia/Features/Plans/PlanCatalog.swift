import Foundation
import Combine

@MainActor
final class PlanCatalog: ObservableObject {
    @Published private(set) var custom: [StudyPlan] = []
    @Published private(set) var lastSelectedID: String
    private let defaults: UserDefaults
    var all: [StudyPlan] { [.defaultPlan] + custom }
    var canAdd: Bool { custom.count < 3 }
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        lastSelectedID = defaults.string(forKey: "study.lastPlan") ?? StudyPlan.defaultPlan.id
        if let data = defaults.data(forKey: "study.plans"), let plans = try? JSONDecoder().decode([StudyPlan].self, from: data) {
            custom = Array(plans.filter { !$0.isDefault && (try? $0.validate()) != nil }.prefix(3))
        }
    }
    var preferredPlan: StudyPlan { all.first { $0.id == lastSelectedID } ?? .defaultPlan }
    func remember(_ id: String) {
        lastSelectedID = all.contains { $0.id == id } ? id : StudyPlan.defaultPlan.id
        defaults.set(lastSelectedID, forKey: "study.lastPlan")
    }
    func save(_ plan: StudyPlan) throws {
        try plan.validate()
        guard !plan.isDefault else { throw ReviaError.message(L("plan_invalid")) }
        var next = custom
        if let index = next.firstIndex(where: { $0.id == plan.id }) { next[index] = plan }
        else {
            guard canAdd else { throw ReviaError.message(L("plan_limit")) }
            next.append(plan)
        }
        defaults.set(try JSONEncoder().encode(next), forKey: "study.plans")
        custom = next
    }
    func delete(_ offsets: IndexSet) {
        let next = custom.enumerated().filter { !offsets.contains($0.offset) }.map(\.element)
        if let data = try? JSONEncoder().encode(next) { defaults.set(data, forKey: "study.plans"); custom = next; remember(lastSelectedID) }
    }
}
