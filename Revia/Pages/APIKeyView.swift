import SwiftUI
import UIKit

struct APIKeyView: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var language: AppLanguage
    @EnvironmentObject private var speech: SpeechController
    var body: some View {
        let _ = theme.selected
        let _ = language.code
        Form {
            Section {
                SecureField("ElevenLabs API Key", text: Binding(get: { speech.draft }, set: { speech.changeKey($0) }))
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .privacySensitive()
                HStack {
                    Label(speech.active ? L("key_active") : L("key_inactive"), systemImage: speech.active ? "checkmark.shield.fill" : "shield")
                        .foregroundStyle(speech.active ? Palette.accent : Palette.muted)
                    Spacer()
                    Button(speech.validating ? L("validating_key") : L("activate_key")) {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        speech.validate()
                    }
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
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("API Key")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(speech.validating)
        .overlay {
            if speech.validating {
                ZStack {
                    Color.black.opacity(0.18).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView().controlSize(.large).tint(Palette.accent)
                        Text(L("validating_key"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Palette.ink)
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
}
