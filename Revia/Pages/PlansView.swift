import SwiftUI

struct PlansView: View {
    @EnvironmentObject private var language: AppLanguage
    @EnvironmentObject private var plans: PlanCatalog
    var body: some View {
        let _ = language.code
        Form {
            Section {
                Text(L("default_plan"))
            } footer: { Text(L("review_plan")) }
            .listRowBackground(Palette.surface)
            Section {
                ForEach(plans.custom) { plan in
                    NavigationLink { PlanEditorView(plan: plan) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(plan.name)
                            Text(L("plan_summary", (plan.offsets ?? []).map(String.init).joined(separator: "、")))
                                .font(.footnote).foregroundStyle(Palette.muted)
                        }
                    }
                }.onDelete { plans.delete($0) }
                NavigationLink { PlanEditorView() } label: {
                    Label(L("new_plan"), systemImage: "plus")
                }.disabled(!plans.canAdd)
            } footer: { Text(L("plan_limit")) }
            .listRowBackground(Palette.surface)
        }
        .scrollContentBackground(.hidden).background(Palette.background)
        .navigationTitle(L("study_plans")).navigationBarTitleDisplayMode(.inline)
    }
}

struct PlanEditorView: View {
    @EnvironmentObject private var language: AppLanguage
    @EnvironmentObject private var plans: PlanCatalog
    @Environment(\.dismiss) private var dismiss
    private let id: String
    @State private var name: String
    @State private var blocks: [Int]
    @State private var error: String?
    private var offsets: [Int]? { try? StudyPlan.offsets(for: blocks) }
    private var count: Int { blocks.filter { $0 == 0 }.count }
    init(plan: StudyPlan? = nil) {
        id = plan?.id ?? UUID().uuidString
        _name = State(initialValue: plan?.name ?? "")
        _blocks = State(initialValue: plan?.blocks ?? [])
    }
    var body: some View {
        let _ = language.code
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                TextField(L("plan_name"), text: $name)
                    .padding(14).background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
                    .onChange(of: name) { _, value in if value.count > 40 { name = String(value.prefix(40)) } }
                Text(L("plan_builder_note")).font(.footnote).foregroundStyle(Palette.muted)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
                    ForEach(StudyPlan.dayBlocks, id: \.self) { day in
                        Button { blocks.append(day) } label: {
                            Text(L("days_block", day)).font(.system(size: 15, weight: .medium))
                                .frame(maxWidth: .infinity).frame(height: 48)
                                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 10))
                        }.disabled(count >= 15)
                    }
                }
                Button { blocks.append(0) } label: {
                    Label(L("review_node"), systemImage: "flag.fill")
                        .frame(maxWidth: .infinity).padding(14)
                        .foregroundStyle(Palette.onAccent).background(Palette.green, in: RoundedRectangle(cornerRadius: 12))
                }.disabled(blocks.isEmpty || blocks.last == 0 || count >= 15)
                HStack {
                    Text(L("node_count", count)).font(.subheadline)
                    Spacer()
                    Button(L("undo_block")) { if !blocks.isEmpty { blocks.removeLast() } }.disabled(blocks.isEmpty)
                    Button(L("clear_blocks")) { blocks.removeAll() }.disabled(blocks.isEmpty)
                }
                if !blocks.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 76))], spacing: 8) {
                        ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                            Button { blocks.remove(at: index) } label: {
                                HStack(spacing: 4) {
                                    Text(block == 0 ? L("review_node") : L("days_block", block)).lineLimit(1).minimumScaleFactor(0.7)
                                    Image(systemName: "xmark").font(.system(size: 9))
                                }
                                .font(.system(size: 12)).frame(maxWidth: .infinity).padding(.vertical, 10)
                                .foregroundStyle(block == 0 ? Palette.onAccent : Palette.ink)
                                .background(block == 0 ? Palette.green : Palette.surface, in: RoundedRectangle(cornerRadius: 8))
                            }.accessibilityLabel(L("remove_block", index + 1))
                        }
                    }
                }
                Text(offsets.map { L("plan_summary", $0.map(String.init).joined(separator: "、")) } ?? L("plan_finish_node"))
                    .font(.subheadline).foregroundStyle(Palette.muted)
                PrimaryButton(title: L("save_plan")) { save() }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || offsets == nil)
                    .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || offsets == nil ? 0.45 : 1)
            }.padding(24)
        }
        .foregroundStyle(Palette.ink).background(Palette.background)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(L("study_plan")).navigationBarTitleDisplayMode(.inline)
        .alert(L("action_failed"), isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button(L("ok"), role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
    }
    private func save() {
        do {
            let values = try StudyPlan.offsets(for: blocks)
            try plans.save(StudyPlan(id: id, name: name.trimmingCharacters(in: .whitespacesAndNewlines), offsets: values))
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
