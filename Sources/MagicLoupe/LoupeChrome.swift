import AppKit

enum LoupeChrome {
    static let cornerRadius: CGFloat = 14
    static let headerHeight: CGFloat = 42
    static let edge: CGFloat = 6
    static let resizePad: CGFloat = 16
    static let resizeBand: CGFloat = 12
    static let resizeCorner: CGFloat = 22
    static let chamfer: CGFloat = 28
    static let chipRadius: CGFloat = 6
    static let frameStrokeWidth: CGFloat = 2
    static let fade: TimeInterval = 0.48
    static var fadeIn: TimeInterval { fade }
    static var fadeOut: TimeInterval { fade }
    static let captureSettle: Duration = .milliseconds(520)

    static var frameStroke: NSColor {
        NSColor(srgbRed: 0.52, green: 0.53, blue: 0.55, alpha: 0.48)
    }

    static var hairline: NSColor {
        NSColor(srgbRed: 0.45, green: 0.46, blue: 0.48, alpha: 0.28)
    }

    static var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    static func fadeTiming(_ phase: FadePhase) -> CAMediaTimingFunction {
        CAMediaTimingFunction(controlPoints: 0.4, 0.0, 0.2, 1.0)
    }

    enum FadePhase {
        case appear
        case disappear
    }
}

extension NSView {
    /// Layer-backed views default to an opaque black backing store; the loupe
    /// hole must stay a true punch-through.
    func punchClearLayer() {
        wantsLayer = true
        layer?.isOpaque = false
        layer?.backgroundColor = NSColor.clear.cgColor
    }
}

enum GlassWeight {
    case chrome
    case obscure
}

/// Frosted plate: Liquid Glass on macOS 26, vibrant material otherwise.
final class GlassBackdrop: NSView {
    let contentView = NSView()
    var cornerRadius: CGFloat = 0 {
        didSet { applyChrome() }
    }
    var tint: NSColor? {
        didSet { applyChrome() }
    }

    private let weight: GlassWeight
    private var plate: NSView?
    private let wash = NSView()

    init(weight: GlassWeight, cornerRadius: CGFloat = 0) {
        self.weight = weight
        self.cornerRadius = cornerRadius
        super.init(frame: .zero)
        punchClearLayer()
        layer?.masksToBounds = true
        contentView.punchClearLayer()
        wash.punchClearLayer()
        wash.autoresizingMask = [.width, .height]
        buildPlate()
        applyChrome()
    }

    override var isOpaque: Bool { false }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyChrome()
    }

    override func layout() {
        super.layout()
        plate?.frame = bounds
        if #available(macOS 26.0, *) {
            wash.frame = contentView.bounds
        } else {
            contentView.frame = bounds
            wash.frame = contentView.bounds
        }
    }

    private func buildPlate() {
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView(frame: bounds)
            glass.autoresizingMask = [.width, .height]
            glass.style = .regular
            glass.cornerRadius = cornerRadius
            glass.contentView = contentView
            addSubview(glass)
            plate = glass
        } else {
            let effect = NSVisualEffectView(frame: bounds)
            effect.autoresizingMask = [.width, .height]
            effect.blendingMode = .behindWindow
            effect.state = .active
            effect.wantsLayer = true
            effect.layer?.masksToBounds = true
            effect.material = weight == .obscure ? .fullScreenUI : .hudWindow
            addSubview(effect)
            plate = effect
            contentView.frame = bounds
            contentView.autoresizingMask = [.width, .height]
            effect.addSubview(contentView)
        }
        contentView.addSubview(wash, positioned: .below, relativeTo: nil)
    }

    private func applyChrome() {
        if #available(macOS 26.0, *) {
            if let glass = plate as? NSGlassEffectView {
                glass.cornerRadius = cornerRadius
                glass.tintColor = tint
            }
            // Liquid Glass picks light/dark from whatever is behind it, not from our
            // appearance. Chips show the sampled color their text was picked for; chrome
            // shows the system background so label colors stay legible over a white page.
            let fill = weight == .obscure
                ? tint?.withAlphaComponent(0.85)
                : NSColor.windowBackgroundColor.withAlphaComponent(0.75)
            effectiveAppearance.performAsCurrentDrawingAppearance {
                wash.layer?.backgroundColor = (fill ?? .clear).cgColor
            }
        } else {
            plate?.layer?.cornerRadius = cornerRadius
            plate?.layer?.cornerCurve = .continuous
            contentView.layer?.cornerRadius = cornerRadius
            if let tint {
                wash.layer?.backgroundColor = tint.withAlphaComponent(weight == .obscure ? 0.32 : 0.12).cgColor
            } else {
                wash.layer?.backgroundColor = NSColor.clear.cgColor
            }
        }
        layer?.cornerRadius = cornerRadius
        layer?.cornerCurve = .continuous
    }
}
