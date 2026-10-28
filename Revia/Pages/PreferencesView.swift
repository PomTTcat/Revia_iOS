import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var language: AppLanguage
    @EnvironmentObject private var reminder: ReminderController
    @AppStorage("app.appearance") private var appearance = AppAppearance.system.rawValue
    @AppStorage("notes.collapsed") private var collapseNotes = false
    @AppStorage("card.fontSize") private var cardFont = CardTextSize.normal.rawValue
    var body: some View {
        let _ = theme.selected
        let _ = language.code
        Form {
            Section {
                Picker(L("language"), selection: Binding(get: { language.selection }, set: { language.select($0) })) {
                    ForEach(AppLocale.allCases) { option in Text(verbatim: option.name).tag(option) }
                }
                Picker(L("appearance"), selection: $appearance) {
                    ForEach(AppAppearance.allCases) { mode in Text(mode.title).tag(mode.rawValue) }
                }
                NavigationLink { ThemeSettingsView() } label: {
                    HStack {
                        Text(L("color_theme"))
                        Spacer()
                        Circle().fill(Palette.accent).frame(width: 14, height: 14)
                        Text(theme.selected.title).foregroundStyle(Palette.muted)
                    }
                }
                NavigationLink { CardFontSettingsView() } label: {
                    HStack {
                        Text(L("card_font"))
                        Spacer()
                        Text(CardTextSize.value(cardFont).title).foregroundStyle(Palette.muted)
                    }
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


enum CardTextSize: Int, CaseIterable {
    case small, normal, large, largest
    static func value(_ raw: Int) -> CardTextSize { CardTextSize(rawValue: raw) ?? .normal }
    var title: String { L(["font_small", "font_normal", "font_large", "font_largest"][rawValue]) }
    var bodySize: CGFloat { [15, 18, 21, 25][rawValue] }
    var compactSize: CGFloat { bodySize - 3 }
    var noteSize: CGFloat { [12, 13, 15, 18][rawValue] }
}

private struct CardFontSettingsView: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var language: AppLanguage
    @AppStorage("card.fontSize") private var selection = CardTextSize.normal.rawValue
    private var size: CardTextSize { CardTextSize.value(selection) }
    var body: some View {
        let _ = theme.selected
        let _ = language.code
        Form {
            Section {
                VStack(spacing: 16) {
                    Text(size.title).font(.headline).foregroundStyle(Palette.ink)
                    Slider(value: Binding(get: { Double(size.rawValue) }, set: { selection = Int($0.rounded()) }), in: 0...3, step: 1)
                        .tint(Palette.accent)
                        .accessibilityLabel(L("card_font"))
                        .accessibilityValue(size.title)
                    HStack {
                        ForEach(CardTextSize.allCases, id: \.rawValue) { option in
                            if option != .small { Spacer(minLength: 0) }
                            Text(option.title)
                                .font(.caption)
                                .foregroundStyle(option == size ? Palette.accent : Palette.muted)
                        }
                    }
                }.padding(.vertical, 12)
            } footer: { Text(L("card_font_note")) }
            .listRowBackground(Palette.surface)
            Section(L("font_preview")) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L("font_sample"))
                        .font(.system(size: size.bodySize, weight: .medium))
                        .foregroundStyle(Palette.ink)
                    Text(L("notes"))
                        .font(.system(size: 14)).foregroundStyle(Palette.muted)
                    Text(L("font_sample_note"))
                        .font(.system(size: size.noteSize)).foregroundStyle(Palette.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            }.listRowBackground(Palette.review)
        }
        .scrollContentBackground(.hidden).background(Palette.background)
        .navigationTitle(L("card_font")).navigationBarTitleDisplayMode(.inline)
    }
}
