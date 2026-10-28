import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var language: AppLanguage
    @Environment(\.scenePhase) private var scenePhase
    @State private var today = Date()
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    var body: some View {
        let _ = theme.selected
        let _ = language.code
        DayView(date: today, allowsAdding: false, listenFirst: true)
            .onAppear { today = Date() }
            .onReceive(timer) { today = $0 }
            .onChange(of: scenePhase) { _, phase in if phase == .active { today = Date() } }
    }
}
