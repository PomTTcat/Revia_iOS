import SwiftUI

struct SentencesView: View {
    @EnvironmentObject private var language: AppLanguage
    @EnvironmentObject private var store: Store
    @State private var query = ""
    var body: some View {
        let _ = language.code
        let sentences = SentenceLibrary.results(store.sentences, query: query)
        ScrollView {
            LazyVStack(spacing: 14) {
                Text(L("newest_first")).font(.footnote).foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if sentences.isEmpty {
                    EmptyViewMessage(text: L(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "no_sentences" : "no_results"))
                }
                ForEach(sentences) { sentence in
                    SentenceCard(sentence: sentence, fresh: false)
                }
            }.padding(24)
        }
        .background(Palette.background)
        .navigationTitle(L("all_sentences"))
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: L("search_sentences"))
        .scrollDismissesKeyboard(.interactively)
    }
}
