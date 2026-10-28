import SwiftUI

@main
struct ReviaApp: App {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("app.appearance") private var appearance = AppAppearance.system.rawValue
    @State private var showingLaunch = true
    @State private var launchFading = false
    @StateObject private var store = Store()
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var reminder = ReminderController()
    @StateObject private var plans = PlanCatalog()
    @StateObject private var language = AppLanguage()
    @StateObject private var theme = ThemeManager()
    var body: some Scene {
        let _ = theme.selected
        WindowGroup {
            RootView()
                .disabled(showingLaunch)
                .accessibilityHidden(showingLaunch)
                .overlay {
                    if showingLaunch {
                        LaunchView(animated: !reduceMotion).opacity(launchFading ? 0 : 1)
                            .allowsHitTesting(false)
                    }
                }
                .task {
                    guard showingLaunch else { return }
                    if !reduceMotion {
                        do { try await Task.sleep(for: .seconds(BrainCircuit.duration)) }
                        catch { return }
                    }
                    withAnimation(.easeOut(duration: reduceMotion ? 0.1 : LaunchAppearance.fadeDuration), completionCriteria: .logicallyComplete) {
                        launchFading = true
                    } completion: {
                        showingLaunch = false
                    }
                }
                .environmentObject(store).environmentObject(store.speech)
                .environmentObject(language)
                .environmentObject(theme)
                .environmentObject(reminder)
                .environmentObject(plans)
                .task { await reminder.refresh() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await reminder.refresh() } }
                }
                .onChange(of: language.code) { _, _ in Task { await reminder.refresh() } }
                .environment(\.locale, language.locale)
                .environment(\.calendar, Schedule.calendar)
                .tint(Palette.accent)
                .preferredColorScheme((AppAppearance(rawValue: appearance) ?? .system).colorScheme)
        }
    }
}
