import SwiftUI

struct APIKeyView: View {
    @EnvironmentObject private var language: AppLanguage
    @EnvironmentObject private var speech: SpeechController
    var body: some View {
        let _ = language.code
        Form {
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
            }.listRowBackground(Palette.surface)
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .background(KeyboardDismiss())
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("API Key")
        .navigationBarTitleDisplayMode(.inline)
    }
}
