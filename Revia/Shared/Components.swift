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
    var compact = false
    var onHide: (() -> Void)? = nil
    var forceNotesCollapsed = false
    @AppStorage("card.fontSize") private var cardFont = CardTextSize.normal.rawValue
    private var textSize: CardTextSize { CardTextSize.value(cardFont) }
    @State private var confirming = false
    @State private var choosingPlan = false
    @AppStorage("notes.collapsed") private var collapseNotes = false
    @State private var notesExpanded: Bool?
    var body: some View {
        let _ = language.code
        Group {
            if compact {
                HStack(spacing: 12) {
                    Text(sentence.text)
                        .font(.system(size: textSize.compactSize, weight: .medium))
                        .lineLimit(1).truncationMode(.tail)
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button { speech.play(sentence) } label: {
                        Group {
                            if speech.busyIDs.contains(sentence.id) {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: speech.playingID == sentence.id ? "stop.fill" : "play.fill")
                            }
                        }
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).foregroundStyle(Palette.green)
                    .disabled(speech.busyIDs.contains(sentence.id))
                    .accessibilityLabel(L(speech.busyIDs.contains(sentence.id) ? "generating_audio" : (speech.playingID == sentence.id ? "stop_audio" : "play_audio")))
                }
            } else {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(L("added_on", (try? Schedule.date(sentence.learningDate)).map { Localization.date($0, template: "yMMMd") } ?? sentence.learningDate)).font(.system(size: 12)).foregroundStyle(Palette.muted)
                Spacer()
                HStack(spacing: 0) {
                    if let onHide {
                        Button {
                            notesExpanded = false
                            onHide()
                        } label: {
                            Image(systemName: "eye.slash")
                                .resizable().scaledToFit()
                                .frame(width: 20, height: 20)
                                .frame(width: 30, height: 44)
                                .contentShape(Rectangle())
                        }
                        .foregroundStyle(Palette.muted)
                        .accessibilityLabel(L("hide_content"))
                    }
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
            Text(sentence.text).font(.system(size: textSize.bodySize, weight: .medium))
                .lineLimit(compact ? 1 : nil)
                .truncationMode(.tail)
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
                DisclosureGroup(isExpanded: Binding(get: { notesExpanded ?? (!forceNotesCollapsed && !collapseNotes) }, set: { notesExpanded = $0 })) {
                    Text(sentence.translation).font(.system(size: textSize.noteSize)).lineSpacing(5)
                        .foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6)
                } label: {
                    Text(L("notes")).font(.system(size: 14)).foregroundStyle(Palette.muted)
                }.tint(Palette.green)
            }
        }
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
        .onChange(of: forceNotesCollapsed) { _, collapsed in
            if collapsed { notesExpanded = false }
        }


    }
}


/// Uses a compact single-line height until the sentence is revealed.
struct ListenFirstCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var speech: SpeechController
    let sentence: Sentence
    let fresh: Bool
    let enabled: Bool
    let day: String
    @State private var revealed = false
    @State private var forceNotesCollapsed = false
    @ScaledMetric(relativeTo: .body) private var singleLineControlSize: CGFloat = 109

    var body: some View {
        SentenceCard(sentence: sentence, fresh: fresh, onHide: enabled ? {
            forceNotesCollapsed = true
            withAnimation(.easeOut(duration: 0.2)) { revealed = false }
        } : nil, forceNotesCollapsed: forceNotesCollapsed)
            .fixedSize(horizontal: false, vertical: true)
            .frame(height: enabled && !revealed ? singleLineControlSize + 20 : nil, alignment: .top)
            .clipped()
            .opacity(enabled && !revealed ? 0 : 1)
            .allowsHitTesting(!enabled || revealed)
            .accessibilityHidden(enabled && !revealed)
            .overlay {
                if enabled && !revealed {
                    GeometryReader { geometry in
                        let baselineSliderWidth: CGFloat = max(44, geometry.size.width * 2 / 3 - 20)
                        let side: CGFloat = max(44, min(singleLineControlSize, geometry.size.width - baselineSliderWidth - 30))
                        let playSide = max(44, side - 40)
                        let sliderHeight = playSide + 12
                        let sliderWidth = max(44, geometry.size.width - 40 - 10 - playSide)
                        HStack(spacing: 10) {
                            RevealSlider(height: sliderHeight) {
                                withAnimation(.easeOut(duration: 0.2)) { revealed = true }
                            }
                            .frame(width: sliderWidth, height: sliderHeight)
                            Button { speech.play(sentence) } label: {
                                Group {
                                    if speech.busyIDs.contains(sentence.id) {
                                        ProgressView().tint(Palette.onAccent)
                                    } else {
                                        Image(systemName: speech.playingID == sentence.id ? "stop.fill" : "play.fill")
                                            .font(.system(size: playSide * 0.34, weight: .medium))
                                    }
                                }
                                .frame(width: playSide, height: playSide)
                                .foregroundStyle(Palette.onAccent)
                                .background(Palette.green, in: Circle())
                                .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .disabled(speech.busyIDs.contains(sentence.id))
                            .accessibilityLabel(L(speech.busyIDs.contains(sentence.id) ? "generating_audio" : (speech.playingID == sentence.id ? "stop_audio" : "play_audio")))
                        }
                        .padding(6)
                        .overlay {
                            Capsule().strokeBorder(Palette.border, lineWidth: 1)
                                .allowsHitTesting(false)
                        }
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background {
                            Image("ListenCover")
                                .resizable()
                                .scaledToFill()
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .overlay {
                                    Palette.background.opacity(colorScheme == .dark ? 0.86 : 0.56)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .accessibilityHidden(true)
                        }
                    }
                }
            }
            .onChange(of: day) { _, _ in revealed = false }
            .onChange(of: sentence.text) { _, _ in revealed = false }
    }
}

private struct RevealSlider: View {
    let height: CGFloat
    let onReveal: () -> Void
    @State private var offset: CGFloat = 0
    var body: some View {
        GeometryReader { geometry in
            let knob: CGFloat = height - 12
            let travel: CGFloat = max(1, geometry.size.width - knob - 12)
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.review)
                    .overlay(Capsule().strokeBorder(Palette.border, lineWidth: 1))
                Text(L("slide_reveal"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center)
                    .padding(.leading, knob + 8).padding(.trailing, 8)
                    .frame(maxWidth: .infinity)
                    .opacity(1 - Double(offset / travel))
                Image(systemName: "chevron.right")
                    .font(.system(size: 22, weight: .semibold))
                    .frame(width: knob, height: knob)
                    .foregroundStyle(Palette.onAccent)
                    .background(Palette.green, in: Circle())
                    .offset(x: 6 + offset)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 8)
                .onChanged { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    offset = min(travel, max(0, value.translation.width))
                }
                .onEnded { _ in
                    if offset >= travel * 0.9 { onReveal() }
                    withAnimation(.easeOut(duration: 0.2)) { offset = 0 }
                })
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L("slide_reveal"))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onReveal() }
        }
        .frame(height: height)
    }
}
