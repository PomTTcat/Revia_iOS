import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var language: AppLanguage
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var addTransition
    @State private var now = Date()
    private let clock = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    @EnvironmentObject private var store: Store
    @State private var month = Schedule.monthStart(Date())
    @State private var adding = false
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private var days: [Date?] { Schedule.monthDays(month) }
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
                HStack {
                    Spacer()
                    if #available(iOS 18.0, *), !reduceMotion {
                        addButton
                            .matchedTransitionSource(id: "add-sentence", in: addTransition) { source in
                                source.background(Palette.green)
                                    .clipShape(RoundedRectangle(cornerRadius: 30))
                            }
                    } else {
                        addButton
                    }
                    Spacer()
                }.padding(.top, 8)
            }.padding(24)
        }
        .background(Palette.background).navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .onAppear { now = Date() }
        .onReceive(clock) { now = $0 }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in now = Date() }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in now = Date() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { now = Date() } }
        .sheet(isPresented: $adding) {
            if #available(iOS 18.0, *), !reduceMotion {
                AddSentenceView(date: Date())
                    .navigationTransition(.zoom(sourceID: "add-sentence", in: addTransition))
                    .presentationCornerRadius(28)
            } else {
                AddSentenceView(date: Date())
            }
        }
    }
    private var addButton: some View {
        Button { adding = true } label: {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Palette.onAccent)
                .frame(width: 60, height: 60)
                .background(Palette.green, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L("add_today"))
    }
    private func move(_ offset: Int) { month = Schedule.calendar.date(byAdding: .month, value: offset, to: month)! }
    private func dayCell(_ date: Date) -> some View {
        let key = Schedule.key(date)
        let today = Schedule.key(date) == Schedule.key(now)
        let fresh = store.sentences.contains { $0.learningDate == key }
        let review = store.reviews.contains { $0.date == key }
        return VStack(spacing: 4) {
            Text("\(Schedule.calendar.component(.day, from: date))")
                .font(.system(size: 16)).frame(width: 36, height: 36)
                .foregroundStyle(today ? Palette.onAccent : Palette.ink)
                .background(today ? Palette.green : .clear, in: Circle())
            ZStack {
                if fresh || review {
                    Circle().fill(today && fresh ? Palette.green : Palette.marker)
                        .frame(width: 5, height: 5)
                }
            }.frame(height: 6)
        }.frame(maxWidth: .infinity).frame(height: 52)
            .accessibilityLabel("\(key)\(fresh ? L("has_new") : "")\(review ? L("has_review") : "")")
    }
}
