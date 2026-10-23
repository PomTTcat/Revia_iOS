import SwiftUI
import UIKit

struct SentencesView: View {
    @EnvironmentObject private var language: AppLanguage
    @EnvironmentObject private var store: Store
    @State private var favoritesOnly = false
    @State private var query = ""
    @State private var searchEditing = false
    @AppStorage("sentences.compact") private var compact = false
    var body: some View {
        let _ = language.code
        let sentences = SentenceLibrary.results(store.sentences, query: query, favoritesOnly: favoritesOnly)
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                SentenceSearchField(text: $query, isEditing: $searchEditing, placeholder: L("search_sentences"))
                    .frame(height: 36)
                if searchEditing {
                Button {
                    query = ""
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                } label: {
                    Image(systemName: "xmark").frame(width: 44, height: 44)
                }
                .buttonStyle(.plain).foregroundStyle(Palette.muted)
                .accessibilityLabel(L("close_search"))
                }
            }
            .frame(height: 44)
            .padding(.horizontal, 24).padding(.top, 8)
            GeometryReader { geometry in
                ZStack(alignment: .trailing) {
                    Picker(L("sentence_filter"), selection: $favoritesOnly) {
                        Text(L("all_items")).tag(false)
                        Text(L("favorites")).tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: geometry.size.width * 2 / 3)
                    .frame(maxWidth: .infinity)
                    Button { compact.toggle() } label: {
                        Image(systemName: compact ? "rectangle.grid.1x2" : "list.bullet")
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 44, height: 44)
                            .background(Palette.review, in: Circle())
                    }
                    .buttonStyle(.plain).foregroundStyle(Palette.green)
                    .accessibilityLabel(L(compact ? "expand_cards" : "compact_cards"))
                }
            }
            .frame(height: 44).padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 10)
            ScrollView {
                LazyVStack(spacing: 14) {
                    if !compact {
                        Text(L("newest_first")).font(.footnote).foregroundStyle(Palette.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if sentences.isEmpty {
                        EmptyViewMessage(text: L(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? (favoritesOnly ? "no_favorites" : "no_sentences") : "no_results"))
                    }
                    ForEach(sentences) { sentence in
                        SentenceCard(sentence: sentence, fresh: false, compact: compact)
                    }
                }.padding(24)
            }
            // Start each display/filter mode at offset zero, including after lazy layout changes.
            .id("sentence-list-\(compact)-\(favoritesOnly)")
        }
        .background(Palette.background)
        .toolbar(.hidden, for: .navigationBar)
        .scrollDismissesKeyboard(.never)
    }
}


/// Native search input keeps the all-sentences keyboard-dismiss exception intact.
private struct SentenceSearchField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isEditing: Bool
    let placeholder: String
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UISearchTextField {
        let field = UISearchTextField()
        field.delegate = context.coordinator
        field.returnKeyType = .search
        field.clearButtonMode = .whileEditing
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        return field
    }
    func updateUIView(_ field: UISearchTextField, context: Context) {
        context.coordinator.parent = self
        if field.text != text { field.text = text }
        field.placeholder = placeholder
        field.accessibilityLabel = placeholder
    }
    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: SentenceSearchField
        init(_ parent: SentenceSearchField) { self.parent = parent }
        @objc func changed(_ field: UISearchTextField) { parent.text = field.text ?? "" }
        func textFieldDidBeginEditing(_ textField: UITextField) { parent.isEditing = true }
        func textFieldDidEndEditing(_ textField: UITextField) { parent.isEditing = false }
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }
}
