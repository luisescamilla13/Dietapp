import AVFoundation
import Foundation
import Speech
import Testing
@testable import DictationKit

/// Transcribes speech synthesized by `say`, with the real on-device speech model. It
/// runs only where the models are already installed, so it never downloads them in CI.
/// The first dictation in the app downloads them, as does a run of the app on the Mac.
@Suite(.enabled { await speechModelsAreInstalled() })
struct SpeechTranscriberTests {
    @Test(arguments: [
        (DictationLanguage.spanish, "Eddy (Spanish (Mexico))", "dos tacos al pastor y una coca", ["dos", "tacos", "pastor", "coca"]),
        (DictationLanguage.english, "Samantha", "two scrambled eggs and a coffee with milk", ["two", "scrambled", "eggs", "coffee", "milk"]),
    ])
    func transcribesSpeech(language: DictationLanguage, voice: String, phrase: String, keyWords: [String]) async throws {
        let audio = try synthesize(phrase, voice: voice)
        defer { try? FileManager.default.removeItem(at: audio) }

        let transcriber = try await SpeechAnalyzerDictation.transcriber(for: language) {}
        let analyzer = try await SpeechAnalyzer(inputAudioFile: AVAudioFile(forReading: audio), modules: [transcriber], finishAfterFile: true)
        var transcript = Transcript()
        for try await result in transcriber.results {
            transcript.add(String(result.text.characters), isFinal: result.isFinal)
        }
        _ = analyzer

        // A synthesized voice isn't always heard word for word ("del pastor" for "al
        // pastor"), so check the words that matter for finding the foods.
        let heard = Set(normalized(transcript.text))
        #expect(keyWords.allSatisfy(heard.contains), "Heard \"\(transcript.text)\"")
    }

    private func synthesize(_ phrase: String, voice: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).aiff")
        let say = Process()
        say.executableURL = URL(filePath: "/usr/bin/say")
        say.arguments = ["-v", voice, "-o", url.path(), phrase]
        try say.run()
        say.waitUntilExit()
        try #require(say.terminationStatus == 0)
        return url
    }

    /// The words, ignoring case, accents and punctuation.
    private func normalized(_ text: String) -> [String] {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }
}

private func speechModelsAreInstalled() async -> Bool {
    guard SpeechTranscriber.isAvailable else { return false }
    let installed = await SpeechTranscriber.installedLocales.map(\.identifier)
    return installed.contains("es_MX") && installed.contains("en_US")
}
