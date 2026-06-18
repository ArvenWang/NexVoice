import AVFoundation
import AppKit
import Foundation

public enum MicrophoneAuthorizationStatus: Equatable {
    case authorized
    case denied
    case notDetermined
    case restricted
    case unknown
}

public final class MicrophonePermissionService {
    public init() {}

    public func authorizationStatus() -> MicrophoneAuthorizationStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        @unknown default:
            return .unknown
        }
    }

    public func requestAccess(completion: @escaping @Sendable (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio, completionHandler: completion)
    }

    @discardableResult
    public func openMicrophonePrivacySettings() -> Bool {
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Microphone"
        ]
        for candidate in candidates {
            guard let url = URL(string: candidate), NSWorkspaceBridge.open(url) else { continue }
            return true
        }
        return false
    }
}

private enum NSWorkspaceBridge {
    static func open(_ url: URL) -> Bool {
        #if os(macOS)
        return NSWorkspace.shared.open(url)
        #else
        return false
        #endif
    }
}
