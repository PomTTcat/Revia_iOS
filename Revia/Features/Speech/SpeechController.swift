import Foundation
import Combine
import AVFoundation
import RxSwift
import RxRelay

@MainActor
final class SpeechController: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var draft = ""
    @Published private(set) var active = false
    @Published private(set) var validating = false
    @Published private(set) var canGenerate = false
    @Published private(set) var source: SpeechSource = .automatic
    @Published private(set) var systemLanguage: SystemSpeechLanguage = .automatic
    @Published private(set) var systemVoices: [SystemVoice] = []
    @Published private(set) var systemSelections: [String: String] = [:]
    var effectiveSource: SpeechSource { source.resolved(elevenReady: active && voices.contains { $0.id == selectedVoiceID }) }
    private let sourceState = BehaviorRelay<SpeechSource>(value: .automatic)
    private let systemState = BehaviorRelay<Bool>(value: false)
    private let systemSpeech: any SystemSpeechProviding
    @Published private(set) var voices: [Voice] = []
    @Published private(set) var selectedVoiceID = ""
    @Published private(set) var storageBytes: Int64 = 0
    @Published private(set) var busyIDs: Set<Int64> = []
    @Published private(set) var playingID: Int64?
    @Published var alert: String?
    private let activeState = BehaviorRelay<Bool>(value: false)
    private let voiceState = BehaviorRelay<Bool>(value: false)
    private let bag = DisposeBag()
    private let credentials: CredentialStorage
    private let api: ElevenLabs
    private var activeKey: String?
    private var validation: Disposable?
    private var requests: [Int64: Disposable] = [:]
    private var database: Database?
    private var cache: AudioCache?
    private var player: AVAudioPlayer?
    private var requestedPlaybackID: Int64?
    private let defaults: UserDefaults

    init(api: ElevenLabs = ElevenLabs(), defaults: UserDefaults = .standard, credentials: CredentialStorage = CredentialStore(), systemSpeech: (any SystemSpeechProviding)? = nil) {
        self.api = api; self.defaults = defaults; self.credentials = credentials
        self.systemSpeech = systemSpeech ?? SystemSpeechGenerator()
        super.init()
        source = defaults.string(forKey: "speech.source").flatMap(SpeechSource.init(rawValue:)) ?? .automatic
        systemLanguage = defaults.string(forKey: "speech.systemLanguage").flatMap(SystemSpeechLanguage.init(rawValue:)) ?? .automatic
        systemSelections = defaults.dictionary(forKey: "speech.systemVoices") as? [String: String] ?? [:]
        refreshSystemVoices()
        sourceState.accept(source)
        selectedVoiceID = defaults.string(forKey: "speech.voice") ?? ElevenLabs.defaultVoice.id
        if let data = defaults.data(forKey: "speech.voices"), let saved = try? JSONDecoder().decode([Voice].self, from: data) { voices = saved }
        for voice in ElevenLabs.presetVoices where !voices.contains(where: { $0.id == voice.id }) { voices.append(voice) }
        do {
            activeKey = try credentials.read()
            draft = activeKey ?? ""
            active = activeKey != nil
        } catch { alert = error.localizedDescription }
        activeState.accept(active)
        voiceState.accept(voices.contains { $0.id == selectedVoiceID })
        Observable.combineLatest(activeState, voiceState, sourceState, systemState)
            .map { active, voice, source, system in
                source.resolved(elevenReady: active && voice) == .system ? system : active && voice
            }.distinctUntilChanged()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in self?.canGenerate = $0 })
            .disposed(by: bag)
    }
    func configure(database: Database, directory: URL) throws {
        self.database = database
        cache = try AudioCache(directory: directory.appendingPathComponent("Speech", isDirectory: true))
        // Reconcile orphan files left by an interrupted file/database operation.
        let referenced = Set(try database.audioRecords().map(\.filename))
        for url in try FileManager.default.contentsOfDirectory(at: cache!.directory, includingPropertiesForKeys: nil) where AudioFormat(rawValue: url.pathExtension) != nil && !referenced.contains(url.lastPathComponent) {
            try cache!.remove(url.lastPathComponent)
        }
        refreshStorage()
    }
    func selectSource(_ value: SpeechSource) {
        source = value
        defaults.set(value.rawValue, forKey: "speech.source")
        sourceState.accept(value)
    }
    func selectSystemLanguage(_ value: SystemSpeechLanguage) {
        systemLanguage = value
        defaults.set(value.rawValue, forKey: "speech.systemLanguage")
    }
    func selectSystemVoice(_ id: String, language: String) {
        systemSelections[language] = id.isEmpty ? nil : id
        defaults.set(systemSelections, forKey: "speech.systemVoices")
    }
    func refreshSystemVoices() {
        systemVoices = systemSpeech.voices
        systemState.accept(!systemVoices.isEmpty)
    }
    private func systemVoice(for text: String) -> SystemVoice? {
        let code = systemLanguage.code(for: text)
        let base = String(code.split(separator: "-").first ?? "en")
        return systemSpeech.voice(language: code, preferredID: systemSelections[base])
    }
    func changeKey(_ value: String) {
        guard value != draft else { return }
        draft = value
        validation?.dispose(); validation = nil; validating = false
        activeKey = nil; active = false; activeState.accept(false)
        do { try credentials.delete() } catch { alert = error.localizedDescription }
    }
    func deactivate() {
        changeKey("")
        // Also handle an already-empty draft after a failed credential read.
        activeKey = nil; active = false; activeState.accept(false)
        do { try credentials.delete() } catch { alert = error.localizedDescription }
    }
    func validate() {
        let key = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !validating else { return }
        validation?.dispose(); validating = true
        validation = api.validate(key: key, voice: selectedVoiceID).observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] list in
                guard let self else { return }
                self.validating = false
                do {
                    try self.credentials.save(key)
                    self.activeKey = key; self.draft = key; self.active = true
                    self.voices = Dictionary((list + ElevenLabs.presetVoices).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }).values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                    self.defaults.set(try JSONEncoder().encode(self.voices), forKey: "speech.voices")
                    let selected = self.voices.contains { $0.id == self.selectedVoiceID } ? self.selectedVoiceID : (self.voices.first?.id ?? "")
                    self.selectVoice(selected)
                    self.activeState.accept(true)
                    self.alert = self.voices.isEmpty ? L("no_voices") : L("key_activated")
                } catch {
                    self.activeKey = nil; self.active = false; self.activeState.accept(false)
                    self.alert = error.localizedDescription
                }
            }, onFailure: { [weak self] error in
                guard let self else { return }
                self.validating = false
                // Network failure during revalidation does not revoke a previously verified Key.
                if case SpeechFailure.authentication = error { self.deactivate() }
                self.alert = error.localizedDescription
            })
    }
    func selectCustomVoice(_ value: String) {
        let id = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return }
        if !voices.contains(where: { $0.id == id }) {
            voices.append(ElevenLabs.presetVoices.first(where: { $0.id == id }) ?? Voice(voice_id: id, name: id))
        }
        if let data = try? JSONEncoder().encode(voices) { defaults.set(data, forKey: "speech.voices") }
        selectVoice(id)
    }
    func selectVoice(_ id: String) {
        selectedVoiceID = id
        defaults.set(id, forKey: "speech.voice")
        voiceState.accept(voices.contains { $0.id == id })
    }
    func refreshStorage() {
        do { storageBytes = try cache?.bytes() ?? 0 }
        catch { alert = L("storage_read_failed", error.localizedDescription) }
    }
    func play(_ sentence: Sentence) {
        if playingID == sentence.id { stop(); return }
        guard !busyIDs.contains(sentence.id) else { return }
        requestedPlaybackID = sentence.id
        prepare(sentence, play: true) { [weak self] result in
            if case .failure(let error) = result { self?.alert = error.localizedDescription }
        }
    }
    func prepare(_ sentence: Sentence, play: Bool = false, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let database, let cache else { completion(.failure(ReviaError.message(L("audio_not_ready")))); return }
        guard !busyIDs.contains(sentence.id) else { completion(.failure(ReviaError.message(L("audio_busy")))); return }
        do {
            let records = try database.audioRecords(sentenceID: sentence.id)
            let engine = effectiveSource
            let appleVoice = engine == .system ? systemVoice(for: sentence.text) : nil
            let voice = engine == .system ? (appleVoice?.id ?? "") : selectedVoiceID
            let model = engine == .system ? SystemSpeechGenerator.model : ElevenLabs.model
            let matching = records.first { $0.text == sentence.text && $0.voiceID == voice && $0.modelID == model && $0.version == AudioCache.version }
            // Always use a matching local file before considering a paid request.
            if let record = matching, let url = cache.existing(record.filename) {
                if play && requestedPlaybackID == sentence.id { try startPlayer(url, sentenceID: sentence.id) }
                completion(.success(())); return
            }
            // Changing the voice affects new recordings; existing audio stays playable without a paid regeneration.
            if let record = records.first(where: { $0.text == sentence.text && cache.existing($0.filename) != nil }), let url = cache.existing(record.filename) {
                if play && requestedPlaybackID == sentence.id { try startPlayer(url, sentenceID: sentence.id) }
                completion(.success(())); return
            }
            guard canGenerate else { throw ReviaError.message(L("audio_missing")) }
            let key = activeKey
            let generate: Single<Data>
            if engine == .system {
                guard let appleVoice else { throw ReviaError.message(L("system_voice_missing")) }
                generate = systemSpeech.generate(text: sentence.text, voice: appleVoice)
            } else {
                guard let key, !voice.isEmpty else { throw ReviaError.message(L("audio_missing")) }
                generate = api.generate(text: sentence.text, voice: voice, key: key)
            }
            let filename = AudioCache.filename(text: sentence.text, voice: voice, model: model, format: engine == .system ? .caf : .mp3)
            let record = AudioRecord(sentenceID: sentence.id, text: sentence.text, voiceID: voice, modelID: model, filename: filename, version: AudioCache.version)
            // Identical sentences can share one file while retaining separate database references.
            if let url = cache.existing(filename) {
                try database.saveAudio(record)
                if play && requestedPlaybackID == sentence.id { try startPlayer(url, sentenceID: sentence.id) }
                completion(.success(())); return
            }
            busyIDs.insert(sentence.id)
            requests[sentence.id] = generate
                .observe(on: MainScheduler.instance)
                .subscribe(onSuccess: { [weak self] data in
                    guard let self else { return }
                    defer { self.busyIDs.remove(sentence.id); self.requests[sentence.id] = nil; self.refreshStorage() }
                    do {
                        // Decode before persistence so malformed audio is never cached as a success.
                        _ = try AVAudioPlayer(data: data)
                        let url = try cache.write(data, filename: filename)
                        do { try database.saveAudio(record) }
                        catch {
                            if !(try database.audioRecords()).contains(where: { $0.filename == filename }) { try? cache.remove(filename) }
                            throw error
                        }
                        if play && self.requestedPlaybackID == sentence.id { try self.startPlayer(url, sentenceID: sentence.id) }
                        completion(.success(()))
                    } catch { completion(.failure(error)) }
                }, onFailure: { [weak self] error in
                    guard let self else { return }
                    self.busyIDs.remove(sentence.id); self.requests[sentence.id] = nil
                    if case SpeechFailure.authentication = error, engine == .elevenlabs, self.activeKey == key { self.deactivate() }
                    completion(.failure(error))
                })
        } catch { completion(.failure(error)) }
    }
    func mutateSentence(_ id: Int64, change: () throws -> Void) throws {
        guard let database, let cache else { try change(); return }
        requests[id]?.dispose(); requests[id] = nil; busyIDs.remove(id)
        if playingID == id { stop() }
        if requestedPlaybackID == id { requestedPlaybackID = nil }
        let files = Set(try database.audioRecords(sentenceID: id).map(\.filename))
        try change()
        let retained = Set(try database.audioRecords().map(\.filename))
        defer { refreshStorage() }
        for filename in files.subtracting(retained) { try cache.remove(filename) }
    }
    private func startPlayer(_ url: URL, sentenceID: Int64) throws {
        stop()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            guard player.prepareToPlay(), player.play() else { throw SpeechFailure.invalidAudio }
            self.player = player; playingID = sentenceID
        } catch { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation); throw error }
    }
    func stop() {
        player?.stop(); player = nil; playingID = nil; requestedPlaybackID = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in if self?.player === player { self?.stop() } }
    }
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in
            guard self?.player === player else { return }
            self?.stop(); self?.alert = L("playback_failed")
        }
    }
}
