import AppKit
import SwiftUI

@main
enum MagicLoupeEntry {
    nonisolated(unsafe) static var retainedDelegate: AppDelegate?

    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        retainedDelegate = delegate
        app.delegate = delegate
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: AppModel!
    var loupe: LoupeController!
    var pipeline: TranslationPipeline!
    private var statusItem: NSStatusItem?
    private var statusMenu: NSMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        PermissionSession.start()
        installStatusItem()
        Task { @MainActor in
            self.bootstrap()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @MainActor
    private func bootstrap() {
        let model = AppModel()
        let blocked = AccessGate.shouldPresent
        if blocked {
            model.isLoupeVisible = false
        }
        self.model = model
        let loupe = LoupeController(model: model)
        let pipeline = TranslationPipeline(model: model, loupe: loupe)
        loupe.pipeline = pipeline
        self.loupe = loupe
        self.pipeline = pipeline
        loupe.start()
        if blocked {
            presentAccessWall()
        }
    }

    @MainActor
    private func presentAccessWall() {
        AccessWallController.shared.present { [weak self] in
            self?.model.isLoupeVisible = true
        }
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = item.button else { return }
        button.title = "Loupe"
        if let image = NSImage(systemSymbolName: "plus.magnifyingglass", accessibilityDescription: "Magic Loupe") {
            image.isTemplate = true
            button.image = image
            button.imagePosition = .imageLeading
        }
        button.toolTip = "Magic Loupe"
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        let menu = NSMenu()
        menu.addItem(makeMenuItem("Перевести", #selector(translate)))
        menu.addItem(.separator())
        menu.addItem(makeMenuItem("Настройки…", #selector(openSettings), ","))
        menu.addItem(makeMenuItem("Перезапустить", #selector(relaunch)))
        menu.addItem(.separator())
        menu.addItem(makeMenuItem("Выйти из Magic Loupe", #selector(quit), "q"))
        statusMenu = menu
        statusItem = item
    }

    private func makeMenuItem(_ title: String, _ action: Selector, _ key: String = "") -> NSMenuItem {
        let row = NSMenuItem(title: title, action: action, keyEquivalent: key)
        row.target = self
        return row
    }

    @objc private func statusItemClicked() {
        guard let button = statusItem?.button else { return }
        if NSApp.currentEvent?.type == .rightMouseUp {
            statusMenu?.popUp(
                positioning: nil,
                at: NSPoint(x: 0, y: button.bounds.height + 2),
                in: button
            )
            return
        }
        showLoupe()
    }

    @MainActor
    private func showLoupe() {
        guard model != nil else { return }
        if AccessGate.shouldPresent {
            presentAccessWall()
            return
        }
        model.isLoupeVisible = true
    }

    @objc private func translate() {
        Task { @MainActor in
            guard self.model != nil, self.pipeline != nil else { return }
            if AccessGate.shouldPresent {
                self.presentAccessWall()
                return
            }
            self.model.isLoupeVisible = true
            self.pipeline.translateNow()
        }
    }

    @objc private func openSettings() {
        Task { @MainActor in
            guard self.loupe != nil else { return }
            self.loupe.openSettings()
        }
    }

    @objc private func relaunch() {
        Task { @MainActor in
            ScreenPermission.relaunch()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
