import AppKit
import Foundation

enum LoupeSkin: String, CaseIterable, Identifiable, Sendable {
    case glass
    case colorLens

    var id: String { rawValue }

    var title: String {
        switch self {
        case .glass: "Стекло"
        case .colorLens: "Color Lens"
        }
    }

    var detail: String {
        switch self {
        case .glass:
            "Текущий хром: стекло, скругления, мягкая тень."
        case .colorLens:
            "New-retro: стекло macOS, пиксельный акцент и призменная рамка. Не Windows 95."
        }
    }

    var headerHeight: CGFloat { 42 }

    var titleBarHeight: CGFloat { 0 }

    var cornerRadius: CGFloat {
        switch self {
        case .glass: 14
        case .colorLens: 8
        }
    }

    var chipRadius: CGFloat {
        switch self {
        case .glass: 6
        case .colorLens: 4
        }
    }

    var edge: CGFloat { 6 }

    var bottomEdge: CGFloat { 6 }

    var chamfer: CGFloat {
        switch self {
        case .glass: 28
        case .colorLens: 22
        }
    }

    var frameStrokeWidth: CGFloat {
        switch self {
        case .glass: 2
        case .colorLens: 0
        }
    }

    var minSize: NSSize { NSSize(width: 312, height: 172) }
}
