import AppKit
import CoreGraphics
import Foundation
import ScreenCaptureKit

enum CaptureError: LocalizedError, Equatable {
    case screenshotFailed
    case permissionNeeded

    var errorDescription: String? {
        switch self {
        case .screenshotFailed: "Не удалось снять область под лупой"
        case .permissionNeeded: "Нет доступа к записи экрана"
        }
    }
}

enum ScreenGrabber {
    @MainActor
    static func capture(contentRectInWindow: CGRect, window: NSWindow) async throws -> CGImage {
        let cocoaScreen = window.convertToScreen(contentRectInWindow)
        guard cocoaScreen.width >= 8, cocoaScreen.height >= 8 else {
            throw CaptureError.screenshotFailed
        }
        let shotRect = ScreenGrabber.topLeftRect(fromCocoaScreen: cocoaScreen)

        do {
            return try await captureScreenshot(screenRect: shotRect)
        } catch {
            if let image = captureBelowWindow(cocoaScreenRect: cocoaScreen, windowNumber: window.windowNumber) {
                return image
            }
            throw classified(error)
        }
    }

    /// ScreenCaptureKit screenshot rects are in top-left global screen space.
    static func topLeftRect(fromCocoaScreen cocoa: CGRect) -> CGRect {
        let top = NSScreen.screens.map(\.frame.maxY).max() ?? NSScreen.main?.frame.maxY ?? cocoa.maxY
        return CGRect(
            x: cocoa.origin.x,
            y: top - cocoa.maxY,
            width: cocoa.width,
            height: cocoa.height
        )
    }

    private static func captureScreenshot(screenRect: CGRect) async throws -> CGImage {
        guard #available(macOS 26.0, *) else {
            throw CaptureError.screenshotFailed
        }
        let config = SCScreenshotConfiguration()
        config.showsCursor = false
        config.ignoreShadows = true
        config.dynamicRange = .sdr
        let output = try await SCScreenshotManager.captureScreenshot(rect: screenRect, configuration: config)
        if let image = output.sdrImage {
            return image
        }
        throw CaptureError.screenshotFailed
    }

    private static func captureBelowWindow(cocoaScreenRect: CGRect, windowNumber: Int) -> CGImage? {
        let primaryHeight = (NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.main)?.frame.height ?? cocoaScreenRect.height
        let quartz = CGRect(
            x: cocoaScreenRect.origin.x,
            y: primaryHeight - cocoaScreenRect.origin.y - cocoaScreenRect.height,
            width: cocoaScreenRect.width,
            height: cocoaScreenRect.height
        )
        return CGWindowListCreateImage(
            quartz,
            [.optionOnScreenBelowWindow],
            CGWindowID(windowNumber),
            [.bestResolution, .boundsIgnoreFraming]
        )
    }

    private static func classified(_ error: Error) -> Error {
        let ns = error as NSError
        if ns.code == -3801 || ns.domain.lowercased().contains("screencapture") {
            return CaptureError.permissionNeeded
        }
        return error
    }
}
