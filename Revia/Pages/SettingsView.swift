import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var language: AppLanguage
    @EnvironmentObject private var speech: SpeechController
    var body: some View {
        let _ = theme.selected
        let _ = language.code
        Form {
            Section {
                NavigationLink { PreferencesView() } label: { Text(L("preferences")) }
            }.listRowBackground(Palette.surface)
            Section {
                NavigationLink { SpeechSettingsView() } label: {
                    HStack {
                        Text(L("speech_settings"))
                        Spacer()
                        Text(speech.source.title).font(.subheadline).foregroundStyle(Palette.muted)
                    }
                }
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
