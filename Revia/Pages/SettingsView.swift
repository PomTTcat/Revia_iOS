import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var language: AppLanguage
    @EnvironmentObject private var reminder: ReminderController
    @EnvironmentObject private var speech: SpeechController
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
            Section {
                Picker(L("voice_type"), selection: Binding(get: { speech.selectedVoiceID }, set: { speech.selectCustomVoice($0) })) {
                    Text(L("male_voice")).tag(ElevenLabs.defaultVoice.id)
                    Text(L("female_voice")).tag(ElevenLabs.femaleVoice.id)
                    if !ElevenLabs.presetVoices.contains(where: { $0.id == speech.selectedVoiceID }) {
                        Text(L("custom_voice")).tag(speech.selectedVoiceID)
                    }
                }.disabled(speech.validating)
                NavigationLink { APIKeyView() } label: {
                    HStack {
                        Text("API Key")
                        Spacer()
                        Text(L(speech.active ? "key_active" : "key_inactive")).foregroundStyle(Palette.muted).font(.subheadline)
                    }
                }
            } header: { Text(L("speech")) } footer: { Text(L("voice_note")) }
            .listRowBackground(Palette.surface)
            Section {
                NavigationLink { BackupView() } label: {
                    Label(L("backup_menu"), systemImage: "arrow.up.arrow.down")
                }
                LabeledContent(L("audio_storage"), value: ByteCountFormatStyle(style: .file, allowedUnits: .all, spellsOutZero: false).locale(language.locale).format(speech.storageBytes))
            }.listRowBackground(Palette.surface)
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .navigationTitle(L("settings"))
        .onAppear { speech.refreshStorage() }
    }
}
