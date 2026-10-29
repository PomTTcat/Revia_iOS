import Foundation
import CryptoKit

struct AudioRecord: Equatable {
    let sentenceID: Int64
    let text: String
    let voiceID: String
    let modelID: String
    let filename: String
    let version: Int
}
enum AudioFormat: String { case mp3, caf }
struct AudioCache {
    static let version = 1
    let directory: URL
    init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    static func filename(text: String, voice: String, model: String, format: AudioFormat = .mp3) -> String {
        let identity = "\(version)\u{0}\(voice)\u{0}\(model)\u{0}\(text)"
        return SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined() + "." + format.rawValue
    }
    func url(for filename: String) throws -> URL {
        guard filename.range(of: "^[a-f0-9]{64}\\.(mp3|caf)$", options: .regularExpression) != nil else {
            throw ReviaError.message(L("invalid_filename"))
        }
        return directory.appendingPathComponent(filename)
    }
    func existing(_ filename: String) -> URL? {
        guard let url = try? url(for: filename), let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber, size.int64Value > 0 else { return nil }
        return url
    }
    func write(_ data: Data, filename: String) throws -> URL {
        guard !data.isEmpty else { throw SpeechFailure.invalidAudio }
        let url = try url(for: filename)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return url
    }
    func remove(_ filename: String) throws {
        let url = try url(for: filename)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
    func bytes() throws -> Int64 {
        try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey])
            .filter { AudioFormat(rawValue: $0.pathExtension) != nil }
            .reduce(0) { total, url in
                let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                return total + (values.isRegularFile == true ? Int64(values.fileSize ?? 0) : 0)
            }
    }
}
