import SwiftUI

struct RootView: View {
    @EnvironmentObject private var language: AppLanguage
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var speech: SpeechController
    var body: some View {
        let _ = language.code
        Group {
            if store.ready {
                TabView {
                    NavigationStack { CalendarView() }
                        .tabItem { Label(L("calendar"), systemImage: "calendar") }
                    NavigationStack { TodayView() }
                        .tabItem { Label(L("today"), systemImage: "sun.max") }
                    NavigationStack { SentencesView() }
                        .tabItem { Label(L("all_sentences"), systemImage: "text.alignleft") }
                    NavigationStack { SettingsView() }
                        .tabItem { Label(L("settings"), systemImage: "gearshape") }
                }
            } else {
                VStack(spacing: 20) {
                    Text("Revia").font(.largeTitle.bold())
                    Text(L("data_unavailable")).foregroundStyle(Palette.muted)
                    Button(L("retry")) { store.load() }
                }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Palette.background)
            }
        }
        .alert(store.error != nil ? L("action_failed") : L("audio_notice"), isPresented: Binding(get: { store.error != nil || speech.alert != nil }, set: { if !$0 { store.error = nil; speech.alert = nil } })) {
            Button(L("ok"), role: .cancel) { store.error = nil; speech.alert = nil }
        } message: { Text(store.error ?? speech.alert ?? L("try_again")) }
    }
}

