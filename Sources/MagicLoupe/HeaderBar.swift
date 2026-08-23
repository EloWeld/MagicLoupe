import AppKit

final class HeaderBar: NSView {
    var onTranslate: () -> Void = {}
    var onSettings: () -> Void = {}
    var onClose: () -> Void = {}
    var onLanguageChange: (TargetLanguage) -> Void = { _ in }
    var onToggleLock: () -> Void = {}
    var onToggleSkin: () -> Void = {}

    private var skin: LoupeSkin = .glass
    private let glassPlate = GlassBackdrop(weight: .chrome)
    private let wordmark = NSTextField(labelWithString: "LENS")
    private let languagePopup = FirstMousePopUp()
    private let translateButton = SkinButton()
    private let lockButton = SkinButton()
    private let settingsButton = SkinButton()
    private let closeButton = SkinButton()
    private let skinButton = SkinButton()
    private let spinner = NSProgressIndicator()
    private let errorIcon = NSImageView()
    private let grip = NSImageView()
    private let toolbar = NSStackView()
    private let marquee = PixelMarqueeView()

    init() {
        super.init(frame: .zero)
        punchClearLayer()

        glassPlate.translatesAutoresizingMaskIntoConstraints = false
        addSubview(glassPlate)
        addSubview(marquee)

        wordmark.font = PixelFont.ui(size: 13)
        wordmark.textColor = LensPalette.wordmark
        wordmark.backgroundColor = .clear
        wordmark.drawsBackground = false
        wordmark.isBezeled = false
        wordmark.isEditable = false
        wordmark.isHidden = true
        wordmark.setContentHuggingPriority(.required, for: .horizontal)

        languagePopup.bezelStyle = .recessed
        languagePopup.controlSize = .small
        languagePopup.target = self
        languagePopup.action = #selector(languageChanged)
        languagePopup.toolTip = "Язык перевода"
        for language in TargetLanguage.allCases {
            languagePopup.addItem(withTitle: language.code)
            languagePopup.lastItem?.representedObject = language.rawValue
        }

        configure(translateButton, title: "Перевести", symbol: "translate", action: #selector(translate))
        translateButton.isBordered = true
        translateButton.bezelStyle = .recessed
        translateButton.controlSize = .small
        translateButton.toolTip = "Снять область и перевести"
        translateButton.contentTintColor = .labelColor
        translateButton.imagePosition = .imageLeading
        translateButton.imageHugsTitle = true

        configure(lockButton, symbol: "lock.fill", action: #selector(toggleLock))
        configure(settingsButton, symbol: "gearshape", action: #selector(openSettings))
        settingsButton.toolTip = "Настройки"
        configure(closeButton, symbol: "xmark", action: #selector(close))
        closeButton.toolTip = "Скрыть лупу (Esc)"
        configure(skinButton, symbol: "square.righthalf.filled", action: #selector(toggleSkin))
        skinButton.toolTip = "Стекло / Color Lens"

        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false

        errorIcon.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Ошибка")
        errorIcon.contentTintColor = .systemOrange
        errorIcon.isHidden = true
        errorIcon.setContentHuggingPriority(.required, for: .horizontal)

        grip.image = NSImage(systemSymbolName: "line.3.horizontal", accessibilityDescription: "Перетащить")
        grip.contentTintColor = .tertiaryLabelColor
        grip.toolTip = "Перетащить лупу"

        let spacer = NSView()
        spacer.setContentHuggingPriority(NSLayoutConstraint.Priority(1), for: .horizontal)
        spacer.setContentCompressionResistancePriority(NSLayoutConstraint.Priority(1), for: .horizontal)

        toolbar.orientation = .horizontal
        toolbar.alignment = .centerY
        toolbar.distribution = .fill
        toolbar.spacing = 7
        toolbar.edgeInsets = NSEdgeInsets(top: 7, left: 14, bottom: 7, right: 14)
        for view in [grip, wordmark, languagePopup, translateButton, lockButton, spacer, spinner, errorIcon, skinButton, settingsButton, closeButton] {
            toolbar.addArrangedSubview(view)
        }
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(toolbar)

        NSLayoutConstraint.activate([
            glassPlate.topAnchor.constraint(equalTo: topAnchor),
            glassPlate.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassPlate.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassPlate.bottomAnchor.constraint(equalTo: bottomAnchor),
            toolbar.leadingAnchor.constraint(equalTo: leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: trailingAnchor),
            toolbar.topAnchor.constraint(equalTo: topAnchor),
            toolbar.bottomAnchor.constraint(equalTo: bottomAnchor),
            grip.widthAnchor.constraint(equalToConstant: 16),
            lockButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 22),
            settingsButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 22),
            closeButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 22),
            skinButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 22),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override var isOpaque: Bool { false }

    override func layout() {
        super.layout()
        marquee.frame = NSRect(
            x: 12,
            y: max(0, bounds.height - 3),
            width: max(0, bounds.width - 24),
            height: 2
        )
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        if hit is NSControl { return hit }
        return self
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        window?.performDrag(with: event)
    }

    func applySkin(_ skin: LoupeSkin) {
        self.skin = skin
        let lens = skin == .colorLens
        wordmark.isHidden = !lens
        glassPlate.tint = nil
        glassPlate.cornerRadius = 0

        toolbar.spacing = lens ? 6 : 7
        toolbar.edgeInsets = lens
            ? NSEdgeInsets(top: 7, left: 12, bottom: 7, right: 12)
            : NSEdgeInsets(top: 7, left: 14, bottom: 7, right: 14)

        for button in [translateButton, lockButton, settingsButton, closeButton, skinButton] {
            button.focusRingType = .none
        }

        translateButton.isBordered = true
        translateButton.bezelStyle = .recessed
        translateButton.controlSize = .small
        translateButton.font = lens
            ? PixelFont.ui(size: 13)
            : .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .medium)
        let translateIcon = symbol("translate") ?? symbol("character.bubble")
        if lens, let translateIcon {
            translateButton.image = translateIcon.withSymbolConfiguration(.init(hierarchicalColor: .white))
        } else {
            translateButton.image = translateIcon
        }
        translateButton.title = "Перевести"
        translateButton.imagePosition = .imageLeading
        translateButton.contentTintColor = lens ? .white : .labelColor

        lockButton.image = nil
        lockButton.title = ""
        lockButton.contentTintColor = .secondaryLabelColor
        settingsButton.image = symbol("gearshape")
        settingsButton.title = ""
        settingsButton.contentTintColor = .secondaryLabelColor
        closeButton.image = symbol("xmark")
        closeButton.title = ""
        closeButton.contentTintColor = .secondaryLabelColor
        skinButton.image = symbol("square.righthalf.filled")
        skinButton.title = ""
        skinButton.contentTintColor = lens ? LensPalette.quartz : .secondaryLabelColor

        languagePopup.font = lens
            ? PixelFont.ui(size: 12)
            : .systemFont(ofSize: NSFont.smallSystemFontSize)
        languagePopup.bezelStyle = .recessed
        languagePopup.controlSize = .small
        errorIcon.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Ошибка")
        errorIcon.contentTintColor = .systemOrange
        needsLayout = true
    }

    func sync(from model: AppModel) {
        if let index = TargetLanguage.allCases.firstIndex(of: model.targetLanguage) {
            languagePopup.selectItem(at: index)
        }
        lockButton.image = symbol(model.isLocked ? "lock.fill" : "lock.open.fill")
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
        translateButton.needsDisplay = true
    }

    func setBusy(_ busy: Bool) {
        marquee.setActive(busy && skin == .colorLens)
    }

    private func configure(_ button: SkinButton, title: String? = nil, symbol name: String? = nil, action: Selector) {
        button.isBordered = false
        button.imagePosition = title == nil ? .imageOnly : .imageLeading
        button.title = title ?? ""
        if let name {
            button.image = symbol(name)
        }
        button.contentTintColor = .secondaryLabelColor
        button.target = self
        button.action = action
        button.setButtonType(.momentaryChange)
        button.focusRingType = .none
    }

    private func symbol(_ name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        let configured = image?.withSymbolConfiguration(.init(pointSize: 12, weight: .medium)) ?? image
        configured?.isTemplate = true
        return configured
    }

    @objc private func translate() { onTranslate() }
    @objc private func openSettings() { onSettings() }
    @objc private func close() { onClose() }
    @objc private func toggleLock() { onToggleLock() }
    @objc private func toggleSkin() { onToggleSkin() }

    @objc private func languageChanged() {
        guard let raw = languagePopup.selectedItem?.representedObject as? String,
              let language = TargetLanguage(rawValue: raw)
        else { return }
        onLanguageChange(language)
    }
}

class FirstMouseButton: NSButton {
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
