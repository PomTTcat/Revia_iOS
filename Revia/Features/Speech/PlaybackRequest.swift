import Foundation

struct PlaybackRequest: Equatable {
    let id = UUID()
    let sentenceID: Int64
}

/// A late completion may finish only its own request, never a newer play intent.
struct PlaybackRequestState {
    private(set) var pending: PlaybackRequest?
    mutating func begin(sentenceID: Int64) -> PlaybackRequest {
        let request = PlaybackRequest(sentenceID: sentenceID)
        pending = request
        return request
    }
    func isCurrent(_ request: PlaybackRequest) -> Bool { pending == request }
    mutating func finish(_ request: PlaybackRequest) {
        if isCurrent(request) { pending = nil }
    }
    mutating func cancel() { pending = nil }
}
