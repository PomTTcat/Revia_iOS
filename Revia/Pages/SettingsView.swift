import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var language: AppLanguage
    @EnvironmentObject private var speech: SpeechController
    @State private var customVoice = ""
    var body: some View {
        let _ = language.code
        Form {
            Section {
                Picker(L("language"), selection: Binding(get: { language.selection }, set: { language.select($0) })) {
                    ForEach(AppLocale.allCases) { option in Text(verbatim: option.name).tag(option) }
                }
            } header: { Text(L("app_language")) } footer: {
                Text(L("language_note"))
            }
            Section {
                SecureField("ElevenLabs API Key", text: Binding(get: { speech.draft }, set: { speech.changeKey($0) }))
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .privacySensitive()
                HStack {
                    Label(speech.active ? L("key_active") : L("key_inactive"), systemImage: speech.active ? "checkmark.shield.fill" : "shield")
                        .foregroundStyle(speech.active ? Palette.green : Palette.muted)
                    Spacer()
                    if speech.validating { ProgressView() }
                    Button(speech.validating ? L("validating_key") : L("activate_key")) { speech.validate() }
                        .disabled(speech.validating || speech.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if speech.active || !speech.draft.isEmpty {
                    Button(L("remove_key"), role: .destructive) { speech.deactivate() }
                }
            } header: { Text("ElevenLabs") } footer: {
                Text(L("key_note"))
            }
            Section {
                Picker(L("voice_type"), selection: Binding(get: { speech.selectedVoiceID }, set: { speech.selectCustomVoice($0) })) {
                    Text(L("male_voice")).tag(ElevenLabs.defaultVoice.id)
                    Text(L("female_voice")).tag(ElevenLabs.femaleVoice.id)
                    if !ElevenLabs.presetVoices.contains(where: { $0.id == speech.selectedVoiceID }) {
                        Text(L("custom_voice")).tag(speech.selectedVoiceID)
                    }
                }.pickerStyle(.segmented).disabled(speech.validating)
                Text(L("voice_note")).font(.footnote).foregroundStyle(Palette.muted)
                if speech.voices.isEmpty {
                    Text(L("voices_hint")).foregroundStyle(Palette.muted)
                } else {
                    Picker(L("voice"), selection: Binding(get: { speech.selectedVoiceID }, set: { speech.selectVoice($0) })) {
                        ForEach(speech.voices) { voice in Text(voice.name).tag(voice.id) }
                    }.disabled(!speech.active || speech.validating)
                }
                TextField(L("voice_id"), text: $customVoice)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Button(L("use_voice")) { speech.selectCustomVoice(customVoice) }
                    .disabled(customVoice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || speech.validating)
                LabeledContent(L("model"), value: "Eleven v3")
            } header: { Text(L("speech")) } footer: {
                Text(L("audio_note"))
            }
            Section {
                LabeledContent(L("audio_storage"), value: ByteCountFormatStyle(style: .file, allowedUnits: .all, spellsOutZero: false).locale(language.locale).format(speech.storageBytes))
                Button(L("refresh_storage")) { speech.refreshStorage() }
            } header: { Text(L("local_storage")) } footer: {
                Text(L("storage_note"))
            }
        }
        .navigationTitle(L("settings"))
        .onAppear { speech.refreshStorage() }
    }
}
