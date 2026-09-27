import AVFoundation

enum ChiptuneCue: CaseIterable, Sendable {
    case correctAnswer
    case wrongAnswer
    case criticalHit
    case badgeEarned
    case whiteout
    case menuSelect
}

struct ChiptuneEffect: Equatable, Sendable {
    let frequency: Double
    let frames: Int
}

enum ChiptuneCatalog {
    static let sampleRate: Double = 44_100

    static let effects: [ChiptuneCue: ChiptuneEffect] = [
        .correctAnswer: ChiptuneEffect(frequency: 880, frames: 5_292),
        .wrongAnswer: ChiptuneEffect(frequency: 220, frames: 7_938),
        .criticalHit: ChiptuneEffect(frequency: 1_320, frames: 8_820),
        .badgeEarned: ChiptuneEffect(frequency: 660, frames: 17_640),
        .whiteout: ChiptuneEffect(frequency: 110, frames: 19_845),
        .menuSelect: ChiptuneEffect(frequency: 440, frames: 3_528)
    ]

    static func effect(for cue: ChiptuneCue) -> ChiptuneEffect {
        effects[cue]!
    }
}

final class Chiptune {
    private let engine = AVAudioEngine()
    private var isEnabled: Bool

    init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    func play(_ cue: ChiptuneCue) {
        guard isEnabled else { return }
        let effect = ChiptuneCatalog.effect(for: cue)
        let node = squareWaveNode(for: effect)
        let format = AVAudioFormat(standardFormatWithSampleRate: ChiptuneCatalog.sampleRate, channels: 1)!
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        try? engine.start()
        schedulesStop(of: node, afterFrames: effect.frames)
    }

    private func squareWaveNode(for effect: ChiptuneEffect) -> AVAudioSourceNode {
        var frameIndex = 0
        let sampleRate = ChiptuneCatalog.sampleRate
        let frequency = effect.frequency
        let totalFrames = effect.frames
        return AVAudioSourceNode { _, _, frameCount, audioBufferList in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                let sample = squareWaveSample(frameIndex: frameIndex, totalFrames: totalFrames,
                                              frequency: frequency, sampleRate: sampleRate)
                for buffer in buffers {
                    let channel = UnsafeMutableBufferPointer<Float>(buffer)
                    channel[frame] = sample
                }
                frameIndex += 1
            }
            return noErr
        }
    }

    private func schedulesStop(of node: AVAudioSourceNode, afterFrames frames: Int) {
        let seconds = Double(frames) / ChiptuneCatalog.sampleRate
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds + 0.05) { [weak self] in
            self?.engine.stop()
            self?.engine.detach(node)
        }
    }
}

private func squareWaveSample(frameIndex: Int, totalFrames: Int, frequency: Double, sampleRate: Double) -> Float {
    guard frameIndex < totalFrames else { return 0 }
    let phase = (frequency * Double(frameIndex) / sampleRate).truncatingRemainder(dividingBy: 1)
    return phase < 0.5 ? 0.2 : -0.2
}
