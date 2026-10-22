import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject private var language: AppLanguage
    @EnvironmentObject private var reminder: ReminderController
    @AppStorage("app.appearance") private var appearance = AppAppearance.system.rawValue
    @AppStorage("notes.collapsed") private var collapseNotes = false
    var body: some View {
        let _ = language.code
        Form {
            Section {
                Picker(L("language"), selection: Binding(get: { language.selection }, set: { language.select($0) })) {
                    ForEach(AppLocale.allCases) { option in Text(verbatim: option.name).tag(option) }
                }
                Picker(L("appearance"), selection: $appearance) {
                    ForEach(AppAppearance.allCases) { mode in Text(mode.title).tag(mode.rawValue) }
                }
                Toggle(L("collapse_notes"), isOn: $collapseNotes)
                NavigationLink { PlansView() } label: { Text(L("study_plans")) }
                NavigationLink { ReminderView() } label: {
                    HStack {
                        Text(L("daily_reminder"))
                        Spacer()
                        Text(reminder.enabled ? reminder.time.formatted(.dateTime.hour().minute().locale(language.locale)) : L("reminder_off"))
                            .foregroundStyle(Palette.muted).font(.subheadline)
                    }
                }
            }.listRowBackground(Palette.surface)
        }
        .scrollContentBackground(.hidden).background(Palette.background)
        .navigationTitle(L("preferences")).navigationBarTitleDisplayMode(.inline)
    }
}
