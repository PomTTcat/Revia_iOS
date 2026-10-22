import SwiftUI
import UIKit

struct PrimaryButton: View {
    @EnvironmentObject private var language: AppLanguage
    let title: String
    let action: () -> Void
    var body: some View {
        let _ = language.code
        Button(action: action) {
            Text(title).font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity).padding(17)
                .foregroundStyle(Palette.onAccent).background(Palette.green, in: RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(.plain)
    }
}
struct EmptyViewMessage: View {
    @EnvironmentObject private var language: AppLanguage
    let text: String
    var body: some View {
        let _ = language.code
        Text(text).font(.system(size: 14)).foregroundStyle(Palette.muted)
            .frame(maxWidth: .infinity).padding(24)
    }
}
struct SentenceCard: View {
    @EnvironmentObject private var language: AppLanguage
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var plans: PlanCatalog
    @EnvironmentObject private var speech: SpeechController
    let sentence: Sentence
    let fresh: Bool
    @State private var confirming = false
    @State private var choosingPlan = false
    @AppStorage("notes.collapsed") private var collapseNotes = false
    @State private var notesExpanded: Bool?
    var body: some View {
        let _ = language.code
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(L("added_on", (try? Schedule.date(sentence.learningDate)).map { Localization.date($0, template: "yMMMd") } ?? sentence.learningDate)).font(.system(size: 12)).foregroundStyle(Palette.muted)
                Spacer()
                HStack(spacing: 0) {
                    Button { store.toggleFavorite(sentence) } label: {
                        Image(systemName: sentence.isFavorite ? "bookmark.fill" : "bookmark")
                            .resizable().scaledToFit()
                            .frame(width: 20, height: 20)
                            .frame(width: 30, height: 44)
                            .contentShape(Rectangle())
                    }
                    .foregroundStyle(sentence.isFavorite ? Palette.green : Palette.muted)
                    .accessibilityLabel(L(sentence.isFavorite ? "unfavorite" : "favorite"))
                    Button(role: .destructive) { confirming = true } label: {
                        Image(systemName: "xmark")
                            .resizable().scaledToFit()
                            .frame(width: 14, height: 14)
                            .frame(width: 30, height: 44)
                            .contentShape(Rectangle())
                    }
                    .foregroundStyle(Palette.muted)
                    .accessibilityLabel(L("delete"))
        .alert(L("delete_title"), isPresented: $confirming) {
            Button(L("cancel"), role: .cancel) {}
            Button(L("delete_all"), role: .destructive) { store.delete(sentence) }
        } message: { Text(L("delete_note")) }
                }
                .buttonStyle(.plain)
                .fontWeight(.regular)
                .symbolRenderingMode(.monochrome)
                .padding(.trailing, -5)
            }
            Text(sentence.text).font(.system(size: 21, weight: .medium))
                .lineSpacing(6).foregroundStyle(Palette.ink)
            HStack {
                Button { speech.play(sentence) } label: {
                    Group {
                        if speech.busyIDs.contains(sentence.id) { ProgressView().controlSize(.small) }
                        else { Image(systemName: speech.playingID == sentence.id ? "stop.fill" : "play.fill") }
                    }
                    .font(.system(size: 18, weight: .medium)).frame(width: 44, height: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain).foregroundStyle(Palette.green).disabled(speech.busyIDs.contains(sentence.id))
                .accessibilityLabel(L(speech.busyIDs.contains(sentence.id) ? "generating_audio" : (speech.playingID == sentence.id ? "stop_audio" : "play_audio")))
                Spacer()
                Button { choosingPlan = true } label: {
                    Text(L("reset_reviews"))
                        .font(.system(size: 14, weight: .medium)).frame(minHeight: 44)
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).foregroundStyle(Palette.green)
                    .accessibilityLabel(L("reset_reviews"))
        .alert(L("reset_reviews"), isPresented: $choosingPlan) {
            ForEach(plans.all) { plan in
                Button(plan.title) { store.resetReviews(sentence, plan: plan) }
            }
            Button(L("cancel"), role: .cancel) {}
        } message: { Text(L("reset_choose_note")) }
            }
            .padding(.vertical, -6.5)
            if !sentence.translation.isEmpty {
                DisclosureGroup(isExpanded: Binding(get: { notesExpanded ?? !collapseNotes }, set: { notesExpanded = $0 })) {
                    Text(sentence.translation).font(.system(size: 15)).lineSpacing(5)
                        .foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6)
                } label: {
                    Text(L("notes")).font(.system(size: 14)).foregroundStyle(Palette.muted)
                }.tint(Palette.green)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 8)
        .background(fresh ? Palette.fresh : Palette.review, in: RoundedRectangle(cornerRadius: 12))
        .contextMenu {
            Button { UIPasteboard.general.string = sentence.text } label: { Label(L("copy"), systemImage: "doc.on.doc") }
            ShareLink(item: sentence.translation.isEmpty ? sentence.text : sentence.text + "\n\n" + sentence.translation) {
                Label(L("share"), systemImage: "square.and.arrow.up")
            }
            Button { store.beginEditing(sentence) } label: { Label(L("edit"), systemImage: "pencil") }
        }
        .onChange(of: collapseNotes) { _, _ in notesExpanded = nil }


    }
}
