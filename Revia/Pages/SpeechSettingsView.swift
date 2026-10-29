import SwiftUI

struct SpeechSettingsView: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var language: AppLanguage
    @EnvironmentObject private var speech: SpeechController
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        let _ = theme.selected
        let _ = language.code
        Form {
            Section {
                Picker(L("speech_source"), selection: Binding(get: { speech.source }, set: { speech.selectSource($0) })) {
                    ForEach(SpeechSource.allCases) { option in Text(option.title).tag(option) }
                }
            } footer: { Text(L("speech_source_note")) }
            .listRowBackground(Palette.surface)
            Section {
                Picker(L("system_language"), selection: Binding(get: { speech.systemLanguage }, set: { speech.selectSystemLanguage($0) })) {
                    ForEach(SystemSpeechLanguage.allCases) { option in Text(option.title).tag(option) }
                }
                ForEach([SystemSpeechLanguage.japanese, .english, .chinese]) { option in
                    let available = speech.systemVoices.filter { $0.matches(option.rawValue) }
                    if available.isEmpty {
                        LabeledContent(option.title, value: L("system_voice_none"))
                    } else {
                        Picker(option.title, selection: Binding(get: {
                            let saved = speech.systemSelections[option.rawValue] ?? ""
                            return available.contains { $0.id == saved } ? saved : ""
                        }, set: { speech.selectSystemVoice($0, language: option.rawValue) })) {
                            Text(L("system_default_voice")).tag("")
                            ForEach(available) { voice in
                                Text(voice.title + " (" + voice.language + ")").tag(voice.id)
                            }
                        }
                    }
                }
            } header: { Text(L("speech_source_system")) } footer: { Text(L("system_voice_note")) }
            .listRowBackground(Palette.surface)
            Section {
                Picker(L("voice_type"), selection: Binding(get: { speech.selectedVoiceID }, set: { speech.selectCustomVoice($0) })) {
                    Text(L("male_voice")).tag(ElevenLabs.defaultVoice.id)
                    Text(L("female_voice")).tag(ElevenLabs.femaleVoice.id)
                    if !ElevenLabs.presetVoices.contains(where: { $0.id == speech.selectedVoiceID }) {
                        Text(L("custom_voice")).tag(speech.selectedVoiceID)
                    }
                }
                if !speech.active { Text(L("eleven_key_note")).font(.footnote).foregroundStyle(Palette.muted) }
            } header: { Text("ElevenLabs") } footer: { Text(L("voice_note")) }
            .listRowBackground(Palette.surface)
        }
        .disabled(speech.validating)
        .scrollContentBackground(.hidden).background(Palette.background)
        .navigationTitle(L("speech_settings")).navigationBarTitleDisplayMode(.inline)
        .onAppear { speech.refreshSystemVoices() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { speech.refreshSystemVoices() } }
    }
}
