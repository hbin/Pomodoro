import AVFoundation
import Foundation

final class SoundPlayer: @unchecked Sendable {
    private let queue = DispatchQueue(
        label: "com.hb.pomodoro.sound",
        qos: .userInitiated
    )
    private let chimeData: Data
    private let tickData: Data
    private var activePlayers: [AVAudioPlayer] = []

    init() {
        chimeData = Self.makeChimeData(sampleRate: 44_100)
        tickData = Self.makeTickData(sampleRate: 44_100)
    }

    func playChime() {
        play(chimeData, volume: 0.72)
    }

    func playTick() {
        play(tickData, volume: 0.32)
    }

    private func play(_ data: Data, volume: Float) {
        queue.async { [weak self] in
            guard let self,
                  let player = try? AVAudioPlayer(data: data) else {
                return
            }
            player.volume = volume
            player.prepareToPlay()
            guard player.play() else { return }
            activePlayers.append(player)
            if activePlayers.count > 4 {
                activePlayers.removeFirst(activePlayers.count - 4)
            }
            queue.asyncAfter(deadline: .now() + player.duration + 0.1) { [weak self, weak player] in
                guard let self, let player else { return }
                activePlayers.removeAll { $0 === player }
            }
        }
    }

    private static func makeChimeData(sampleRate: Double) -> Data {
        let duration = 0.98
        let frameCount = Int(duration * sampleRate)
        var samples = [Float](repeating: 0, count: frameCount)
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
        return makeWAVData(samples: samples, sampleRate: Int(sampleRate))
    }

    private static func makeTickData(sampleRate: Double) -> Data {
        let duration = 0.055
        let frameCount = Int(duration * sampleRate)
        var samples = [Float](repeating: 0, count: frameCount)
        var generator = SystemRandomNumberGenerator()

        for index in 0..<frameCount {
            let time = Double(index) / sampleRate
            let envelope = exp(-78 * time)
            let tone = sin(2 * Double.pi * 1_650 * time) * 0.6
            let overtone = sin(2 * Double.pi * 2_450 * time) * 0.25
            let noise = Double.random(in: -1...1, using: &generator) * 0.18
            samples[index] = Float((tone + overtone + noise) * envelope * 0.20)
        }
        return makeWAVData(samples: samples, sampleRate: Int(sampleRate))
    }

    private static func makeWAVData(samples: [Float], sampleRate: Int) -> Data {
        let bytesPerSample = 2
        let dataSize = samples.count * bytesPerSample
        var data = Data(capacity: 44 + dataSize)

        data.append(contentsOf: Array("RIFF".utf8))
        appendLE(UInt32(36 + dataSize), to: &data)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        appendLE(UInt32(16), to: &data)
        appendLE(UInt16(1), to: &data)
        appendLE(UInt16(1), to: &data)
        appendLE(UInt32(sampleRate), to: &data)
        appendLE(UInt32(sampleRate * bytesPerSample), to: &data)
        appendLE(UInt16(bytesPerSample), to: &data)
        appendLE(UInt16(16), to: &data)
        data.append(contentsOf: Array("data".utf8))
        appendLE(UInt32(dataSize), to: &data)

        for sample in samples {
            let clamped = min(max(sample, -1), 1)
            let value = Int16((clamped * Float(Int16.max)).rounded())
            appendLE(UInt16(bitPattern: value), to: &data)
        }

        return data
    }

    private static func appendLE(_ value: UInt16, to data: inout Data) {
        var value = value.littleEndian
        withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
    }

    private static func appendLE(_ value: UInt32, to data: inout Data) {
        var value = value.littleEndian
        withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
    }
}
