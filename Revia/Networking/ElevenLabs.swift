import Foundation
import RxSwift

struct Voice: Codable, Identifiable, Equatable {
    let voice_id: String
    let name: String
    var id: String { voice_id }
}
struct VoicesPage: Decodable {
    let voices: [Voice]
    let has_more: Bool?
    let next_page_token: String?
}
enum SpeechFailure: LocalizedError {
    case authentication, permission, quota, rateLimited, unavailable, invalidAudio
    var errorDescription: String? {
        switch self {
        case .authentication: return L("invalid_key")
        case .permission: return L("key_permission")
        case .quota: return L("low_credits")
        case .rateLimited: return L("rate_limited")
        case .unavailable: return L("service_unavailable")
        case .invalidAudio: return L("invalid_audio")
        }
    }
}

final class ElevenLabs {
    static let model = "eleven_multilingual_v2"
    private let session: URLSession
    init(session: URLSession = .shared) { self.session = session }
    private func request(path: String, key: String, query: [URLQueryItem] = [], body: Data? = nil) -> URLRequest {
        var url = URLComponents(string: "https://api.elevenlabs.io" + path)!
        url.queryItems = query.isEmpty ? nil : query
        var request = URLRequest(url: url.url!, timeoutInterval: 90)
        request.setValue(key, forHTTPHeaderField: "xi-api-key")
        if let body {
            request.httpMethod = "POST"
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        }
        return request
    }
    private func send(_ request: URLRequest, audio: Bool = false) -> Single<Data> {
        Single.create { observer in
            let task = self.session.dataTask(with: request) { data, response, error in
                if error != nil { observer(.failure(ReviaError.message(L("network_failed")))); return }
                guard let response = response as? HTTPURLResponse, let data else {
                    observer(.failure(SpeechFailure.unavailable)); return
                }
                guard (200..<300).contains(response.statusCode) else {
                    let failure: SpeechFailure
                    switch response.statusCode {
                    case 401: failure = .authentication
                    case 403: failure = .permission
                    case 402: failure = .quota
                    case 429: failure = .rateLimited
                    default: failure = .unavailable
                    }
                    let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
                    let detail = object?["detail"] as? [String: Any]
                    observer(.failure(detail?["status"] as? String == "quota_exceeded" ? SpeechFailure.quota : failure)); return
                }
                if audio && (data.isEmpty || !(response.mimeType?.hasPrefix("audio/") ?? false)) {
                    observer(.failure(SpeechFailure.invalidAudio)); return
                }
                observer(.success(data))
            }
            task.resume()
            return Disposables.create { task.cancel() }
        }
    }
    func validate(key: String) -> Single<[Voice]> {
        // Account and voice reads do not synthesize audio or spend TTS credits.
        send(request(path: "/v1/user", key: key)).flatMap { data in
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any], object["user_id"] as? String != nil else {
                throw SpeechFailure.unavailable
            }
            return self.voices(key: key)
        }
    }
    private func voices(key: String, token: String? = nil, seen: Set<String> = []) -> Single<[Voice]> {
        var query = [URLQueryItem(name: "page_size", value: "100")]
        if let token { query.append(URLQueryItem(name: "next_page_token", value: token)) }
        return send(request(path: "/v2/voices", key: key, query: query)).flatMap { data in
            let page = try JSONDecoder().decode(VoicesPage.self, from: data)
            if page.has_more == true {
                guard let next = page.next_page_token, !seen.contains(next) else { throw SpeechFailure.unavailable }
                return self.voices(key: key, token: next, seen: seen.union([next])).map { page.voices + $0 }
            }
            return .just(page.voices)
        }
    }
    func generate(text: String, voice: String, key: String) -> Single<Data> {
        guard voice.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil else {
            return .error(ReviaError.message(L("invalid_voice")))
        }
        do {
            let body = try JSONSerialization.data(withJSONObject: ["text": text, "model_id": Self.model])
            return send(request(path: "/v1/text-to-speech/" + voice, key: key,
                                query: [URLQueryItem(name: "output_format", value: "mp3_44100_128")], body: body), audio: true)
        } catch { return .error(error) }
    }
}
