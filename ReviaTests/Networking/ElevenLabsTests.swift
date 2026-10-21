import XCTest
import RxSwift
@testable import Revia

private final class MockElevenProtocol: URLProtocol {
    static var handle: ((URLRequest) throws -> (Int, String, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (code, type, data) = try Self.handle!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: ["Content-Type": type])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
final class ElevenLabsTests: XCTestCase {
    private var session: URLSession!
    private var api: ElevenLabs!
    override func setUp() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockElevenProtocol.self]
        session = URLSession(configuration: config)
        api = ElevenLabs(session: session)
    }
    override func tearDown() { session.invalidateAndCancel(); MockElevenProtocol.handle = nil }
    func testValidationChecksTTSAndLoadsPaginatedVoices() {
        let done = expectation(description: "validated")
        var paths: [String] = []
        MockElevenProtocol.handle = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "xi-api-key"), "test-key")
            paths.append(request.url!.path)
            let body: String
            if request.url!.path.hasPrefix("/v1/text-to-speech/") {
                XCTAssertEqual(request.httpMethod, "POST")
                return (200, "audio/mpeg", Data([1, 2, 3]))
            }
            else if request.url!.query?.contains("next_page_token") == true { body = #"{"voices":[{"voice_id":"B","name":"Beta"}],"has_more":false}"# }
            else { body = #"{"voices":[{"voice_id":"A","name":"Alpha"}],"has_more":true,"next_page_token":"second"}"# }
            return (200, "application/json", Data(body.utf8))
        }
        let disposable = api.validate(key: "test-key").subscribe(onSuccess: { voices in
            XCTAssertEqual(voices.map(\.id), [ElevenLabs.defaultVoice.id, "A", "B"])
            XCTAssertEqual(paths, ["/v1/text-to-speech/" + ElevenLabs.defaultVoice.id, "/v2/voices", "/v2/voices"])
            done.fulfill()
        }, onFailure: { error in XCTFail(error.localizedDescription); done.fulfill() })
        wait(for: [done], timeout: 10); disposable.dispose()
    }
    func testTTSOnlyKeyActivatesWithoutAccountOrVoicesReadPermission() {
        let done = expectation(description: "tts-only")
        MockElevenProtocol.handle = { request in
            XCTAssertNotEqual(request.url!.path, "/v1/user")
            if request.url!.path == "/v2/voices" {
                return (401, "application/json", Data(#"{"detail":{"status":"missing_permissions"}}"#.utf8))
            }
            XCTAssertEqual(request.url!.path, "/v1/text-to-speech/customVoice")
            return (200, "audio/mpeg", Data([1, 2, 3]))
        }
        let disposable = api.validate(key: "tts-only", voice: "customVoice").subscribe(onSuccess: { voices in
            XCTAssertEqual(voices.map(\.id), ["customVoice"])
            done.fulfill()
        }, onFailure: { error in XCTFail(error.localizedDescription); done.fulfill() })
        wait(for: [done], timeout: 10); disposable.dispose()
    }
    func testMissingTTSPermissionIsNotInvalidKey() {
        let done = expectation(description: "permission")
        MockElevenProtocol.handle = { _ in
            (401, "application/json", Data(#"{"detail":{"status":"missing_permissions"}}"#.utf8))
        }
        let disposable = api.validate(key: "restricted").subscribe(onSuccess: { _ in
            XCTFail("key without TTS activated"); done.fulfill()
        }, onFailure: { error in
            guard case SpeechFailure.permission = error else { XCTFail("wrong error"); done.fulfill(); return }
            done.fulfill()
        })
        wait(for: [done], timeout: 10); disposable.dispose()
    }
    func testInvalidKeyIsRejected() {
        let done = expectation(description: "invalid")
        MockElevenProtocol.handle = { _ in (401, "application/json", Data()) }
        let disposable = api.validate(key: "bad").subscribe(onSuccess: { _ in XCTFail("invalid key accepted"); done.fulfill() }, onFailure: { error in
            guard case SpeechFailure.authentication = error else { XCTFail("wrong error"); done.fulfill(); return }
            done.fulfill()
        })
        wait(for: [done], timeout: 10); disposable.dispose()
    }
    func testGenerationUsesSentenceTextVoiceAndModel() {
        let done = expectation(description: "generated")
        MockElevenProtocol.handle = { request in
            XCTAssertEqual(request.url!.path, "/v1/text-to-speech/voiceA")
            XCTAssertTrue(request.url!.query!.contains("mp3_44100_128"))
            XCTAssertEqual(request.httpMethod, "POST")
            // URLProtocol may expose the POST body as a stream.
            if let body = request.httpBody {
                let json = try JSONSerialization.jsonObject(with: body) as! [String: String]
                XCTAssertEqual(json["text"], "今日は晴れです。")
                XCTAssertEqual(json["model_id"], ElevenLabs.model)
            }
            return (200, "audio/mpeg", Data([1, 2, 3]))
        }
        let disposable = api.generate(text: "今日は晴れです。", voice: "voiceA", key: "test-key").subscribe(onSuccess: { data in
            XCTAssertEqual(data, Data([1, 2, 3])); done.fulfill()
        }, onFailure: { error in XCTFail(error.localizedDescription); done.fulfill() })
        wait(for: [done], timeout: 10); disposable.dispose()
    }
    func testJSONSuccessIsNotCachedAsAudio() {
        let done = expectation(description: "bad audio")
        MockElevenProtocol.handle = { _ in (200, "application/json", Data("{}".utf8)) }
        let disposable = api.generate(text: "文。", voice: "voiceA", key: "test-key").subscribe(onSuccess: { _ in XCTFail("JSON accepted as audio"); done.fulfill() }, onFailure: { error in
            guard case SpeechFailure.invalidAudio = error else { XCTFail("wrong error"); done.fulfill(); return }
            done.fulfill()
        })
        wait(for: [done], timeout: 10); disposable.dispose()
    }
}

#if os(iOS)
private final class MemoryCredentials: CredentialStorage {
    var value: String?
    func read() throws -> String? { value }
    func save(_ key: String) throws { value = key }
    func delete() throws { value = nil }
}
extension ElevenLabsTests {
    @MainActor
    func testChangingVerifiedKeyDisablesGenerationUntilRevalidated() async {
        let suite = "ReviaTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let credentials = MemoryCredentials()
        let controller = SpeechController(api: api, defaults: defaults, credentials: credentials)
        XCTAssertFalse(controller.canGenerate)
        MockElevenProtocol.handle = { request in
            if request.url!.path.hasPrefix("/v1/text-to-speech/") { return (200, "audio/mpeg", Data([1, 2, 3])) }
            return (200, "application/json", Data(#"{"voices":[{"voice_id":"A","name":"Alpha"}],"has_more":false}"#.utf8))
        }
        controller.changeKey("test-key")
        controller.validate()
        // Await the real Rx callback, rather than checking an implementation-only boolean.
        for _ in 0..<100 where controller.validating { try? await Task.sleep(nanoseconds: 20_000_000) }
        XCTAssertTrue(controller.active)
        XCTAssertTrue(controller.canGenerate)
        XCTAssertEqual(credentials.value, "test-key")
        controller.changeKey("different-key")
        XCTAssertFalse(controller.active)
        XCTAssertFalse(controller.canGenerate)
        XCTAssertNil(credentials.value)
    }
}
#endif
