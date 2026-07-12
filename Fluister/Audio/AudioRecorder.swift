import Foundation
import AVFoundation

// U4 — microfoon-opname naar 16 kHz mono Float (het formaat dat WhisperKit wil).
//
// Twee lagen:
//  1. RecordingBuffer — pure accumulator met max-duur begrenzing, testbaar.
//  2. AudioRecorder — AVAudioEngine-tap + AVAudioConverter naar 16k mono.
//     Deze laag raakt de echte mic en wordt handmatig geverifieerd (testopname).

enum AudioFormatSpec {
    static let sampleRate: Double = 16_000
    static let channelCount: AVAudioChannelCount = 1
}

/// Naad voor de orkestratie (U7), zodat DictationController met een fake test.
protocol AudioRecording: AnyObject {
    func start() throws
    func stop() -> [Float]
}

/// Pure sample-accumulator met begrenzing op een maximale duur.
final class RecordingBuffer {
    private(set) var samples: [Float] = []
    let maxSamples: Int
    private(set) var didHitLimit = false

    init(maxSeconds: Double = 60, sampleRate: Double = AudioFormatSpec.sampleRate) {
        self.maxSamples = Int(maxSeconds * sampleRate)
    }

    /// Voegt samples toe tot de limiet. Retourneert false zodra de limiet is bereikt.
    @discardableResult
    func append(_ new: [Float]) -> Bool {
        guard !didHitLimit else { return false }
        let room = maxSamples - samples.count
        if new.count >= room {
            samples.append(contentsOf: new.prefix(room))
            didHitLimit = true
            return false
        }
        samples.append(contentsOf: new)
        return true
    }

    func reset() {
        samples.removeAll(keepingCapacity: true)
        didHitLimit = false
    }

    var duration: Double { Double(samples.count) / AudioFormatSpec.sampleRate }
    var isEmpty: Bool { samples.isEmpty }
}

final class AudioRecorder: ObservableObject, AudioRecording {
    @Published private(set) var isRecording = false
    @Published private(set) var lastCaptureSummary: String?

    /// Wordt aangeroepen (op main) als de max-duur is bereikt.
    var onLimitReached: (() -> Void)?

    private let engine = AVAudioEngine()
    private let buffer: RecordingBuffer
    private let targetFormat: AVAudioFormat

    init(maxSeconds: Double = 60) {
        self.buffer = RecordingBuffer(maxSeconds: maxSeconds)
        self.targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: AudioFormatSpec.sampleRate,
            channels: AudioFormatSpec.channelCount,
            interleaved: false
        )!
    }

    func start() throws {
        guard !isRecording else { return }
        buffer.reset()

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        let converter = AVAudioConverter(from: inputFormat, to: targetFormat)

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] pcm, _ in
            self?.process(pcm, converter: converter)
        }
        engine.prepare()
        try engine.start()
        isRecording = true
    }

    /// Stopt en retourneert de opgenomen 16k-mono samples.
    @discardableResult
    func stop() -> [Float] {
        guard isRecording else { return buffer.samples }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
        return buffer.samples
    }

    /// Neemt N seconden op en retourneert de 16k-mono samples (async).
    func record(seconds: Double) async -> [Float] {
        do {
            try start()
        } catch {
            return []
        }
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        return stop()
    }

    /// Neemt N seconden op en publiceert een korte samenvatting (handmatige verificatie).
    func testCapture(seconds: Double = 2) {
        do {
            try start()
        } catch {
            lastCaptureSummary = "Fout: \(error.localizedDescription)"
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            guard let self else { return }
            let s = self.stop()
            let dur = Double(s.count) / AudioFormatSpec.sampleRate
            self.lastCaptureSummary = String(format: "Opgenomen: %.1fs, %d samples @16kHz", dur, s.count)
        }
    }

    private func process(_ pcm: AVAudioPCMBuffer, converter: AVAudioConverter?) {
        guard let converter else { return }
        let ratio = targetFormat.sampleRate / pcm.format.sampleRate
        let capacity = AVAudioFrameCount(Double(pcm.frameLength) * ratio) + 16
        guard let out = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

        var supplied = false
        var error: NSError?
        let status = converter.convert(to: out, error: &error) { _, outStatus in
            if supplied {
                outStatus.pointee = .noDataNow
                return nil
            }
            supplied = true
            outStatus.pointee = .haveData
            return pcm
        }

        guard status != .error, let channel = out.floatChannelData else { return }
        let count = Int(out.frameLength)
        let floats = Array(UnsafeBufferPointer(start: channel[0], count: count))

        if !buffer.append(floats) {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isRecording else { return }
                self.stop()
                self.onLimitReached?()
            }
        }
    }
}
