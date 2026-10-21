import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var language: AppLanguage
    @EnvironmentObject private var speech: SpeechController
    @AppStorage("notes.collapsed") private var collapseNotes = false
    var body: some View {
        let _ = language.code
        Form {
            Section {
                Picker(L("language"), selection: Binding(get: { language.selection }, set: { language.select($0) })) {
                    ForEach(AppLocale.allCases) { option in Text(verbatim: option.name).tag(option) }
                }
                Toggle(L("collapse_notes"), isOn: $collapseNotes)
            }
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
            Section {
                NavigationLink { BackupView() } label: {
                    Label(L("backup_menu"), systemImage: "arrow.up.arrow.down")
                }
                LabeledContent(L("audio_storage"), value: ByteCountFormatStyle(style: .file, allowedUnits: .all, spellsOutZero: false).locale(language.locale).format(speech.storageBytes))
            }
        }
        .navigationTitle(L("settings"))
        .onAppear { speech.refreshStorage() }
    }
}
