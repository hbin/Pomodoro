import AppKit
import AVFoundation

@MainActor
final class SoundPlayer {
    private let engine = AVAudioEngine()
    private let chimeNode = AVAudioPlayerNode()
    private let tickNode = AVAudioPlayerNode()
    private let sampleRate: Double = 44_100
    private var isConfigured = false
    private var chimeBuffer: AVAudioPCMBuffer?
    private var tickBuffer: AVAudioPCMBuffer?

    init() {
        chimeBuffer = Self.makeChimeBuffer(sampleRate: sampleRate)
        tickBuffer = Self.makeTickBuffer(sampleRate: sampleRate)
    }

    func playChime() {
        configureIfNeeded()
        guard let chimeBuffer else { return }
        chimeNode.stop()
        chimeNode.scheduleBuffer(chimeBuffer, at: nil, options: [], completionHandler: nil)
        chimeNode.play()
    }

    func playTick() {
        configureIfNeeded()
        guard let tickBuffer else { return }
        tickNode.stop()
        tickNode.scheduleBuffer(tickBuffer, at: nil, options: [], completionHandler: nil)
        tickNode.play()
    }

    private func configureIfNeeded() {
        guard !isConfigured else {
            if !engine.isRunning {
                try? engine.start()
            }
            return
        }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            return
        }
        engine.attach(chimeNode)
        engine.attach(tickNode)
        engine.connect(chimeNode, to: engine.mainMixerNode, format: format)
        engine.connect(tickNode, to: engine.mainMixerNode, format: format)
        chimeNode.volume = 0.72
        tickNode.volume = 0.32
        engine.mainMixerNode.outputVolume = 1
        do {
            try engine.start()
            isConfigured = true
        } catch {
            isConfigured = false
        }
    }

    private static func makeChimeBuffer(sampleRate: Double) -> AVAudioPCMBuffer? {
        let duration = 0.98
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(duration * sampleRate)),
              let samples = buffer.floatChannelData?[0] else {
            return nil
        }
        buffer.frameLength = buffer.frameCapacity
        let frameCount = Int(buffer.frameLength)
        let notes: [(start: Double, frequency: Double, duration: Double, gain: Double)] = [
            (0.0, 587.33, 0.58, 0.9),
            (0.26, 880.0, 0.66, 0.8)
        ]

        for index in 0..<frameCount {
            let time = Double(index) / sampleRate
            var value = 0.0
            for note in notes {
                let local = time - note.start
                guard local >= 0, local < note.duration else { continue }
                let attack = min(1.0, local / 0.006)
                let decay = exp(-5.2 * local)
                let release = local > note.duration - 0.06
                    ? max(0, (note.duration - local) / 0.06)
                    : 1.0
                let envelope = attack * decay * release * note.gain
                let phase = 2 * Double.pi * note.frequency * local
                let body = sin(phase)
                    + 0.18 * sin(phase * 2.0 + 0.12)
                    + 0.07 * sin(phase * 3.01 + 0.3)
                    + 0.025 * sin(phase * 4.17)
                value += body * envelope
            }
            samples[index] = Float(value * 0.32)
        }
        return buffer
    }

    private static func makeTickBuffer(sampleRate: Double) -> AVAudioPCMBuffer? {
        let duration = 0.055
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(duration * sampleRate)),
              let samples = buffer.floatChannelData?[0] else {
            return nil
        }
        buffer.frameLength = buffer.frameCapacity
        let frameCount = Int(buffer.frameLength)
        var generator = SystemRandomNumberGenerator()

        for index in 0..<frameCount {
            let time = Double(index) / sampleRate
            let envelope = exp(-78 * time)
            let tone = sin(2 * Double.pi * 1_650 * time) * 0.6
            let overtone = sin(2 * Double.pi * 2_450 * time) * 0.25
            let noise = Double.random(in: -1...1, using: &generator) * 0.18
            samples[index] = Float((tone + overtone + noise) * envelope * 0.20)
        }
        return buffer
    }
}
