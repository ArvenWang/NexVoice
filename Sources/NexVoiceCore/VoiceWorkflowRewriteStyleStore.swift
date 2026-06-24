import Foundation

public final class VoiceWorkflowRewriteStyleStore {
    private let defaults: UserDefaults
    private let key: String

    public init(
        defaults: UserDefaults = .standard,
        key: String = "workflowRewriteStyles"
    ) {
        self.defaults = defaults
        self.key = key
    }

    public func style(for workflowIdentifier: String, defaultStyle: VoiceRewriteStyle) -> VoiceRewriteStyle {
        guard let rawValue = rawStyles()[workflowIdentifier],
              let style = VoiceRewriteStyle(rawValue: rawValue) else {
            return defaultStyle
        }
        return style
    }

    public func save(_ style: VoiceRewriteStyle, for workflowIdentifier: String) {
        var styles = rawStyles()
        styles[workflowIdentifier] = style.rawValue
        defaults.set(styles, forKey: key)
    }

    public func reset() {
        defaults.removeObject(forKey: key)
    }

    private func rawStyles() -> [String: String] {
        defaults.dictionary(forKey: key) as? [String: String] ?? [:]
    }
}
