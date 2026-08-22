import AppKit
import Combine
import Observation
import SwiftUI

@MainActor
@Observable
final class AccessWallStore {
    var rows: [PermissionRow] = []
    var tick: Int = 0

    var canContinue: Bool {
        AccessGate.allRequiredFullyGranted
    }

    func refresh() {
        rows = AppPermission.allCases.map { permission in
            PermissionRow(permission: permission, status: permission.status)
        }
        tick += 1
    }

    func request(_ permission: AppPermission) {
        permission.request()
        refresh()
    }

    func openSettings(_ permission: AppPermission) {
        permission.openSystemSettings()
    }
}

struct PermissionRow: Identifiable {
    var permission: AppPermission
    var status: PermissionStatus
    var id: String { permission.rawValue }
}

@MainActor
final class AccessWallController: NSObject, NSWindowDelegate {
    static let shared = AccessWallController()

    private var window: NSWindow?
    private let store = AccessWallStore()
    private var onContinue: (() -> Void)?
    private var becomeActiveObserver: NSObjectProtocol?

    var isVisible: Bool { window?.isVisible == true }

    func present(onContinue: (() -> Void)? = nil) {
        if let onContinue {
            self.onContinue = onContinue
        }
        store.refresh()
        if window == nil {
            window = makeWindow()
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.center()
        startObserving()
    }

    func focus() {
        guard isVisible else { return }
        store.refresh()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func dismiss() {
        window?.orderOut(nil)
        stopObserving()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        dismiss()
        return false
    }

    private func continueTapped() {
        guard store.canContinue else { return }
        AccessGate.markCompleted()
        dismiss()
        onContinue?()
    }

    private func startObserving() {
        stopObserving()
        becomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.store.refresh()
            }
        }
    }

    private func stopObserving() {
        if let becomeActiveObserver {
            NotificationCenter.default.removeObserver(becomeActiveObserver)
            self.becomeActiveObserver = nil
        }
    }

    private func makeWindow() -> NSWindow {
        let root = AccessWallView(
            store: store,
            onContinue: { [weak self] in self?.continueTapped() }
        )
        let hosting = NSHostingView(rootView: root)
        hosting.wantsLayer = true

        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 500),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Доступ"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = true
        window.isFloatingPanel = true
        window.level = .floating
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.hasShadow = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.cornerRadius = 22
            glass.style = .regular
            glass.contentView = hosting
            window.contentView = glass
        } else {
            let effect = NSVisualEffectView()
            effect.material = .popover
            effect.blendingMode = .behindWindow
            effect.state = .active
            effect.wantsLayer = true
            effect.layer?.cornerRadius = 22
            effect.layer?.cornerCurve = .continuous
            effect.layer?.masksToBounds = true
            hosting.frame = effect.bounds
            hosting.autoresizingMask = [.width, .height]
            effect.addSubview(hosting)
            window.contentView = effect
        }
        return window
    }
}

struct AccessWallView: View {
    @Bindable var store: AccessWallStore
    var onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            permissionList
            relaunchNote
            Spacer(minLength: 8)
            footer
        }
        .padding(.horizontal, 28)
        .padding(.top, 36)
        .padding(.bottom, 24)
        .frame(width: 440, height: 500)
        .background(Color.clear)
        .onAppear { store.refresh() }
        .onReceive(Timer.publish(every: 0.8, on: .main, in: .common).autoconnect()) { _ in
            store.refresh()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "plus.magnifyingglass")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.primary.opacity(0.85))
            Text("Magic Loupe")
                .font(.system(size: 22, weight: .semibold))
            Text("Нужен доступ, чтобы читать текст под лупой и переводить его поверх экрана.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var permissionList: some View {
        VStack(spacing: 10) {
            ForEach(store.rows) { row in
                PermissionRowView(
                    row: row,
                    onAllow: { store.request(row.permission) },
                    onSettings: { store.openSettings(row.permission) }
                )
            }
        }
    }

    private var relaunchNote: some View {
        Text("Если macOS покажет свой диалог Quit & Reopen — это нормально. После перезапуска этот экран откроется снова, уже с галочкой.")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Продолжить") {
                onContinue()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!store.canContinue)
        }
    }
}

private struct PermissionRowView: View {
    let row: PermissionRow
    var onAllow: () -> Void
    var onSettings: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 36, height: 36)
                Image(systemName: row.permission.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.8))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(row.permission.title)
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    statusBadge
                }
                Text(row.permission.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if row.status == .missing {
                    HStack(spacing: 8) {
                        Button("Разрешить", action: onAllow)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        Button("Настройки", action: onSettings)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                    .padding(.top, 4)
                } else if row.status == .needsRelaunch {
                    Button("Открыть настройки", action: onSettings)
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.045))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch row.status {
        case .granted:
            Label("Разрешено", systemImage: "checkmark.circle.fill")
                .labelStyle(.titleAndIcon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.green)
        case .needsRelaunch:
            Label("Ждём macOS", systemImage: "ellipsis.circle.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.orange)
        case .missing:
            Label("Не выдано", systemImage: "circle")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}
