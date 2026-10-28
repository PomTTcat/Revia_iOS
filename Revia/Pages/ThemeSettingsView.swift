import SwiftUI

struct ThemeSettingsView: View {
    @EnvironmentObject private var language: AppLanguage
    @EnvironmentObject private var theme: ThemeManager
    var body: some View {
        let _ = language.code
        let _ = theme.selected
        Form {
            Section {
                ForEach(AppTheme.allCases) { option in
                    Button { theme.select(option) } label: {
                        HStack(spacing: 16) {
                            Image(option.previewName)
                                .resizable().scaledToFit()
                                .frame(width: 52, height: 52)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 8) {
                                Text(option.title).foregroundStyle(Palette.ink)
                                HStack(spacing: 6) {
                                    ForEach([option.colors.accent.light, option.colors.fresh.light, option.colors.accent.dark], id: \.self) { value in
                                        Circle().fill(Palette.color(value)).frame(width: 12, height: 12)
                                    }
                                }.accessibilityHidden(true)
                            }
                            Spacer()
                            if theme.selected == option {
                                if theme.changingIcon { ProgressView().tint(Palette.accent) }
                                else { Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.accent) }
                            }
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(theme.changingIcon)
                    .accessibilityLabel(option.title)
                    .accessibilityAddTraits(theme.selected == option ? .isSelected : [])
                }
            } footer: {
                Text(L("color_note"))
            }.listRowBackground(Palette.surface)
            Section(L("font_preview")) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(L("font_sample"))
                        .font(.system(size: 21, weight: .medium)).foregroundStyle(Palette.ink)
                    HStack {
                        Image(systemName: "play.fill")
                        Spacer()
                        Image(systemName: "bookmark.fill")
                    }.foregroundStyle(Palette.accent)
                }
                .padding(.vertical, 8)
            }.listRowBackground(Palette.fresh)
        }
        .scrollContentBackground(.hidden).background(Palette.background)
        .navigationTitle(L("color_theme")).navigationBarTitleDisplayMode(.inline)
        .alert(L("icon_title"), isPresented: Binding(get: { theme.iconError != nil }, set: { if !$0 { theme.iconError = nil } })) {
            Button(L("ok"), role: .cancel) { theme.iconError = nil }
        } message: { Text(theme.iconError ?? "") }
    }
}
