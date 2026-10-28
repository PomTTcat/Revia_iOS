import SwiftUI
import UIKit

struct AddSentenceView: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var language: AppLanguage
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var plans: PlanCatalog
    @EnvironmentObject private var speech: SpeechController
    @Environment(\.dismiss) private var dismiss
    let date: Date
    let edit: SentenceEdit?
    init(date: Date, edit: SentenceEdit? = nil) {
        self.date = date; self.edit = edit
        _text = State(initialValue: edit?.sentence.text ?? "")
        _translation = State(initialValue: edit?.sentence.translation ?? "")
    }
    @State private var initialized = false
    @State private var keepHistory = true
    private var offersCurrentPlan: Bool { edit.map { !plans.all.contains($0.plan) } ?? false }
    private var learningDate: Date {
        if let edit, keepHistory { return (try? Schedule.date(edit.sentence.learningDate)) ?? date }
        return date
    }
    @State private var selectedPlanID = StudyPlan.defaultPlan.id
    private var selectedPlan: StudyPlan {
        if selectedPlanID == "editing-current", let edit { return edit.plan }
        return plans.all.first { $0.id == selectedPlanID } ?? .defaultPlan
    }
    @State private var text = ""
    @State private var translation = ""
    @State private var error: String?
    @State private var generateSpeech = false
    @State private var saving = false
    @State private var saved = false
    var body: some View {
        let _ = theme.selected
        let _ = language.code
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(L(edit == nil ? "sentence_title" : "edit_sentence")).font(.system(size: 30, weight: .bold)).foregroundStyle(Palette.ink)
                    Text(L(edit == nil ? "sentence_subtitle" : "edit_note")).font(.system(size: 14)).foregroundStyle(Palette.muted)
                    field(title: L("sentence"), text: $text, placeholder: L("sentence_hint"), height: 120)
                    field(title: L("meaning"), text: $translation, placeholder: L("meaning_hint"), height: 90)
                    LabeledContent(L("learning_date"), value: Localization.date(learningDate, template: "yMMMd"))
                    Picker(L("study_plan"), selection: $selectedPlanID) {
                        ForEach(plans.all) { plan in Text(plan.title).tag(plan.id) }
                        if offersCurrentPlan, let edit { Text(L("current_plan", edit.plan.title)).tag("editing-current") }
                    }.disabled(saving)
                    Text(selectedPlan.offsets.map { L("plan_summary", $0.map(String.init).joined(separator: "、")) } ?? L("review_plan"))
                        .font(.system(size: 13)).foregroundStyle(Palette.muted).lineSpacing(4)
                    Button {
                        if speech.canGenerate { generateSpeech.toggle() }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: generateSpeech && speech.canGenerate ? "checkmark.square.fill" : "square")
                            Text(L("generate_audio"))
                            Spacer()
                        }.foregroundStyle(speech.canGenerate ? Palette.accent : Palette.muted)
                    }.buttonStyle(.plain).disabled(!speech.canGenerate || saving)
                    if edit != nil {
                        Toggle(L("keep_history"), isOn: $keepHistory).disabled(saving)
                        Text(L(keepHistory ? "keep_history_note" : "clear_history_note"))
                            .font(.footnote).foregroundStyle(Palette.muted)
                    }
                    if !speech.canGenerate {
                        Text(L("enable_audio_note")).font(.footnote).foregroundStyle(Palette.muted)
                    }
                    PrimaryButton(title: saving ? L("saving_sentence") : L(edit == nil ? "save_sentence" : "save_changes")) { save() }
                        .disabled(saving || saved || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(saving || saved || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
                }.padding(24)
            }.background(Palette.background)
                .scrollDismissesKeyboard(.interactively)
                .navigationTitle(L(edit == nil ? "add_sentence" : "edit_sentence")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("cancel")) { dismiss() }.disabled(saving) } }
                .interactiveDismissDisabled(saving)
                .onAppear {
                    guard !initialized else { return }
                    initialized = true
                    generateSpeech = speech.canGenerate
                    selectedPlanID = edit.map { offersCurrentPlan ? "editing-current" : $0.plan.id } ?? plans.preferredPlan.id
                }
                .onChange(of: selectedPlanID) { _, id in if edit == nil { plans.remember(id) } }
                .onChange(of: speech.canGenerate) { _, enabled in generateSpeech = enabled }
                .alert(saved ? L("audio_failed_saved") : L("save_failed"), isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                    Button(L("ok"), role: .cancel) { error = nil; if saved { dismiss() } }
                } message: { Text(error ?? L("try_again")) }
        }
        .disabled(saving)
        .overlay {
            if saving {
                ZStack {
                    Color.black.opacity(0.18)
                        .ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .controlSize(.large)
                            .tint(Palette.accent)
                        Text(L(saved ? "generating_audio" : "saving_sentence"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Palette.ink)
                            .multilineTextAlignment(.center)
                    }
                    .padding(28)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20))
                    .padding(24)
                    .accessibilityElement(children: .combine)
                }
                .contentShape(Rectangle())
            }
        }
    }
    private func save() {
        guard !saving, !saved else { return }
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        saving = true
        do {
            let sentence: Sentence
            if let edit {
                sentence = try store.edit(edit.sentence, text: text, translation: translation, plan: selectedPlan, keepHistory: keepHistory)
            } else {
                sentence = try store.add(text: text, translation: translation, date: date, plan: selectedPlan)
            }
            saved = true
            if generateSpeech && speech.canGenerate {
                speech.prepare(sentence) { result in
                    saving = false
                    switch result {
                    case .success: dismiss()
                    case .failure(let failure): error = failure.localizedDescription
                    }
                }
            } else { saving = false; dismiss() }
        } catch { saving = false; self.error = error.localizedDescription }
    }
    private func field(title: String, text: Binding<String>, placeholder: String, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 18, weight: .semibold)).foregroundStyle(Palette.ink)
            ZStack(alignment: .topLeading) {
                if text.wrappedValue.isEmpty { Text(placeholder).foregroundStyle(Palette.muted).padding(.horizontal, 13).padding(.vertical, 15).allowsHitTesting(false) }
                TextEditor(text: text).scrollContentBackground(.hidden).frame(minHeight: height).padding(8)
                    .accessibilityLabel(title)
            }.font(.system(size: 17)).foregroundStyle(Palette.ink).background(Palette.surface, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.border))
        }
    }
}
