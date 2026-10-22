import SwiftUI

struct RootView: View {
    @EnvironmentObject private var language: AppLanguage
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var speech: SpeechController
    @State private var selectedTab = 0
    var body: some View {
        let _ = language.code
        Group {
            if store.ready {
                TabView(selection: $selectedTab) {
                    NavigationStack { CalendarView() }
                        .tabItem { Label(L("calendar"), systemImage: "calendar") }.tag(0)
                    NavigationStack { TodayView() }
                        .tabItem { Label(L("today"), systemImage: "sun.max") }.tag(1)
                    NavigationStack { SentencesView() }
                        .tabItem { Label(L("all_sentences"), systemImage: "text.alignleft") }.tag(2)
                    NavigationStack { SettingsView() }
                        .tabItem { Label(L("settings"), systemImage: "gearshape") }.tag(3)
                }
            } else {
                VStack(spacing: 20) {
                    Text("Revia").font(.largeTitle.bold())
                    Text(L("data_unavailable")).foregroundStyle(Palette.muted)
                    Button(L("retry")) { store.load() }
                }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Palette.background)
            }
        }
        .background(KeyboardDismiss(keepSearchFocused: selectedTab == 2))
        .sheet(item: $store.editing) { edit in
            AddSentenceView(date: Date(), edit: edit)
        }
        .alert(store.error != nil ? L("action_failed") : (store.notice != nil ? L("reset_done") : L("audio_notice")), isPresented: Binding(get: { store.error != nil || store.notice != nil || speech.alert != nil }, set: { if !$0 { store.error = nil; store.notice = nil; speech.alert = nil } })) {
            Button(L("ok"), role: .cancel) { store.error = nil; store.notice = nil; speech.alert = nil }
        } message: { Text(store.error ?? store.notice ?? speech.alert ?? L("try_again")) }
    }
}

