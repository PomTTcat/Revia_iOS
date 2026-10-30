import Foundation

enum PlaybackRepeatCount: Int, CaseIterable, Identifiable {
    case twice = 2, three = 3, five = 5, forever = 0
    var id: Int { rawValue }
    var title: String { self == .forever ? L("repeat_forever") : L("repeat_times", rawValue) }
}

struct PlaybackRepeatSettings {
    static let enabledKey = "speech.repeatEnabled"
    static let countKey = "speech.repeatCount"
    var enabled: Bool
    var count: PlaybackRepeatCount
    init(defaults: UserDefaults = .standard) {
        enabled = defaults.bool(forKey: Self.enabledKey)
        count = (defaults.object(forKey: Self.countKey) as? NSNumber)
            .flatMap { PlaybackRepeatCount(rawValue: $0.intValue) } ?? .three
    }
    func save(in defaults: UserDefaults) {
        defaults.set(enabled, forKey: Self.enabledKey)
        defaults.set(count.rawValue, forKey: Self.countKey)
    }
}

/// Snapshots settings for one playback, counting the first play toward the total.
struct PlaybackRepeatSession {
    static let interval: TimeInterval = 3
    private var remaining: Int?
    init(settings: PlaybackRepeatSettings) {
        remaining = settings.enabled ? (settings.count == .forever ? nil : settings.count.rawValue) : 1
    }
    mutating func finishedPlayback() -> Bool {
        guard let remaining else { return true }
        self.remaining = max(0, remaining - 1)
        return remaining > 1
    }
}
