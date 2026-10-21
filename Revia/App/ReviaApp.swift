import SwiftUI

@main
struct ReviaApp: App {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingLaunch = true
    @State private var launchFading = false
    @StateObject private var store = Store()
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var reminder = ReminderController()
    @StateObject private var language = AppLanguage()
    var body: some Scene {
        WindowGroup {
            RootView()
                .overlay {
                    if showingLaunch {
                        LaunchView().opacity(launchFading ? 0 : 1)
                            .allowsHitTesting(false)
                    }
                }
                .task {
                    // Fade straight into the ready interface, without a timer or artificial loading delay.
                    withAnimation(.easeOut(duration: reduceMotion ? 0.1 : 0.4), completionCriteria: .logicallyComplete) {
                        launchFading = true
                    } completion: {
                        showingLaunch = false
                    }
                }
                .environmentObject(store).environmentObject(store.speech)
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
