import Foundation

public enum SenseVoiceTranscriptionOutput {
    public enum Error: Swift.Error, Equatable, Sendable {
        case invalidJSON
    }

    private struct Payload: Decodable {
        let text: String
    }

    public static func transcribedText(from output: Data) throws -> String {
        do {
            let payload = try JSONDecoder().decode(Payload.self, from: output)
            return payload.text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            throw Error.invalidJSON
        }
    }
}
