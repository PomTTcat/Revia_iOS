import SwiftUI

struct SentencesView: View {
    @EnvironmentObject private var language: AppLanguage
    @EnvironmentObject private var store: Store
    @State private var favoritesOnly = false
    @State private var query = ""
    var body: some View {
        let _ = language.code
        let sentences = SentenceLibrary.results(store.sentences, query: query, favoritesOnly: favoritesOnly)
        VStack(spacing: 0) {
            Picker(L("sentence_filter"), selection: $favoritesOnly) {
                Text(L("all_items")).tag(false)
                Text(L("favorites")).tag(true)
            }
            .pickerStyle(.segmented).padding(.horizontal, 24).padding(.top, 12)
            ScrollView {
                LazyVStack(spacing: 14) {
                    Text(L("newest_first")).font(.footnote).foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if sentences.isEmpty {
                        EmptyViewMessage(text: L(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? (favoritesOnly ? "no_favorites" : "no_sentences") : "no_results"))
                    }
                    ForEach(sentences) { sentence in
                        SentenceCard(sentence: sentence, fresh: false)
                    }
                }.padding(24)
            }
        }
        .background(Palette.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: L("search_sentences"))
        .scrollDismissesKeyboard(.never)
    }
}
