import Foundation

public struct VoiceAudioLevelSmoother: Equatable, Sendable {
    public let openThreshold: Double
    public let closeThreshold: Double
    public let attackRate: Double
    public let releaseRate: Double
    public let quietFramesToClose: Int

    private var isOpen = false
    private var quietFrameCount = 0
    private var displayedLevel = 0.0

    public init(
        openThreshold: Double = 0.22,
        closeThreshold: Double = 0.10,
        attackRate: Double = 0.55,
        releaseRate: Double = 0.68,
        quietFramesToClose: Int = 3
    ) {
        self.openThreshold = openThreshold
        self.closeThreshold = closeThreshold
        self.attackRate = attackRate
        self.releaseRate = releaseRate
        self.quietFramesToClose = quietFramesToClose
    }

    public mutating func process(rawLevel: Double) -> Double {
        let level = clamp(rawLevel)
        if !isOpen {
            guard level >= openThreshold else {
                displayedLevel = 0
                quietFrameCount = 0
                return 0
            }
            isOpen = true
        }

        if level < closeThreshold {
            quietFrameCount += 1
        } else {
            quietFrameCount = 0
        }

        if quietFrameCount >= quietFramesToClose {
            reset()
            return 0
        }

        let targetLevel = level >= closeThreshold ? level : 0
        if targetLevel > displayedLevel {
            displayedLevel += (targetLevel - displayedLevel) * attackRate
        } else {
            displayedLevel *= releaseRate
        }
        return clamp(displayedLevel)
    }

    public mutating func reset() {
        isOpen = false
        quietFrameCount = 0
        displayedLevel = 0
    }

    private func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
