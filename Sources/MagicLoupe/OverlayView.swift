import AppKit

final class OverlayView: NSView {
    private var chips: [Int: OverlayBlockView] = [:]
    private var presented: [OverlayBlock] = []
    private var locked = true
    private var script: ScriptKind = .latin
    private var skin: LoupeSkin = .glass
    private let shimmer = TranslationShimmerView()

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        punchClearLayer()
        addSubview(shimmer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        shimmer.frame = bounds
    }

    func applySkin(_ skin: LoupeSkin) {
        self.skin = skin
        shimmer.applySkin(skin)
        for chip in chips.values {
            chip.skin = skin
        }
        for block in presented {
            chips[block.id]?.configure(block, script: script, locked: locked)
        }
    }

    func setBusy(_ busy: Bool) {
        shimmer.setActive(busy && skin == .glass)
    }

    func apply(
        _ blocks: [OverlayBlock],
        script: ScriptKind,
        locked: Bool,
        animated: Bool
    ) {
        self.script = script
        self.locked = locked
        let motion = animated && !LoupeChrome.reduceMotion
        let duration = motion ? LoupeChrome.fade : 0

        if blocks == presented {
            for block in blocks {
                chips[block.id]?.configure(block, script: script, locked: locked)
            }
            return
        }

        var leftover = chips
        var next: [Int: OverlayBlockView] = [:]

        for block in blocks {
            if let chip = leftover.removeValue(forKey: block.id) {
                chip.configure(block, script: script, locked: locked)
                next[block.id] = chip
                continue
            }
            let chip = OverlayBlockView()
            chip.skin = skin
            chip.alphaValue = 0
            chip.configure(block, script: script, locked: locked)
            addSubview(chip)
            next[block.id] = chip
            fade(chip, to: 1, duration: duration, phase: .appear)
        }

        for (_, chip) in leftover {
            fade(chip, to: 0, duration: duration, phase: .disappear) {
                chip.removeFromSuperview()
            }
        }

        chips = next
        presented = blocks
        addSubview(shimmer, positioned: .below, relativeTo: nil)
    }

    func updateLock(_ locked: Bool, script: ScriptKind) {
        self.locked = locked
        self.script = script
        for block in presented {
            chips[block.id]?.configure(block, script: script, locked: locked)
        }
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        let item = NSMenuItem(title: "Скопировать перевод", action: #selector(copyTranslation), keyEquivalent: "c")
        item.target = self
        menu.addItem(item)
        return menu
    }

    @objc private func copyTranslation() {
        let text = presented.map(\.translatedText).joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func fade(
        _ view: NSView,
        to alpha: CGFloat,
        duration: TimeInterval,
        phase: LoupeChrome.FadePhase,
        completion: (() -> Void)? = nil
    ) {
        if duration <= 0.001 {
            view.alphaValue = alpha
            completion?()
            return
        }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = LoupeChrome.fadeTiming(phase)
            context.allowsImplicitAnimation = true
            view.animator().alphaValue = alpha
        }, completionHandler: {
            completion?()
        })
    }
}

final class OverlayBlockView: NSView {
    var skin: LoupeSkin = .glass
    private let plate = GlassBackdrop(weight: .obscure, cornerRadius: LoupeChrome.chipRadius)
    private let field = NSTextField()

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }

    init() {
        super.init(frame: .zero)
        punchClearLayer()
        plate.translatesAutoresizingMaskIntoConstraints = false
        addSubview(plate)
        NSLayoutConstraint.activate([
            plate.topAnchor.constraint(equalTo: topAnchor),
            plate.leadingAnchor.constraint(equalTo: leadingAnchor),
            plate.trailingAnchor.constraint(equalTo: trailingAnchor),
            plate.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.backgroundColor = .clear
        field.isEditable = false
        field.usesSingleLineMode = false
        field.cell?.wraps = true
        field.cell?.isScrollable = false
        field.lineBreakMode = .byWordWrapping
        field.translatesAutoresizingMaskIntoConstraints = false
        addSubview(field)
        NSLayoutConstraint.activate([
            field.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            field.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            field.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            field.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func configure(_ block: OverlayBlock, script: ScriptKind, locked: Bool) {
        frame = block.rect.insetBy(dx: -2, dy: -1).integral
        plate.isHidden = false
        plate.cornerRadius = min(skin.chipRadius, max(4, bounds.height * 0.22))
        plate.tint = block.background.nsColor
        if block.background.luma > 0.55 {
            appearance = NSAppearance(named: .vibrantLight)
        } else {
            appearance = NSAppearance(named: .vibrantDark)
        }
        field.font = skin == .colorLens
            ? PixelFont.overlay(size: block.fontSize, script: script)
            : block.family.nsFont(size: block.fontSize, script: script)
        field.stringValue = block.translatedText
        field.textColor = block.foreground.nsColor
        field.isSelectable = locked
        field.toolTip = locked ? block.sourceText : nil
    }
}

/// Diagonal gleam that rolls across the loupe while translation is in flight.
final class TranslationShimmerView: NSView {
    private let wash = CALayer()
    private let gleam = CAGradientLayer()
    private let emitter = CAEmitterLayer()
    private var running = false
    private var lastSize: CGSize = .zero

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        punchClearLayer()
        layer?.masksToBounds = true
        wash.backgroundColor = NSColor.white.withAlphaComponent(0.04).cgColor
        layer?.addSublayer(wash)

        gleam.colors = [
            NSColor.white.withAlphaComponent(0).cgColor,
            NSColor.white.withAlphaComponent(0.04).cgColor,
            NSColor.white.withAlphaComponent(0.20).cgColor,
            NSColor.white.withAlphaComponent(0.04).cgColor,
            NSColor.white.withAlphaComponent(0).cgColor,
        ]
        gleam.locations = [0, 0.08, 0.16, 0.24, 0.32]
        gleam.startPoint = CGPoint(x: 0, y: 0)
        gleam.endPoint = CGPoint(x: 1, y: 1)
        layer?.addSublayer(gleam)

        emitter.emitterShape = .point
        emitter.emitterMode = .points
        emitter.renderMode = .additive
        emitter.birthRate = 0
        emitter.emitterCells = [Self.dustCell, Self.twinkleCell]
        layer?.addSublayer(emitter)

        alphaValue = 0
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        wash.backgroundColor = NSColor.white.withAlphaComponent(dark ? 0.04 : 0.055).cgColor
    }

    override func layout() {
        super.layout()
        wash.frame = bounds
        layoutSweep()
        let grown = abs(bounds.width - lastSize.width) > 8 || abs(bounds.height - lastSize.height) > 8
        lastSize = bounds.size
        if running, grown {
            attachAnimation()
        }
    }

    func applySkin(_ skin: LoupeSkin) {
        wash.isHidden = skin != .glass
        gleam.isHidden = skin != .glass
        emitter.isHidden = skin != .glass
        if skin != .glass {
            setActive(false)
        }
    }

    func setActive(_ on: Bool) {
        if LoupeChrome.reduceMotion {
            running = false
            stopSweep()
            isHidden = true
            alphaValue = 0
            return
        }
        if on {
            guard !running else { return }
            running = true
            isHidden = false
            layout()
            attachAnimation()
            emitter.birthRate = 1
            NSAnimationContext.runAnimationGroup { context in
                context.duration = LoupeChrome.fade
                context.timingFunction = LoupeChrome.fadeTiming(.appear)
                animator().alphaValue = 1
            }
            return
        }
        guard running || alphaValue > 0.01 else { return }
        running = false
        emitter.birthRate = 0
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = LoupeChrome.fade
            context.timingFunction = LoupeChrome.fadeTiming(.disappear)
            animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self, !self.running else { return }
                self.stopSweep()
                self.isHidden = true
            }
        })
    }

    private func layoutSweep() {
        gleam.transform = CATransform3DIdentity
        gleam.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        gleam.frame = bounds.insetBy(dx: -gleamPad, dy: -gleamPad)
        gleam.startPoint = CGPoint(x: 0, y: 0)
        gleam.endPoint = CGPoint(x: 1, y: 1)

        emitter.transform = CATransform3DIdentity
        emitter.bounds = CGRect(x: 0, y: 0, width: 8, height: 8)
        emitter.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        emitter.emitterSize = .zero
        emitter.emitterPosition = CGPoint(x: 4, y: 4)
        emitter.position = particleStart
    }

    /// Extra space so the gradient's rectangle never meets the clip; the band
    /// lives in that margin at both ends of the loop.
    private var gleamPad: CGFloat {
        max(hypot(bounds.width, bounds.height), 1)
    }

    private var particleStart: CGPoint {
        CGPoint(x: -bounds.width * 0.35, y: -bounds.height * 0.35)
    }

    private var particleEnd: CGPoint {
        CGPoint(x: bounds.width * 1.35, y: bounds.height * 1.35)
    }

    private func bandLocations(center: CGFloat, span: CGFloat) -> [NSNumber] {
        let half = span / 2
        return [center - half, center - half / 2, center, center + half / 2, center + half]
            .map { NSNumber(value: Double($0)) }
    }

    /// Narrow band parked past both clipped corners (locations stay in 0...1;
    /// Core Animation otherwise clamps and the gleam collapses into an edge).
    private func bandTravel() -> (from: [NSNumber], to: [NSNumber]) {
        let pad = gleamPad
        let gw = max(bounds.width + 2 * pad, 1)
        let gh = max(bounds.height + 2 * pad, 1)
        let span = max(hypot(bounds.width, bounds.height) * 0.13, 28) / hypot(gw, gh)
        let fromCenter = span / 2 + 0.02
        let toCenter = 1 - span / 2 - 0.02
        return (bandLocations(center: fromCenter, span: span), bandLocations(center: toCenter, span: span))
    }

    private func attachAnimation() {
        gleam.removeAnimation(forKey: "roll")
        emitter.removeAnimation(forKey: "roll")

        let travel = bandTravel()
        let band = CABasicAnimation(keyPath: "locations")
        band.fromValue = travel.from
        band.toValue = travel.to
        band.duration = 2.15
        band.repeatCount = .infinity
        band.timingFunction = CAMediaTimingFunction(name: .linear)
        band.isRemovedOnCompletion = false
        gleam.locations = travel.from
        gleam.add(band, forKey: "roll")

        let drift = CABasicAnimation(keyPath: "position")
        drift.fromValue = NSValue(point: particleStart)
        drift.toValue = NSValue(point: particleEnd)
        drift.duration = 2.15
        drift.repeatCount = .infinity
        drift.timingFunction = CAMediaTimingFunction(name: .linear)
        drift.isRemovedOnCompletion = false
        emitter.position = particleStart
        emitter.add(drift, forKey: "roll")
    }

    private func stopSweep() {
        gleam.removeAllAnimations()
        emitter.removeAllAnimations()
        emitter.birthRate = 0
    }

    private static let sparkleImage: CGImage? = {
        let side = 16
        let space = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: side * 4,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        let colors = [NSColor.white.cgColor, NSColor.white.withAlphaComponent(0).cgColor] as CFArray
        let locations: [CGFloat] = [0, 1]
        guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: locations) else { return nil }
        let center = CGPoint(x: CGFloat(side) / 2, y: CGFloat(side) / 2)
        ctx.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: CGFloat(side) / 2,
            options: []
        )
        return ctx.makeImage()
    }()

    private static var dustCell: CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = sparkleImage
        cell.birthRate = 14
        cell.lifetime = 1.15
        cell.lifetimeRange = 0.35
        cell.velocity = 18
        cell.velocityRange = 14
        cell.emissionLongitude = .pi / 4
        cell.emissionRange = .pi / 7
        cell.scale = 0.07
        cell.scaleRange = 0.05
        cell.alphaSpeed = -0.55
        cell.color = NSColor.white.withAlphaComponent(0.55).cgColor
        return cell
    }

    private static var twinkleCell: CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = sparkleImage
        cell.birthRate = 5
        cell.lifetime = 0.7
        cell.lifetimeRange = 0.2
        cell.velocity = 8
        cell.velocityRange = 10
        cell.emissionRange = .pi
        cell.scale = 0.13
        cell.scaleRange = 0.08
        cell.alphaSpeed = -0.9
        cell.color = NSColor.white.withAlphaComponent(0.85).cgColor
        return cell
    }
}
