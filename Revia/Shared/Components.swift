import SwiftUI

enum Palette {
    static let ink = Color(red: 0.14, green: 0.23, blue: 0.20)
    static let green = Color(red: 0.20, green: 0.46, blue: 0.36)
    static let muted = Color(red: 0.47, green: 0.52, blue: 0.49)
    static let background = Color(red: 0.98, green: 0.985, blue: 0.97)
    static let fresh = Color(red: 0.886, green: 0.941, blue: 0.871)
    static let review = Color(red: 0.925, green: 0.933, blue: 0.922)
}
struct PrimaryButton: View {
    @EnvironmentObject private var language: AppLanguage
    let title: String
    let action: () -> Void
    var body: some View {
        let _ = language.code
        Button(action: action) {
            Text(title).font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity).padding(17)
                .foregroundStyle(.white).background(Palette.green, in: RoundedRectangle(cornerRadius: 16))
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
    @EnvironmentObject private var speech: SpeechController
    let sentence: Sentence
    let fresh: Bool
    @State private var confirming = false
    var body: some View {
        let _ = language.code
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L("added_on", (try? Schedule.date(sentence.learningDate)).map { Localization.date($0, template: "yMMMd") } ?? sentence.learningDate)).font(.system(size: 12)).foregroundStyle(Palette.muted)
                Spacer()
                Button(L("delete"), role: .destructive) { confirming = true }
                    .font(.system(size: 12)).padding(.vertical, 5)
            }
            Text(sentence.text).font(.system(size: 21, weight: .medium))
                .lineSpacing(6).textSelection(.enabled).foregroundStyle(Palette.ink)
            Button { speech.play(sentence) } label: {
                HStack(spacing: 8) {
                    if speech.busyIDs.contains(sentence.id) { ProgressView().controlSize(.small) }
                    Image(systemName: speech.playingID == sentence.id ? "stop.fill" : "play.fill")
                    Text(speech.busyIDs.contains(sentence.id) ? L("generating_audio") : (speech.playingID == sentence.id ? L("stop_audio") : L("play_audio")))
                }.font(.system(size: 14, weight: .medium)).foregroundStyle(Palette.green).padding(.vertical, 6)
            }.buttonStyle(.plain).disabled(speech.busyIDs.contains(sentence.id))
            if !sentence.translation.isEmpty {
                Text(sentence.translation).font(.system(size: 15)).lineSpacing(5)
                    .foregroundStyle(Palette.muted).textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(20)
        .background(fresh ? Palette.fresh : Palette.review, in: RoundedRectangle(cornerRadius: 20))
        .alert(L("delete_title"), isPresented: $confirming) {
            Button(L("cancel"), role: .cancel) {}
            Button(L("delete_all"), role: .destructive) { store.delete(sentence) }
        } message: { Text(L("delete_note")) }
    }
}
