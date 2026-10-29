import Foundation
import AVFoundation
import NaturalLanguage
import RxSwift

enum SpeechSource: String, CaseIterable, Identifiable {
    case automatic, system, elevenlabs
    var id: String { rawValue }
    var title: String { L("speech_source_" + rawValue) }
    func resolved(elevenReady: Bool) -> SpeechSource {
        self == .automatic ? (elevenReady ? .elevenlabs : .system) : self
    }
}

enum SystemSpeechLanguage: String, CaseIterable, Identifiable {
    case automatic, japanese = "ja", english = "en", chinese = "zh"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .automatic: return L("speech_auto_language")
        case .japanese: return "日本語"
        case .english: return "English"
        case .chinese: return "中文"
        }
    }
    func code(for text: String) -> String {
        guard self == .automatic else { return rawValue }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage?.rawValue ?? Localization.selection.rawValue
    }
}

struct SystemVoice: Identifiable, Equatable {
    enum Gender { case male, female, unspecified }
    let id: String
    let name: String
    let language: String
    let gender: Gender
    let quality: Int
    var title: String {
        switch gender {
        case .male: return name + " · " + L("male_voice")
        case .female: return name + " · " + L("female_voice")
        case .unspecified: return name
        }
    }
    func matches(_ code: String) -> Bool {
        language.split(separator: "-").first == code.split(separator: "-").first
    }
    init(_ voice: AVSpeechSynthesisVoice) {
        id = voice.identifier; name = voice.name; language = voice.language; quality = voice.quality.rawValue
        switch voice.gender {
        case .male: gender = .male
        case .female: gender = .female
        default: gender = .unspecified
        }
    }
}

@MainActor
protocol SystemSpeechProviding {
    var voices: [SystemVoice] { get }
    func voice(language: String, preferredID: String?) -> SystemVoice?
    func generate(text: String, voice: SystemVoice) -> Single<Data>
}

@MainActor
final class SystemSpeechGenerator: SystemSpeechProviding {
    static let model = "apple_tts_v1"
    var voices: [SystemVoice] {
        AVSpeechSynthesisVoice.speechVoices().map(SystemVoice.init).sorted {
            if $0.quality != $1.quality { return $0.quality > $1.quality }
            return $0.id < $1.id
        }
    }
    func voice(language: String, preferredID: String?) -> SystemVoice? {
        let matching = voices.filter { $0.matches(language) }
        if let preferredID, let voice = matching.first(where: { $0.id == preferredID }) { return voice }
        if let voice = matching.first { return voice }
        return AVSpeechSynthesisVoice(language: language).map(SystemVoice.init)
    }
    private struct Pending {
        let id: UUID
        let request: SystemSpeechRequest
        let text: String
        let voiceID: String
    }
    private var pending: [Pending] = []
    private var activeID: UUID?
    func generate(text: String, voice: SystemVoice) -> Single<Data> {
        Single.create { [weak self] observer in
            guard let self else { observer(.failure(SpeechFailure.unavailable)); return Disposables.create() }
            let id = UUID()
            let request = SystemSpeechRequest { [weak self] event in
                self?.finished(id)
                observer(event)
            }
            self.pending.append(Pending(id: id, request: request, text: text, voiceID: voice.id))
            self.startNext()
            return Disposables.create { [weak self] in Task { @MainActor in self?.cancel(id) } }
        }
    }
    private func startNext() {
        guard activeID == nil, let next = pending.first else { return }
        activeID = next.id
        next.request.start(text: next.text, voiceID: next.voiceID)
    }
    private func finished(_ id: UUID) {
        pending.removeAll { $0.id == id }
        if activeID == id { activeID = nil }
        startNext()
    }
    private func cancel(_ id: UUID) {
        pending.first { $0.id == id }?.request.cancel()
        finished(id)
    }
}

/// Writes Apple's PCM buffers to CAF before returning data to the shared cache pipeline.
@MainActor
private final class SystemSpeechRequest: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var file: AVAudioFile?
    private let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("caf")
    private var completed = false
    private var timeout: Timer?
    private let completion: (SingleEvent<Data>) -> Void
    init(completion: @escaping (SingleEvent<Data>) -> Void) { self.completion = completion; super.init() }
    func start(text: String, voiceID: String) {
        guard let voice = AVSpeechSynthesisVoice(identifier: voiceID) else {
            finish(.failure(ReviaError.message(L("system_voice_missing")))); return
        }
        synthesizer.delegate = self
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        timeout = Timer.scheduledTimer(withTimeInterval: 90, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.finish(.failure(ReviaError.message(L("system_speech_failed")))) }
        }
        synthesizer.write(utterance) { [weak self] buffer in
            DispatchQueue.main.async { self?.consume(buffer) }
        }
    }
    private func consume(_ buffer: AVAudioBuffer) {
        guard !completed else { return }
        guard let pcm = buffer as? AVAudioPCMBuffer else { finish(.failure(SpeechFailure.invalidAudio)); return }
        do {
            if pcm.frameLength == 0 {
                // Close the file before reading so its header and length are finalized.
                file = nil
                let data = try Data(contentsOf: url)
                guard !data.isEmpty else { throw SpeechFailure.invalidAudio }
                finish(.success(data))
            } else {
                if file == nil {
                    file = try AVAudioFile(forWriting: url, settings: pcm.format.settings,
                                           commonFormat: pcm.format.commonFormat, interleaved: pcm.format.isInterleaved)
                }
                try file?.write(from: pcm)
            }
        } catch { finish(.failure(ReviaError.message(L("system_speech_failed")))) }
    }
    func cancel() {
        guard !completed else { return }
        completed = true
        cleanup()
    }
    private func finish(_ event: SingleEvent<Data>) {
        guard !completed else { return }
        completed = true
        cleanup()
        completion(event)
    }
    private func cleanup() {
        timeout?.invalidate(); timeout = nil
        synthesizer.stopSpeaking(at: .immediate)
        file = nil
        try? FileManager.default.removeItem(at: url)
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in self?.finish(.failure(ReviaError.message(L("system_speech_failed")))) }
    }
}
