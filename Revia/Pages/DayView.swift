import SwiftUI

struct DayView: View {
    @EnvironmentObject private var language: AppLanguage
    @EnvironmentObject private var store: Store
    let date: Date
    @State private var adding = false
    private var fresh: [Sentence] { store.newSentences(on: Schedule.key(date)) }
    private var reviews: [Sentence] { store.reviewSentences(on: Schedule.key(date)) }
    var body: some View {
        let _ = language.code
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(Schedule.title(date)).font(.system(size: 32, weight: .bold)).foregroundStyle(Palette.ink)
                Text(L("day_counts", fresh.count, reviews.count)).font(.system(size: 14)).foregroundStyle(Palette.muted)
                Text(L("new_count", fresh.count)).font(.system(size: 18, weight: .semibold)).foregroundStyle(Palette.ink).padding(.top, 20)
                if fresh.isEmpty { EmptyViewMessage(text: L("no_new")) }
                ForEach(fresh) { SentenceCard(sentence: $0, fresh: true) }
                PrimaryButton(title: L("add_for_day")) { adding = true }
                Text(L("review_count", reviews.count)).font(.system(size: 18, weight: .semibold)).foregroundStyle(Palette.ink).padding(.top, 20)
                if reviews.isEmpty { EmptyViewMessage(text: L("no_reviews")) }
                ForEach(reviews) { SentenceCard(sentence: $0, fresh: false) }
            }.padding(24)
        }.background(Palette.background)
            .navigationTitle(Localization.date(date, template: "yMMMd"))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $adding) { AddSentenceView(date: date) }
    }
}
