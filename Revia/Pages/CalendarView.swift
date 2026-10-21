import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var language: AppLanguage
    @EnvironmentObject private var store: Store
    @State private var month = Schedule.monthStart(Date())
    @State private var adding = false
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private var days: [Date?] {
        let calendar = Schedule.calendar
        let count = calendar.range(of: .day, in: .month, for: month)!.count
        let padding = (calendar.component(.weekday, from: month) + 5) % 7
        let cells = ((padding + count + 6) / 7) * 7
        return (0..<cells).map { index in
            guard index >= padding, index < padding + count else { return nil }
            return calendar.date(byAdding: .day, value: index - padding, to: month)
        }
    }
    private var monthTitle: String {
        Localization.date(month, template: "yMMMM")
    }
    var body: some View {
        let _ = language.code
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(L("brand_line")).font(.system(size: 11)).tracking(2).foregroundStyle(Palette.green)
                    Text(L("calendar_title")).font(.system(size: 30, weight: .bold)).foregroundStyle(Palette.ink)
                    Text(L("calendar_subtitle")).font(.system(size: 14)).foregroundStyle(Palette.muted)
                }.padding(.top, 12)
                HStack {
                    Text(monthTitle).lineLimit(1).minimumScaleFactor(0.75).font(.system(size: 22, weight: .semibold)).foregroundStyle(Palette.ink)
                    Spacer()
                    Button { move(-1) } label: { Image(systemName: "chevron.left").padding(8) }.accessibilityLabel(L("prev_month"))
                    Button(L("today")) { month = Schedule.monthStart(Date()) }.font(.system(size: 14))
                    Button { move(1) } label: { Image(systemName: "chevron.right").padding(8) }.accessibilityLabel(L("next_month"))
                }.padding(.top, 8)
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Localization.weekdays, id: \.self) { day in
                        Text(day).font(.system(size: 14)).foregroundStyle(Palette.muted).frame(height: 30)
                    }
                    ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                        if let date {
                            NavigationLink { DayView(date: date) } label: { dayCell(date) }.buttonStyle(.plain)
                        } else { Color.clear.frame(height: 52) }
                    }
                }
                PrimaryButton(title: L("add_today")) { adding = true }
                Divider().padding(.top, 8)
                VStack(alignment: .leading, spacing: 10) {
                    Text(L("memory_title")).font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                    Text(L("review_plan"))
                        .font(.system(size: 14)).foregroundStyle(Palette.muted).lineSpacing(5)
                }
            }.padding(24)
        }
        .background(Palette.background).navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $adding) { AddSentenceView(date: Date()) }
    }
    private func move(_ offset: Int) { month = Schedule.calendar.date(byAdding: .month, value: offset, to: month)! }
    private func dayCell(_ date: Date) -> some View {
        let key = Schedule.key(date)
        let today = Schedule.calendar.isDateInToday(date)
        let fresh = store.sentences.contains { $0.learningDate == key }
        let review = store.reviews.contains { $0.date == key }
        return VStack(spacing: 4) {
            Text("\(Schedule.calendar.component(.day, from: date))")
                .font(.system(size: 16)).frame(width: 36, height: 36)
                .foregroundStyle(today ? .white : Palette.ink)
                .background(today ? Palette.green : .clear, in: Circle())
            HStack(spacing: 3) {
                if fresh { Circle().fill(Palette.green).frame(width: 5, height: 5) }
                if review { Circle().fill(Color.gray.opacity(0.6)).frame(width: 5, height: 5) }
            }.frame(height: 6)
        }.frame(maxWidth: .infinity).frame(height: 52)
            .accessibilityLabel("\(key)\(fresh ? L("has_new") : "")\(review ? L("has_review") : "")")
    }
}
