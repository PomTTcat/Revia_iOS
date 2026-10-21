import SwiftUI

@main
struct ReviaApp: App {
    @StateObject private var store = Store()
    @StateObject private var language = AppLanguage()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store).environmentObject(store.speech)
                .environmentObject(language)
                .environment(\.locale, language.locale)
                .environment(\.calendar, Schedule.calendar)
                .tint(Palette.green)
                .preferredColorScheme(.light)
        }
    }
}
