import AppKit
import SwiftUI
import Observation

@MainActor
final class LoupeController {
    private(set) var panel: LoupePanel?
    private let model: AppModel
    private let overlayView = OverlayView()
    private let headerBar = HeaderBar()
    private let rootView: LoupeRootView
    private var settingsWindow: NSWindow?
    private var observing = false
    weak var pipeline: TranslationPipeline?
    private let moveDebounce = Debouncer()
    private var pollTask: Task<Void, Never>?
    private var notifications: [NSObjectProtocol] = []
    private var appliedSkin: LoupeSkin?

    var contentRectInWindow: CGRect {
        overlayView.convert(overlayView.bounds, to: nil)
    }

    func flushOverlay() {
        overlayView.apply(
            model.overlayBlocks,
            script: ScriptKind.of(model.targetLanguage),
            locked: model.isLocked,
            animated: true
        )
        overlayView.setBusy(model.status == .translating && model.overlayBlocks.isEmpty)
        headerBar.setBusy(model.status == .translating && model.overlayBlocks.isEmpty)
    }

    init(model: AppModel) {
        self.model = model
        rootView = LoupeRootView(headerHost: headerBar, overlayView: overlayView)
        rootView.isLocked = { [weak model] in model?.isLocked ?? true }
    }

    func start() {
        let panel = LoupePanel()
        self.panel = panel
        panel.onEscape = { [weak self] in
            self?.model.isLoupeVisible = false
        }

        headerBar.onTranslate = { [weak self] in self?.pipeline?.translateNow() }
        headerBar.onSettings = { [weak self] in self?.openSettings() }
        headerBar.onClose = { [weak self] in self?.model.isLoupeVisible = false }
        headerBar.onToggleLock = { [weak self] in
            guard let self else { return }
            self.model.isLocked.toggle()
            self.model.persist()
        }
        headerBar.onToggleSkin = { [weak self] in
            guard let self else { return }
            self.model.skin = self.model.skin == .glass ? .colorLens : .glass
            self.model.persist()
        }
        headerBar.onLanguageChange = { [weak self] language in
            guard let self else { return }
            self.model.targetLanguage = language
            self.model.persist()
        }
        headerBar.applySkin(model.skin)
        headerBar.sync(from: model)

        panel.contentView = rootView
        panel.center()
        rootView.onFrameChange = { [weak self] in
            self?.handleFrameChange()
        }

        notifications.append(NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleFrameChange() }
        })
        notifications.append(NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleFrameChange() }
        })

        startObserving()
        applyModel()
        startPolling()
    }

    func openSettings() {
        if let settingsWindow {
            NSApp.activate(ignoringOtherApps: true)
            settingsWindow.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 560),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Настройки LangLens"
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = true
        let hosting = NSHostingView(rootView: SettingsView(model: model))
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.style = .regular
            glass.cornerRadius = 0
            glass.contentView = hosting
            window.contentView = glass
        } else {
            let effect = NSVisualEffectView()
            effect.material = .sidebar
            effect.blendingMode = .behindWindow
            effect.state = .active
            hosting.frame = effect.bounds
            hosting.autoresizingMask = [.width, .height]
            effect.addSubview(hosting)
            window.contentView = effect
        }
        window.isReleasedWhenClosed = false
        window.center()
        settingsWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func handleFrameChange() {
        pipeline?.invalidateSnapshot()
        guard model.translateMode == .automatic else { return }
        moveDebounce.schedule(milliseconds: 450) { [weak self] in
            self?.pipeline?.translateIfChanged()
        }
    }

    private func startObserving() {
        guard !observing else { return }
        observing = true
        watch()
    }

    private func watch() {
        withObservationTracking {
            _ = model.overlayBlocks
            _ = model.isLocked
            _ = model.isLoupeVisible
            _ = model.targetLanguage
            _ = model.status
            _ = model.skin
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.applyModel()
                self?.watch()
            }
        }
    }

    private func applyModel() {
        if appliedSkin != model.skin {
            appliedSkin = model.skin
            rootView.applySkin(model.skin)
            headerBar.applySkin(model.skin)
            overlayView.applySkin(model.skin)
            panel?.minSize = model.skin.minSize
        }
        overlayView.apply(
            model.overlayBlocks,
            script: ScriptKind.of(model.targetLanguage),
            locked: model.isLocked,
            animated: true
        )
        overlayView.setBusy(model.status == .translating && model.overlayBlocks.isEmpty)
        headerBar.setBusy(model.status == .translating && model.overlayBlocks.isEmpty)
        headerBar.sync(from: model)
        rootView.window?.invalidateCursorRects(for: rootView)

        guard let panel else { return }
        if model.isLoupeVisible {
            if !panel.isVisible {
                panel.orderFrontRegardless()
            }
        } else {
            panel.orderOut(nil)
        }
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(1200))
                guard let self else { return }
                guard self.model.translateMode == .automatic,
                      self.model.isLoupeVisible,
                      self.panel?.isVisible == true
                else { continue }
                self.pipeline?.translateIfChanged()
            }
        }
    }
}
