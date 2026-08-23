import AppKit
import QuartzCore

enum LensPalette {
    static let quartz = NSColor(srgbRed: 0.37, green: 0.92, blue: 0.84, alpha: 1)
    static let flare = NSColor(srgbRed: 0.91, green: 0.48, blue: 0.98, alpha: 1)
    static let chip = NSColor(srgbRed: 0.12, green: 0.14, blue: 0.18, alpha: 0.72)
    static let hair = NSColor.white.withAlphaComponent(0.22)

    static var wordmark: NSColor { quartz }
}

final class LensFrame: NSView {
    var cornerRadius: CGFloat = 8

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        guard rect.width > 8, rect.height > 8 else { return }
        let radius = max(0, cornerRadius - 0.5)

        let outer = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        outer.lineWidth = 1
        LensPalette.flare.withAlphaComponent(0.55).setStroke()
        outer.stroke()

        let inner = NSBezierPath(
            roundedRect: rect.insetBy(dx: 1, dy: 1),
            xRadius: max(0, radius - 1),
            yRadius: max(0, radius - 1)
        )
        inner.lineWidth = 1
        LensPalette.quartz.withAlphaComponent(0.7).setStroke()
        inner.stroke()
    }
}

final class PixelMarqueeView: NSView {
    private let beam = CAGradientLayer()
    private var running = false

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        punchClearLayer()
        layer?.masksToBounds = true
        layer?.cornerRadius = 2
        beam.colors = [
            LensPalette.quartz.withAlphaComponent(0).cgColor,
            LensPalette.quartz.withAlphaComponent(0.85).cgColor,
            LensPalette.flare.withAlphaComponent(0.55).cgColor,
            LensPalette.quartz.withAlphaComponent(0).cgColor,
        ]
        beam.startPoint = CGPoint(x: 0, y: 0.5)
        beam.endPoint = CGPoint(x: 1, y: 0.5)
        layer?.addSublayer(beam)
        alphaValue = 0
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        beam.frame = bounds
        if running { attach() }
    }

    func setActive(_ on: Bool) {
        if LoupeChrome.reduceMotion {
            running = false
            beam.removeAllAnimations()
            isHidden = true
            alphaValue = 0
            return
        }
        if on {
            running = true
            isHidden = false
            layout()
            attach()
            animator().alphaValue = 1
            return
        }
        running = false
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self, !self.running else { return }
                self.beam.removeAllAnimations()
                self.isHidden = true
            }
        })
    }

    private func attach() {
        beam.removeAnimation(forKey: "sweep")
        let anim = CABasicAnimation(keyPath: "locations")
        anim.fromValue = [-0.3, -0.1, 0.0, 0.2] as [NSNumber]
        anim.toValue = [0.8, 1.0, 1.1, 1.3] as [NSNumber]
        anim.duration = 1.35
        anim.repeatCount = .infinity
        anim.timingFunction = CAMediaTimingFunction(name: .linear)
        anim.isRemovedOnCompletion = false
        beam.add(anim, forKey: "sweep")
    }
}

final class SkinButton: FirstMouseButton {}
