import AppKit
import CoreGraphics

enum PermissionStatus: Equatable {
    case missing
    case needsRelaunch
    case granted
}

enum AppPermission: String, CaseIterable, Identifiable, Sendable {
    case screenRecording

    var id: String { rawValue }

    var title: String {
        switch self {
        case .screenRecording: "Запись экрана"
        }
    }

    var subtitle: String {
        switch self {
        case .screenRecording:
            "Снимок области под лупой, чтобы распознать и перевести текст. Видео не пишется, кадры не сохраняются."
        }
    }

    var symbol: String {
        switch self {
        case .screenRecording: "rectangle.dashed.badge.record"
        }
    }

    var isRequired: Bool { true }

    var requiresRelaunch: Bool {
        switch self {
        case .screenRecording: true
        }
    }

    @MainActor
    var status: PermissionStatus {
        switch self {
        case .screenRecording:
            let preflight = CGPreflightScreenCaptureAccess()
            if PermissionSession.screenGrantedAtLaunch && preflight {
                return .granted
            }
            if PermissionSession.screenAllowThisSession || preflight {
                return .needsRelaunch
            }
            return .missing
        }
    }

    @MainActor
    var isFullyGranted: Bool { status == .granted }

    @MainActor
    func request() {
        if requiresRelaunch {
            AccessGate.markPendingSystemRelaunch()
        }
        switch self {
        case .screenRecording:
            let allowed = CGRequestScreenCaptureAccess()
            if allowed {
                PermissionSession.markScreenAllowThisSession()
            }
        }
    }

    @MainActor
    func openSystemSettings() {
        switch self {
        case .screenRecording:
            ScreenPermission.openSystemSettings()
        }
    }
}

@MainActor
enum AccessGate {
    static var shouldPresent: Bool {
        if UserDefaults.standard.bool(forKey: Keys.showOnNextLaunch) { return true }
        if !allRequiredFullyGranted { return true }
        if !UserDefaults.standard.bool(forKey: Keys.completed) { return true }
        return false
    }

    static var allRequiredFullyGranted: Bool {
        AppPermission.allCases.filter(\.isRequired).allSatisfy(\.isFullyGranted)
    }

    static func markCompleted() {
        UserDefaults.standard.set(true, forKey: Keys.completed)
        UserDefaults.standard.set(false, forKey: Keys.showOnNextLaunch)
    }

    static func markPendingSystemRelaunch() {
        UserDefaults.standard.set(true, forKey: Keys.showOnNextLaunch)
        UserDefaults.standard.synchronize()
    }

    private enum Keys {
        static let completed = "accessWall.completed"
        static let showOnNextLaunch = "accessWall.showOnNextLaunch"
    }
}

@MainActor
enum PermissionSession {
    private(set) static var screenGrantedAtLaunch = false
    private(set) static var screenAllowThisSession = false
    private static var didStart = false

    static func start() {
        guard !didStart else { return }
        didStart = true
        screenGrantedAtLaunch = CGPreflightScreenCaptureAccess()
    }

    static func markScreenAllowThisSession() {
        screenAllowThisSession = true
    }
}

@MainActor
enum ScreenPermission {
    static var isGranted: Bool {
        AppPermission.screenRecording.isFullyGranted
    }

    static func openSystemSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
        ]
        for raw in candidates {
            if let url = URL(string: raw) {
                NSWorkspace.shared.open(url)
                return
            }
        }
    }

    static func relaunch() {
        let url = Bundle.main.bundleURL
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }
}
