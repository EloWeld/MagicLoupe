import AppKit

enum ResizeEdge: Sendable {
    case n, s, e, w, ne, nw, se, sw, none
}

private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }
}

final class LoupeRootView: NSView {
    let headerHost: NSView
    let overlayView: OverlayView
    var isLocked: () -> Bool = { true }
    var onFrameChange: (() -> Void)?

    private var skin: LoupeSkin = .glass
    private var headerHeight: CGFloat { skin.headerHeight }
    private var edge: CGFloat { skin.edge }
    private var cornerRadius: CGFloat { skin.cornerRadius }
    private let pad = LoupeChrome.resizePad
    private let shadowHost = NSView()
    private let plate = FlippedView()
    private let frameView = LensFrame()
    private let hairline = NSView()
    private let chamfer = ResizeChamferView()

    private var chromeRect: CGRect {
        bounds.insetBy(dx: pad, dy: pad)
    }

    init(headerHost: NSView, overlayView: OverlayView) {
        self.headerHost = headerHost
        self.overlayView = overlayView
        super.init(frame: .zero)
        punchClearLayer()
        layer?.masksToBounds = false

        shadowHost.punchClearLayer()
        shadowHost.layer?.masksToBounds = false
        shadowHost.layer?.shadowColor = NSColor.black.cgColor
        shadowHost.layer?.shadowOpacity = 0.28
        shadowHost.layer?.shadowRadius = 12
        shadowHost.layer?.shadowOffset = CGSize(width: 0, height: -1)
        addSubview(shadowHost)

        plate.punchClearLayer()
        plate.layer?.masksToBounds = true
        shadowHost.addSubview(plate)
        overlayView.punchClearLayer()
        plate.addSubview(overlayView)
        plate.addSubview(headerHost)
        hairline.punchClearLayer()
        hairline.layer?.backgroundColor = LoupeChrome.hairline.cgColor
        plate.addSubview(hairline)
        plate.addSubview(chamfer)
        frameView.isHidden = true
        plate.addSubview(frameView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override var isOpaque: Bool { false }

    func applySkin(_ skin: LoupeSkin) {
        self.skin = skin
        let lens = skin == .colorLens
        hairline.isHidden = lens
        frameView.isHidden = !lens
        frameView.cornerRadius = skin.cornerRadius
        chamfer.skin = skin
        shadowHost.layer?.shadowOpacity = 0.28
        shadowHost.layer?.shadowRadius = lens ? 10 : 12
        needsLayout = true
        needsDisplay = true
        chamfer.needsDisplay = true
    }

    override var wantsUpdateLayer: Bool { true }

    override func layout() {
        super.layout()
        let chrome = chromeRect
        shadowHost.frame = chrome
        plate.frame = shadowHost.bounds
        headerHost.frame = NSRect(x: 0, y: 0, width: plate.bounds.width, height: headerHeight)
        let bottom = skin.bottomEdge
        overlayView.frame = NSRect(
            x: edge,
            y: headerHeight,
            width: max(0, plate.bounds.width - edge * 2),
            height: max(0, plate.bounds.height - headerHeight - bottom)
        )
        frameView.frame = plate.bounds
        frameView.cornerRadius = cornerRadius
        hairline.frame = NSRect(x: 12, y: headerHeight - 1, width: max(0, plate.bounds.width - 24), height: 1)
        hairline.layer?.backgroundColor = LoupeChrome.hairline.cgColor
        let grip = skin.chamfer
        chamfer.frame = NSRect(
            x: max(0, plate.bounds.width - grip),
            y: max(0, plate.bounds.height - grip),
            width: grip,
            height: grip
        )
        overlayView.punchClearLayer()
        plate.punchClearLayer()
        plate.layer?.masksToBounds = true
        plate.layer?.cornerRadius = cornerRadius
        plate.layer?.cornerCurve = .continuous
        plate.layer?.borderWidth = skin.frameStrokeWidth
        plate.layer?.borderColor = LoupeChrome.frameStroke.cgColor
        // Follow real alpha so the viewport stays a hole instead of a filled umbra.
        shadowHost.layer?.shadowPath = nil
        window?.invalidateCursorRects(for: self)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
        hairline.layer?.backgroundColor = LoupeChrome.hairline.cgColor
        chamfer.needsDisplay = true
    }

    override func updateLayer() {
        guard let layer else { return }
        layer.masksToBounds = false
        layer.backgroundColor = NSColor.clear.cgColor
        layer.isOpaque = false
        plate.punchClearLayer()
        plate.layer?.masksToBounds = true
        plate.layer?.borderColor = LoupeChrome.frameStroke.cgColor
        overlayView.punchClearLayer()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        guard bounds.contains(local) else { return nil }

        let inPlate = plate.convert(local, from: self)

        if headerHost.frame.contains(inPlate) {
            let headerHit = headerHost.hitTest(inPlate)
            if headerHit is NSControl { return headerHit }
        }

        if resizeEdge(at: local) != .none { return self }
        if headerHost.frame.contains(inPlate) {
            return headerHost.hitTest(inPlate) ?? headerHost
        }
        if overlayView.frame.contains(inPlate) {
            if isLocked() {
                return overlayView.hitTest(inPlate) ?? overlayView
            }
            return nil
        }
        if chromeRect.contains(local) { return self }
        return self
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let edgeKind = resizeEdge(at: point)
        if edgeKind != .none {
            trackResize(edge: edgeKind)
            return
        }
        super.mouseDown(with: event)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        let b = chromeRect
        let band = LoupeChrome.resizeBand
        let corner = LoupeChrome.resizeCorner
        let grip = skin.chamfer
        addCursorRect(NSRect(x: 0, y: b.minY, width: b.minX + band, height: b.height), cursor: .resizeLeftRight)
        addCursorRect(NSRect(x: b.maxX - band, y: b.minY, width: bounds.width - (b.maxX - band), height: b.height), cursor: .resizeLeftRight)
        addCursorRect(NSRect(x: b.minX, y: b.maxY - band, width: b.width, height: bounds.height - (b.maxY - band)), cursor: .resizeUpDown)
        addCursorRect(NSRect(x: b.minX, y: 0, width: b.width, height: b.minY + band), cursor: .resizeUpDown)
        addCursorRect(NSRect(x: 0, y: 0, width: b.minX + corner, height: b.minY + corner), cursor: Self.resizeCursor(.nw))
        addCursorRect(NSRect(x: b.maxX - corner, y: 0, width: bounds.width - (b.maxX - corner), height: b.minY + corner), cursor: Self.resizeCursor(.ne))
        addCursorRect(NSRect(x: 0, y: b.maxY - corner, width: b.minX + corner, height: bounds.height - (b.maxY - corner)), cursor: Self.resizeCursor(.sw))
        addCursorRect(NSRect(x: b.maxX - grip, y: b.maxY - grip, width: bounds.width - (b.maxX - grip), height: bounds.height - (b.maxY - grip)), cursor: Self.resizeCursor(.se))
    }

    private static func resizeCursor(_ corner: ResizeEdge) -> NSCursor {
        if #available(macOS 15.0, *) {
            let position: NSCursor.FrameResizePosition
            switch corner {
            case .nw: position = .topLeft
            case .ne: position = .topRight
            case .sw: position = .bottomLeft
            case .se: position = .bottomRight
            default: return .resizeLeftRight
            }
            return NSCursor.frameResize(position: position, directions: [.inward, .outward])
        }
        return .crosshair
    }

    private func resizeEdge(at point: NSPoint) -> ResizeEdge {
        let chrome = chromeRect
        let inner = LoupeChrome.resizeBand
        let corner = LoupeChrome.resizeCorner
        let grip = skin.chamfer

        let se = NSRect(x: chrome.maxX - grip, y: chrome.maxY - grip, width: grip, height: grip)
        if se.contains(point) {
            let dx = chrome.maxX - point.x
            let dy = chrome.maxY - point.y
            if dx + dy <= grip + 8 { return .se }
            if point.x >= chrome.maxX - inner || point.y >= chrome.maxY - inner { return .se }
        }

        let l = point.x <= chrome.minX + inner
        let r = point.x >= chrome.maxX - inner
        let t = point.y <= chrome.minY + inner
        let s = point.y >= chrome.maxY - inner
        let nearL = point.x <= chrome.minX + corner
        let nearR = point.x >= chrome.maxX - corner
        let nearT = point.y <= chrome.minY + corner
        let nearS = point.y >= chrome.maxY - corner

        switch (nearL && nearT, nearR && nearT, nearL && nearS, nearR && nearS, l, r, t, s) {
        case (true, _, _, _, _, _, _, _): return .nw
        case (_, true, _, _, _, _, _, _): return .ne
        case (_, _, true, _, _, _, _, _): return .sw
        case (_, _, _, true, _, _, _, _): return .se
        case (_, _, _, _, true, false, false, false): return .w
        case (_, _, _, _, false, true, false, false): return .e
        case (_, _, _, _, false, false, false, true): return .s
        case (_, _, _, _, false, false, true, false): return .n
        default: return .none
        }
    }

    private func trackResize(edge: ResizeEdge) {
        guard let window else { return }
        let startMouse = NSEvent.mouseLocation
        let startFrame = window.frame
        let minSize = window.minSize

        window.trackEvents(
            matching: [.leftMouseDragged, .leftMouseUp],
            timeout: .infinity,
            mode: .eventTracking
        ) { event, stop in
            guard let event else { return }
            if event.type == .leftMouseUp {
                stop.pointee = true
                DispatchQueue.main.async { [weak self] in
                    self?.onFrameChange?()
                }
                return
            }
            let mouse = NSEvent.mouseLocation
            let dx = mouse.x - startMouse.x
            let dy = mouse.y - startMouse.y
            var frame = startFrame

            func setWidth(_ width: CGFloat, fromMaxX: Bool) {
                let w = max(minSize.width, width)
                if fromMaxX { frame.origin.x = startFrame.maxX - w }
                frame.size.width = w
            }
            func setHeight(_ height: CGFloat, fromMaxY: Bool) {
                let h = max(minSize.height, height)
                if fromMaxY { frame.origin.y = startFrame.maxY - h }
                frame.size.height = h
            }

            switch edge {
            case .e: setWidth(startFrame.width + dx, fromMaxX: false)
            case .w: setWidth(startFrame.width - dx, fromMaxX: true)
            case .n: setHeight(startFrame.height + dy, fromMaxY: false)
            case .s: setHeight(startFrame.height - dy, fromMaxY: true)
            case .ne:
                setWidth(startFrame.width + dx, fromMaxX: false)
                setHeight(startFrame.height + dy, fromMaxY: false)
            case .nw:
                setWidth(startFrame.width - dx, fromMaxX: true)
                setHeight(startFrame.height + dy, fromMaxY: false)
            case .se:
                setWidth(startFrame.width + dx, fromMaxX: false)
                setHeight(startFrame.height - dy, fromMaxY: true)
            case .sw:
                setWidth(startFrame.width - dx, fromMaxX: true)
                setHeight(startFrame.height - dy, fromMaxY: true)
            case .none:
                break
            }
            window.setFrame(frame, display: true)
        }
    }
}

/// Diagonal grow-box in the bottom-right corner. Hits go to the parent.
final class ResizeChamferView: NSView {
    var skin: LoupeSkin = .glass

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        let s = bounds
        guard s.width > 8, s.height > 8 else { return }

        if skin == .colorLens {
            drawLensGrip(s)
            return
        }

        let facet = NSBezierPath()
        facet.move(to: NSPoint(x: 3, y: s.maxY))
        facet.line(to: NSPoint(x: s.maxX, y: s.maxY))
        facet.line(to: NSPoint(x: s.maxX, y: 3))
        facet.close()
        NSColor.white.withAlphaComponent(effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? 0.07 : 0.16).setFill()
        facet.fill()

        let bevel = NSBezierPath()
        bevel.move(to: NSPoint(x: 4, y: s.maxY - 1.2))
        bevel.line(to: NSPoint(x: s.maxX - 1.2, y: 4))
        bevel.lineWidth = 1
        bevel.lineCapStyle = .round
        LoupeChrome.frameStroke.withAlphaComponent(0.9).setStroke()
        bevel.stroke()

        let highlight = NSBezierPath()
        highlight.move(to: NSPoint(x: 6.5, y: s.maxY - 3.4))
        highlight.line(to: NSPoint(x: s.maxX - 3.4, y: 6.5))
        highlight.lineWidth = 1
        highlight.lineCapStyle = .round
        NSColor.white.withAlphaComponent(0.18).setStroke()
        highlight.stroke()

        for i in 0..<3 {
            let offset = 8 + CGFloat(i) * 4.6
            let tick = NSBezierPath()
            tick.move(to: NSPoint(x: s.maxX - offset - 6.5, y: s.maxY - 3.2))
            tick.line(to: NSPoint(x: s.maxX - 3.2, y: s.maxY - offset - 6.5))
            tick.lineWidth = 1.6
            tick.lineCapStyle = .round
            LoupeChrome.frameStroke.withAlphaComponent(0.92 - CGFloat(i) * 0.16).setStroke()
            tick.stroke()
        }
    }

    private func drawLensGrip(_ s: NSRect) {
        for i in 0..<3 {
            let offset = 6 + CGFloat(i) * 4
            let tick = NSBezierPath()
            tick.move(to: NSPoint(x: s.maxX - offset - 5, y: s.maxY - 2))
            tick.line(to: NSPoint(x: s.maxX - 2, y: s.maxY - offset - 5))
            tick.lineWidth = 1
            tick.lineCapStyle = .butt
            let color: NSColor = i % 2 == 0 ? LensPalette.quartz : LensPalette.flare
            color.withAlphaComponent(0.8 - CGFloat(i) * 0.18).setStroke()
            tick.stroke()
        }
    }
}
