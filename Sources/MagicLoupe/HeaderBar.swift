import AppKit

final class HeaderBar: NSView {
    var onTranslate: () -> Void = {}
    var onSettings: () -> Void = {}
    var onClose: () -> Void = {}
    var onLanguageChange: (TargetLanguage) -> Void = { _ in }
    var onToggleLock: () -> Void = {}

    private let plate = GlassBackdrop(weight: .chrome)
    private let languagePopup = FirstMousePopUp()
    private let translateButton = FirstMouseButton()
    private let lockButton = FirstMouseButton()
    private let settingsButton = FirstMouseButton()
    private let closeButton = FirstMouseButton()
    private let spinner = NSProgressIndicator()
    private let errorIcon = NSImageView()

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        plate.translatesAutoresizingMaskIntoConstraints = false
        addSubview(plate)
        NSLayoutConstraint.activate([
            plate.topAnchor.constraint(equalTo: topAnchor),
            plate.leadingAnchor.constraint(equalTo: leadingAnchor),
            plate.trailingAnchor.constraint(equalTo: trailingAnchor),
            plate.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        languagePopup.bezelStyle = .recessed
        languagePopup.controlSize = .small
        languagePopup.target = self
        languagePopup.action = #selector(languageChanged)
        languagePopup.toolTip = "Язык перевода"
        for language in TargetLanguage.allCases {
            languagePopup.addItem(withTitle: language.code)
            languagePopup.lastItem?.representedObject = language.rawValue
        }

        configure(translateButton, title: "Перевести", action: #selector(translate))
        translateButton.isBordered = true
        translateButton.bezelStyle = .recessed
        translateButton.controlSize = .small
        translateButton.toolTip = "Снять область и перевести"

        configure(lockButton, symbol: "lock.fill", action: #selector(toggleLock))
        configure(settingsButton, symbol: "gearshape", action: #selector(openSettings))
        settingsButton.toolTip = "Настройки"
        configure(closeButton, symbol: "xmark", action: #selector(close))
        closeButton.toolTip = "Скрыть лупу (Esc)"

        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false

        errorIcon.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Ошибка")
        errorIcon.contentTintColor = .systemOrange
        errorIcon.isHidden = true
        errorIcon.setContentHuggingPriority(.required, for: .horizontal)

        let grip = NSImageView()
        grip.image = NSImage(systemSymbolName: "line.3.horizontal", accessibilityDescription: "Перетащить")
        grip.contentTintColor = .tertiaryLabelColor
        grip.toolTip = "Перетащить лупу"

        let spacer = NSView()
        spacer.setContentHuggingPriority(NSLayoutConstraint.Priority(1), for: .horizontal)
        spacer.setContentCompressionResistancePriority(NSLayoutConstraint.Priority(1), for: .horizontal)

        let stack = NSStackView(views: [
            grip, languagePopup, translateButton, lockButton,
            spacer, spinner, errorIcon, settingsButton, closeButton,
        ])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.distribution = .fill
        stack.spacing = 7
        stack.edgeInsets = NSEdgeInsets(top: 7, left: 14, bottom: 7, right: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false
        plate.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: plate.contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: plate.contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: plate.contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: plate.contentView.bottomAnchor),
            grip.widthAnchor.constraint(equalToConstant: 16),
            lockButton.widthAnchor.constraint(equalToConstant: 22),
            settingsButton.widthAnchor.constraint(equalToConstant: 22),
            closeButton.widthAnchor.constraint(equalToConstant: 22),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        if hit is NSControl { return hit }
        return self
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        window?.performDrag(with: event)
    }

    func sync(from model: AppModel) {
        if let index = TargetLanguage.allCases.firstIndex(of: model.targetLanguage) {
            languagePopup.selectItem(at: index)
        }
        lockButton.image = NSImage(
            systemSymbolName: model.isLocked ? "lock.fill" : "lock.open.fill",
            accessibilityDescription: "Замок"
        )
        lockButton.toolTip = model.isLocked
            ? "Замок: клики не проходят, перевод можно копировать"
            : "Сквозь: клики идут в окно под лупой"

        switch model.status {
        case .capturing, .translating:
            spinner.startAnimation(nil)
            errorIcon.isHidden = true
            translateButton.isEnabled = false
        case .error(let message):
            spinner.stopAnimation(nil)
            errorIcon.isHidden = false
            errorIcon.toolTip = message
            translateButton.isEnabled = true
        case .idle:
            spinner.stopAnimation(nil)
            errorIcon.isHidden = true
            translateButton.isEnabled = true
        }
    }

    private func configure(_ button: NSButton, title: String? = nil, symbol: String? = nil, action: Selector) {
        button.isBordered = false
        button.imagePosition = title == nil ? .imageOnly : .imageLeading
        if let title { button.title = title }
        if let symbol {
            button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        }
        button.contentTintColor = .secondaryLabelColor
        button.target = self
        button.action = action
        button.setButtonType(.momentaryChange)
    }

    @objc private func translate() { onTranslate() }
    @objc private func openSettings() { onSettings() }
    @objc private func close() { onClose() }
    @objc private func toggleLock() { onToggleLock() }

    @objc private func languageChanged() {
        guard let raw = languagePopup.selectedItem?.representedObject as? String,
              let language = TargetLanguage(rawValue: raw)
        else { return }
        onLanguageChange(language)
    }
}

final class FirstMouseButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        super.mouseDown(with: event)
    }
}

final class FirstMousePopUp: NSPopUpButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        super.mouseDown(with: event)
    }
}
