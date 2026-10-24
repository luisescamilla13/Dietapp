import AVFoundation
import Speech
import Synchronization

/// Transcribes the microphone on the device with `SpeechAnalyzer`. No audio leaves the device.
public struct SpeechAnalyzerDictation: Dictating {
    public init() {}

    public func dictate(in language: DictationLanguage) -> AsyncThrowingStream<DictationEvent, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard await AVAudioApplication.requestRecordPermission() else {
                        throw DictationError.microphoneDenied
                    }
                    let transcriber = try await Self.transcriber(for: language) {
                        continuation.yield(.downloadingLanguage)
                    }
                    try await Self.listen(with: transcriber, continuation: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// A transcriber for `language` whose speech model is on the device, downloading it if needed.
    static func transcriber(for language: DictationLanguage, onDownload: () -> Void) async throws -> SpeechTranscriber {
        guard SpeechTranscriber.isAvailable else { throw DictationError.unavailable }
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: language.locale()) else {
            throw DictationError.unsupportedLanguage
        }
        // Progressive results update while the user speaks instead of after each pause.
        let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            onDownload()
            try await request.downloadAndInstall()
        }
        return transcriber
    }

    /// Streams the microphone into the analyzer until the task is cancelled.
    private static func listen(
        with transcriber: SpeechTranscriber,
        continuation: AsyncThrowingStream<DictationEvent, any Error>.Continuation
    ) async throws {
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw DictationError.unavailable
        }
        try await analyzer.prepareToAnalyze(in: format)

        let (input, inputContinuation) = AsyncStream.makeStream(of: AnalyzerInput.self)
        let microphone = try Microphone(convertingTo: format) { buffer in
            inputContinuation.yield(AnalyzerInput(buffer: buffer))
        }
        defer { microphone.stop() }
        try await analyzer.start(inputSequence: input)
        try microphone.start()
        continuation.yield(.listening)

        // The results never end on their own while the microphone is on, so cancelling
        // the task stops the analyzer, which ends them.
        try await withTaskCancellationHandler {
            var transcript = Transcript()
            for try await result in transcriber.results {
                transcript.add(String(result.text.characters), isFinal: result.isFinal)
                continuation.yield(.transcript(transcript.text))
            }
        } onCancel: {
            inputContinuation.finish()
            Task { await analyzer.cancelAndFinishNow() }
        }
    }
}

/// Captures microphone audio and converts it to the format the analyzer wants.
private final class Microphone {
    private let engine = AVAudioEngine()

    init(convertingTo format: AVAudioFormat, onBuffer: @escaping @Sendable (AVAudioPCMBuffer) -> Void) throws {
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        // The simulator and Macs without a microphone report an empty format.
        guard inputFormat.sampleRate > 0, let converter = BufferConverter(from: inputFormat, to: format) else {
            throw DictationError.unavailable
        }
        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
            if let converted = converter.convert(buffer) {
                onBuffer(converted)
            }
        }
    }

    func start() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        #endif
        engine.prepare()
        try engine.start()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }
}

/// Converts buffers on the audio thread. The mutex makes sharing the converter safe.
private final class BufferConverter: Sendable {
    private let converter: Mutex<AVAudioConverter>
    private let outputFormat: AVAudioFormat

    init?(from inputFormat: AVAudioFormat, to outputFormat: AVAudioFormat) {
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else { return nil }
        // Without priming the output keeps the input's timing, which the analyzer expects.
        converter.primeMethod = .none
        self.converter = Mutex(converter)
        self.outputFormat = outputFormat
    }

    func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up))
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { return nil }
        let isConverted = converter.withLock { converter in
            var error: NSError?
            var isConsumed = false
            converter.convert(to: output, error: &error) { _, status in
                if isConsumed {
                    status.pointee = .noDataNow
                    return nil
                }
                isConsumed = true
                status.pointee = .haveData
                return buffer
            }
            return error == nil
        }
        return isConverted ? output : nil
    }
}
