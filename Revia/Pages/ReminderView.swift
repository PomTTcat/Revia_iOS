import SwiftUI

struct ReminderView: View {
    @EnvironmentObject private var language: AppLanguage
    @EnvironmentObject private var reminder: ReminderController
    @Environment(\.openURL) private var openURL
    var body: some View {
        let _ = language.code
        Form {
            Section {
                Toggle(L("daily_reminder"), isOn: Binding(get: { reminder.enabled }, set: { value in
                    Task { await reminder.setEnabled(value) }
                }))
                DatePicker(L("reminder_time"), selection: Binding(get: { reminder.time }, set: { value in
                    Task { await reminder.setTime(value) }
                }), displayedComponents: .hourAndMinute)
            } footer: { Text(L("reminder_note")) }
            .disabled(reminder.busy)
            if reminder.denied {
                Section {
                    Button(L("open_settings")) {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                    }
                } footer: { Text(L("reminder_denied")) }
            }
        }
        .navigationTitle(L("daily_reminder"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(L("daily_reminder"), isPresented: Binding(get: { reminder.message != nil }, set: { if !$0 { reminder.message = nil } })) {
            Button(L("ok"), role: .cancel) { reminder.message = nil }
        } message: { Text(reminder.message ?? "") }
    }
}
