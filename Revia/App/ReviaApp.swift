import SwiftUI

@main
struct ReviaApp: App {
    @StateObject private var store = Store()
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var reminder = ReminderController()
    @StateObject private var language = AppLanguage()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store).environmentObject(store.speech)
                .environmentObject(language)
                .environmentObject(reminder)
                .task { await reminder.refresh() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await reminder.refresh() } }
                }
                .onChange(of: language.code) { _, _ in Task { await reminder.refresh() } }
                .environment(\.locale, language.locale)
                .environment(\.calendar, Schedule.calendar)
                .tint(Palette.green)
                .preferredColorScheme(.light)
        }
    }
}
