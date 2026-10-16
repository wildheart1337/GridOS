import AppKit

/// A rounded, System Settings–style group that hosts a column of rows.
private final class SettingsCardView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 0.5
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var wantsUpdateLayer: Bool { true }

    /// Resolves the dynamic colors for the current light or dark appearance.
    override func updateLayer() {
        layer?.backgroundColor = NSColor.quaternarySystemFill.cgColor
        layer?.borderColor = NSColor.separatorColor.cgColor
    }
}

/// The panes of the settings window, in toolbar order.
private enum SettingsPane: String, CaseIterable {
    case general
    case grid
    case activation
    case applications
    case about

    var identifier: NSToolbarItem.Identifier { NSToolbarItem.Identifier("gridos." + rawValue) }

    var symbolName: String {
        switch self {
        case .general: "gearshape"
        case .grid: "square.grid.3x3"
        case .activation: "keyboard"
        case .applications: "app.badge"
        case .about: "info.circle"
        }
    }

    var titleKey: String { "settings.tab." + rawValue }
}

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate, NSToolbarDelegate {
    private enum Feedback {
        case key(String)
        case formatted(String, String)
    }

    private static let paneWidth: CGFloat = 560

    private let preferences: LunchpadPreferences
    private let localizer: AppLocalizer
    private let hotKeyController: HotKeyController
    private let loginItemController: LoginItemController
    private let gestureErrorProvider: () -> String?

    /// Adds GridOS itself to the Dock; supplied by the app delegate.
    var onAddGridOSToDock: (() -> Void)?

    // Row titles.
    private let languageLabel = NSTextField(labelWithString: "")
    private let orderLabel = NSTextField(labelWithString: "")
    private let loginItemLabel = NSTextField(labelWithString: "")
    private let dockLabel = NSTextField(labelWithString: "")
    private let columnsLabel = NSTextField(labelWithString: "")
    private let rowsLabel = NSTextField(labelWithString: "")
    private let shortcutLabel = NSTextField(labelWithString: "")
    private let spotlightKeyLabel = NSTextField(labelWithString: "")
    private let gestureLabel = NSTextField(labelWithString: "")
    private let gestureFingerCountLabel = NSTextField(labelWithString: "")
    private let hotCornerLabel = NSTextField(labelWithString: "")
    private let hiddenAppsLabel = NSTextField(labelWithString: "")
    private let customNamesLabel = NSTextField(labelWithString: "")
    private let appFoldersLabel = NSTextField(labelWithString: "")

    // Notes under groups.
    private let gridNote = NSTextField(wrappingLabelWithString: "")
    private let spotlightKeyNote = NSTextField(wrappingLabelWithString: "")
    private let gestureNote = NSTextField(wrappingLabelWithString: "")
    private let appFoldersList = NSTextField(wrappingLabelWithString: "")

    // Controls.
    private let languagePopup = NSPopUpButton()
    private let orderPopup = NSPopUpButton()
    private let loginItemSwitch = NSSwitch()
    private let loginItemApprovalButton = NSButton()
    private let addToDockButton = NSButton()
    private let columnsPopup = NSPopUpButton()
    private let rowsPopup = NSPopUpButton()
    private let shortcutRecorder: ShortcutRecorderView
    private let clearShortcutButton = NSButton()
    private let spotlightKeySwitch = NSSwitch()
    private let gestureSwitch = NSSwitch()
    private let gestureFingerCountPopup = NSPopUpButton()
    private let hotCornerPopup = NSPopUpButton()
    private let unhideAllButton = NSButton()
    private let resetNamesButton = NSButton()
    private let addFolderButton = NSButton()
    private let clearFoldersButton = NSButton()

    // About pane.
    private let aboutIcon = NSImageView()
    private let aboutName = NSTextField(labelWithString: "GridOS")
    private let aboutVersion = NSTextField(labelWithString: "")
    private let aboutCredit = NSTextField(wrappingLabelWithString: "")

    private let feedbackLabel = NSTextField(wrappingLabelWithString: "")
    private var transientFeedback: Feedback?

    private let paneHost = NSView()
    private var paneViews: [SettingsPane: NSView] = [:]
    private var toolbarItems: [NSToolbarItem.Identifier: NSToolbarItem] = [:]
    private var selectedPane: SettingsPane = .general

    init(
        preferences: LunchpadPreferences,
        localizer: AppLocalizer,
        hotKeyController: HotKeyController,
        loginItemController: LoginItemController,
        gestureErrorProvider: @escaping () -> String?
    ) {
        self.preferences = preferences
        self.localizer = localizer
        self.hotKeyController = hotKeyController
        self.loginItemController = loginItemController
        self.gestureErrorProvider = gestureErrorProvider
        shortcutRecorder = ShortcutRecorderView(localizer: localizer)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Self.paneWidth, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.collectionBehavior.insert(.moveToActiveSpace)
        window.toolbarStyle = .preference
        super.init(window: window)
        window.delegate = self
        setupControls()
        setupToolbar()
        setupContent()
        refreshLocalizedContent()
        select(.general, animated: false)
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        refreshLocalizedContent()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    func refreshLocalizedContent() {
        window?.title = localizer.string(selectedPane.titleKey)
        for pane in SettingsPane.allCases {
            toolbarItems[pane.identifier]?.label = localizer.string(pane.titleKey)
        }

        languageLabel.stringValue = localizer.string("settings.language")
        orderLabel.stringValue = localizer.string("settings.application-order")
        loginItemLabel.stringValue = localizer.string("settings.launch-at-login")
        dockLabel.stringValue = localizer.string("settings.dock")
        addToDockButton.title = localizer.string("settings.dock.add")
        columnsLabel.stringValue = localizer.string("settings.grid-columns")
        rowsLabel.stringValue = localizer.string("settings.grid-rows")
        gridNote.stringValue = localizer.string("settings.grid.note")
        shortcutLabel.stringValue = localizer.string("settings.shortcut")
        spotlightKeyLabel.stringValue = localizer.string("settings.spotlight-key")
        spotlightKeyNote.stringValue = localizer.string("settings.spotlight-key.note")
        gestureLabel.stringValue = localizer.string("settings.trackpad-gesture")
        gestureFingerCountLabel.stringValue = localizer.string("settings.gesture-finger-count")
        gestureNote.stringValue = localizer.string("settings.trackpad-gesture.note")
        hotCornerLabel.stringValue = localizer.string("settings.hot-corner")
        hiddenAppsLabel.stringValue = localizer.string("settings.hidden-apps")
        customNamesLabel.stringValue = localizer.string("settings.custom-names")
        appFoldersLabel.stringValue = localizer.string("settings.app-folders")
        addFolderButton.title = localizer.string("settings.app-folders.add")
        clearFoldersButton.title = localizer.string("settings.app-folders.clear")
        clearShortcutButton.title = localizer.string("settings.shortcut.clear")
        loginItemApprovalButton.title = localizer.string("settings.launch-at-login.open-settings")
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "—"
        aboutVersion.stringValue = localizer.formatted("settings.about.version", version)
        aboutCredit.stringValue = localizer.string("settings.about.credit")

        rebuildLanguagePopup()
        rebuildOrderPopup()
        rebuildGestureFingerCountPopup()
        rebuildGridPopups()
        rebuildHotCornerPopup()
        refreshApplicationCustomizationState()
        refreshShortcutState()
        refreshLoginItemState()
        gestureSwitch.state = preferences.gestureEnabled ? .on : .off
        spotlightKeySwitch.state = preferences.spotlightKeyOpensGridOS ? .on : .off
        refreshFeedback()
        resizeWindowToFitPane(animated: false)
    }

    /// Whether the login item waits for approval in System Settings (diagnostics and tests).
    var isShowingLoginItemApproval: Bool { !loginItemApprovalButton.isHidden }

    /// The current explanatory text below the settings (diagnostics and tests).
    var feedbackText: String? { feedbackLabel.isHidden ? nil : feedbackLabel.stringValue }

    private func refreshLoginItemState() {
        loginItemSwitch.isEnabled = loginItemController.isAvailable
        loginItemSwitch.state = loginItemController.isEnabled ? .on : .off
        loginItemApprovalButton.isHidden = !loginItemController.requiresApproval
    }

    /// The user may approve the login item in System Settings and come back.
    func windowDidBecomeKey(_ notification: Notification) {
        refreshLoginItemState()
        refreshFeedback()
    }

    // MARK: Toolbar

    private func setupToolbar() {
        let toolbar = NSToolbar(identifier: "GridOSSettingsToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        toolbar.allowsUserCustomization = false
        window?.toolbar = toolbar
        toolbar.selectedItemIdentifier = SettingsPane.general.identifier
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        SettingsPane.allCases.map(\.identifier)
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        SettingsPane.allCases.map(\.identifier)
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        SettingsPane.allCases.map(\.identifier)
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        guard let pane = SettingsPane.allCases.first(where: { $0.identifier == itemIdentifier })
        else { return nil }
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = localizer.string(pane.titleKey)
        item.image = NSImage(systemSymbolName: pane.symbolName, accessibilityDescription: nil)
        item.target = self
        item.action = #selector(toolbarItemSelected(_:))
        toolbarItems[itemIdentifier] = item
        return item
    }

    @objc private func toolbarItemSelected(_ sender: NSToolbarItem) {
        guard let pane = SettingsPane.allCases.first(where: { $0.identifier == sender.itemIdentifier })
        else { return }
        select(pane, animated: true)
    }

    private func select(_ pane: SettingsPane, animated: Bool) {
        selectedPane = pane
        window?.toolbar?.selectedItemIdentifier = pane.identifier
        window?.title = localizer.string(pane.titleKey)
        paneHost.subviews.forEach { $0.removeFromSuperview() }
        guard let view = paneViews[pane] else { return }
        paneHost.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: paneHost.topAnchor),
            view.leadingAnchor.constraint(equalTo: paneHost.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: paneHost.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: paneHost.bottomAnchor),
        ])
        resizeWindowToFitPane(animated: animated)
    }

    /// Keeps the window's top edge in place while its height follows the selected pane.
    private func resizeWindowToFitPane(animated: Bool) {
        guard let window, let contentView = window.contentView else { return }
        contentView.layoutSubtreeIfNeeded()
        let fitting = contentView.fittingSize
        let contentRect = NSRect(x: 0, y: 0, width: Self.paneWidth, height: fitting.height)
        var frame = window.frameRect(forContentRect: contentRect)
        frame.origin.x = window.frame.minX
        frame.origin.y = window.frame.maxY - frame.height
        guard frame != window.frame else { return }
        window.setFrame(frame, display: true, animate: animated && window.isVisible)
    }

    // MARK: Layout

    private func setupControls() {
        languagePopup.target = self
        languagePopup.action = #selector(languageChanged(_:))
        orderPopup.target = self
        orderPopup.action = #selector(orderChanged(_:))
        gestureFingerCountPopup.target = self
        gestureFingerCountPopup.action = #selector(gestureFingerCountChanged(_:))
        columnsPopup.target = self
        columnsPopup.action = #selector(gridDimensionChanged(_:))
        rowsPopup.target = self
        rowsPopup.action = #selector(gridDimensionChanged(_:))
        hotCornerPopup.target = self
        hotCornerPopup.action = #selector(hotCornerChanged(_:))
        for popup in [languagePopup, orderPopup, gestureFingerCountPopup, columnsPopup, rowsPopup,
                      hotCornerPopup] {
            popup.translatesAutoresizingMaskIntoConstraints = false
            popup.widthAnchor.constraint(equalToConstant: 200).isActive = true
        }

        shortcutRecorder.onCandidate = { [weak self] configuration in
            self?.applyShortcut(.configured(configuration))
        }
        shortcutRecorder.onClear = { [weak self] in
            self?.applyShortcut(.disabled)
        }
        shortcutRecorder.onValidationError = { [weak self] in
            self?.transientFeedback = .key("settings.shortcut.invalid")
            self?.refreshFeedback()
        }

        for button in [clearShortcutButton, loginItemApprovalButton, addToDockButton,
                       unhideAllButton, resetNamesButton, addFolderButton, clearFoldersButton] {
            button.bezelStyle = .rounded
            button.target = self
        }
        clearShortcutButton.action = #selector(clearShortcut(_:))
        loginItemApprovalButton.action = #selector(openLoginItemSettings(_:))
        loginItemApprovalButton.isHidden = true
        addToDockButton.action = #selector(addGridOSToDock(_:))
        unhideAllButton.action = #selector(unhideAll(_:))
        resetNamesButton.action = #selector(resetNames(_:))
        addFolderButton.action = #selector(addApplicationFolder(_:))
        clearFoldersButton.action = #selector(clearApplicationFolders(_:))

        loginItemSwitch.target = self
        loginItemSwitch.action = #selector(loginItemChanged(_:))
        gestureSwitch.target = self
        gestureSwitch.action = #selector(gestureChanged(_:))
        spotlightKeySwitch.target = self
        spotlightKeySwitch.action = #selector(spotlightKeyChanged(_:))

        for note in [gridNote, spotlightKeyNote, gestureNote, appFoldersList, feedbackLabel] {
            note.textColor = .secondaryLabelColor
            note.font = .systemFont(ofSize: 11)
            note.maximumNumberOfLines = 0
            note.translatesAutoresizingMaskIntoConstraints = false
            note.preferredMaxLayoutWidth = Self.paneWidth - 64
        }
        feedbackLabel.font = .systemFont(ofSize: 12)
        appFoldersList.lineBreakMode = .byTruncatingMiddle
    }

    private func setupContent() {
        guard let window else { return }

        let shortcutControls = horizontalStack([shortcutRecorder, clearShortcutButton])
        let loginItemControls = horizontalStack([loginItemApprovalButton, loginItemSwitch])
        let folderControls = horizontalStack([clearFoldersButton, addFolderButton])

        paneViews[.general] = makePane([
            card([
                row(languageLabel, languagePopup),
                row(orderLabel, orderPopup),
            ]),
            card([
                row(loginItemLabel, loginItemControls),
                row(dockLabel, addToDockButton),
            ]),
        ])
        paneViews[.grid] = makePane([
            card([
                row(columnsLabel, columnsPopup),
                row(rowsLabel, rowsPopup),
            ]),
            note(gridNote),
        ])
        paneViews[.activation] = makePane([
            card([
                row(shortcutLabel, shortcutControls),
                row(spotlightKeyLabel, spotlightKeySwitch),
            ]),
            note(spotlightKeyNote),
            card([
                row(gestureLabel, gestureSwitch),
                row(gestureFingerCountLabel, gestureFingerCountPopup),
            ]),
            note(gestureNote),
            card([
                row(hotCornerLabel, hotCornerPopup),
            ]),
        ])
        paneViews[.applications] = makePane([
            card([
                row(hiddenAppsLabel, unhideAllButton),
                row(customNamesLabel, resetNamesButton),
                row(appFoldersLabel, folderControls),
            ]),
            note(appFoldersList),
        ])
        paneViews[.about] = makeAboutPane()

        paneHost.translatesAutoresizingMaskIntoConstraints = false
        let root = NSStackView(views: [paneHost, feedbackLabel])
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 0
        root.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 16, right: 0)
        root.translatesAutoresizingMaskIntoConstraints = false
        let content = NSView()
        content.addSubview(root)
        window.contentView = content
        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: content.topAnchor),
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            root.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            content.widthAnchor.constraint(equalToConstant: Self.paneWidth),
            paneHost.widthAnchor.constraint(equalToConstant: Self.paneWidth),
            feedbackLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 32),
            feedbackLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -32),
        ])
    }

    private func makePane(_ sections: [NSView]) -> NSView {
        let stack = NSStackView(views: sections)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 16, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false
        for section in sections {
            section.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -48).isActive = true
        }
        return stack
    }

    private func makeAboutPane() -> NSView {
        aboutIcon.image = NSApp.applicationIconImage
        aboutIcon.imageScaling = .scaleProportionallyUpOrDown
        aboutIcon.translatesAutoresizingMaskIntoConstraints = false
        aboutIcon.widthAnchor.constraint(equalToConstant: 96).isActive = true
        aboutIcon.heightAnchor.constraint(equalToConstant: 96).isActive = true
        aboutName.font = .systemFont(ofSize: 22, weight: .semibold)
        aboutVersion.textColor = .secondaryLabelColor
        aboutCredit.textColor = .secondaryLabelColor
        aboutCredit.font = .systemFont(ofSize: 11)
        aboutCredit.alignment = .center
        aboutCredit.preferredMaxLayoutWidth = Self.paneWidth - 96

        let stack = NSStackView(views: [aboutIcon, aboutName, aboutVersion, aboutCredit])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 28, left: 24, bottom: 24, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    private func card(_ rows: [NSView]) -> NSView {
        let card = SettingsCardView()
        card.translatesAutoresizingMaskIntoConstraints = false
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        for (index, row) in rows.enumerated() {
            if index > 0 {
                let separator = NSBox()
                separator.boxType = .separator
                separator.translatesAutoresizingMaskIntoConstraints = false
                stack.addArrangedSubview(separator)
                separator.leadingAnchor.constraint(equalTo: stack.leadingAnchor, constant: 14).isActive = true
                separator.trailingAnchor.constraint(equalTo: stack.trailingAnchor, constant: -14).isActive = true
            }
            stack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])
        return card
    }

    private func row(_ label: NSTextField, _ control: NSView) -> NSView {
        label.font = .systemFont(ofSize: 13)
        label.lineBreakMode = .byTruncatingTail
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        control.setContentHuggingPriority(.required, for: .horizontal)
        control.setContentCompressionResistancePriority(.required, for: .horizontal)
        let row = NSStackView(views: [label, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fill
        row.spacing = 12
        row.edgeInsets = NSEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        return row
    }

    private func horizontalStack(_ views: [NSView]) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        return stack
    }

    /// A footnote aligned with the text inside the cards above it.
    private func note(_ label: NSTextField) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
        ])
        return container
    }

    private func rebuildLanguagePopup() {
        languagePopup.removeAllItems()
        let values: [(InterfaceLanguage, String)] = [
            (.system, localizer.string("settings.language.system")),
            (.english, localizer.string("settings.language.english")),
            (.simplifiedChinese, localizer.string("settings.language.simplified-chinese")),
            (.russian, localizer.string("settings.language.russian")),
        ]
        for (index, value) in values.enumerated() {
            languagePopup.addItem(withTitle: value.1)
            languagePopup.item(at: index)?.representedObject = value.0.rawValue
        }
        let index = values.firstIndex { $0.0 == preferences.interfaceLanguage } ?? 0
        languagePopup.selectItem(at: index)
    }

    private func rebuildOrderPopup() {
        orderPopup.removeAllItems()
        let values: [(ApplicationSortOrder, String)] = [
            (.manual, localizer.string("settings.application-order.manual")),
            (.name, localizer.string("settings.application-order.name")),
            (.creationDate, localizer.string("settings.application-order.creation-date")),
            (.modificationDate, localizer.string("settings.application-order.modification-date")),
        ]
        for (index, value) in values.enumerated() {
            orderPopup.addItem(withTitle: value.1)
            orderPopup.item(at: index)?.representedObject = value.0.rawValue
        }
        let index = values.firstIndex { $0.0 == preferences.applicationSortOrder } ?? 0
        orderPopup.selectItem(at: index)
    }

    private func rebuildGestureFingerCountPopup() {
        gestureFingerCountPopup.removeAllItems()
        let values: [(GestureFingerCount, String)] = [
            (.three, localizer.string("settings.gesture-finger-count.three")),
            (.four, localizer.string("settings.gesture-finger-count.four")),
        ]
        for (index, value) in values.enumerated() {
            gestureFingerCountPopup.addItem(withTitle: value.1)
            gestureFingerCountPopup.item(at: index)?.representedObject = value.0.rawValue
        }
        let index = values.firstIndex { $0.0 == preferences.gestureFingerCount } ?? 1
        gestureFingerCountPopup.selectItem(at: index)
    }

    private func rebuildGridPopups() {
        columnsPopup.removeAllItems()
        for value in LunchpadPreferences.gridColumnRange {
            columnsPopup.addItem(withTitle: String(value))
            columnsPopup.lastItem?.representedObject = value
        }
        columnsPopup.selectItem(withTitle: String(preferences.gridColumns))

        rowsPopup.removeAllItems()
        for value in LunchpadPreferences.gridRowRange {
            rowsPopup.addItem(withTitle: String(value))
            rowsPopup.lastItem?.representedObject = value
        }
        rowsPopup.selectItem(withTitle: String(preferences.gridRows))
    }

    private func rebuildHotCornerPopup() {
        hotCornerPopup.removeAllItems()
        let values: [(HotCorner, String)] = [
            (.none, localizer.string("settings.hot-corner.none")),
            (.topLeft, localizer.string("settings.hot-corner.top-left")),
            (.topRight, localizer.string("settings.hot-corner.top-right")),
            (.bottomLeft, localizer.string("settings.hot-corner.bottom-left")),
            (.bottomRight, localizer.string("settings.hot-corner.bottom-right")),
        ]
        for (index, value) in values.enumerated() {
            hotCornerPopup.addItem(withTitle: value.1)
            hotCornerPopup.item(at: index)?.representedObject = value.0.rawValue
        }
        let index = values.firstIndex { $0.0 == preferences.hotCorner } ?? 0
        hotCornerPopup.selectItem(at: index)
    }

    private func refreshApplicationCustomizationState() {
        let hiddenCount = preferences.hiddenApplicationIdentifiers.count
        unhideAllButton.title = localizer.formatted("settings.hidden-apps.show-all", String(hiddenCount))
        unhideAllButton.isEnabled = hiddenCount > 0

        let renamedCount = preferences.customApplicationNames.count
        resetNamesButton.title = localizer.formatted("settings.custom-names.reset", String(renamedCount))
        resetNamesButton.isEnabled = renamedCount > 0

        let folders = preferences.additionalApplicationFolders
        appFoldersList.stringValue = folders.isEmpty
            ? localizer.string("settings.app-folders.none")
            : folders.joined(separator: "\n")
        clearFoldersButton.isEnabled = !folders.isEmpty
    }

    private func refreshShortcutState() {
        let managed = hotKeyController.isExternallyManaged
        shortcutRecorder.configuration = managed
            ? hotKeyController.activeConfiguration
            : preferences.hotKey.configuration
        shortcutRecorder.isEditable = !managed
        shortcutRecorder.refreshLocalizedContent(localizer)
        clearShortcutButton.isEnabled = !managed && preferences.hotKey.configuration != nil
    }

    private func applyShortcut(_ preference: HotKeyPreference) {
        switch hotKeyController.apply(preference) {
        case .success:
            preferences.hotKey = preference
            transientFeedback = nil
        case .failure(let error):
            switch error {
            case .conflict:
                transientFeedback = .key("settings.shortcut.conflict")
            case .invalid:
                transientFeedback = .key("settings.shortcut.invalid")
            case .managedByEnvironment:
                transientFeedback = nil
            case .unavailable:
                transientFeedback = .key("settings.shortcut.unavailable")
            }
        }
        refreshShortcutState()
        refreshFeedback()
    }

    private func refreshFeedback() {
        let feedback: Feedback?
        if let override = hotKeyController.environmentOverride {
            feedback = .formatted("settings.shortcut.override", override.rawValue)
        } else if let transientFeedback {
            feedback = transientFeedback
        } else if hotKeyController.lastError != nil {
            feedback = .key("settings.shortcut.unavailable")
        } else if loginItemController.requiresApproval {
            feedback = .key("settings.launch-at-login.approval")
        } else if let gestureError = gestureErrorProvider() {
            feedback = .formatted("settings.trackpad-gesture.unavailable", gestureError)
        } else if !loginItemController.isAvailable {
            feedback = .key("settings.launch-at-login.development")
        } else {
            feedback = nil
        }

        switch feedback {
        case .key(let key):
            feedbackLabel.stringValue = localizer.string(key)
        case .formatted(let key, let argument):
            feedbackLabel.stringValue = localizer.formatted(key, argument)
        case nil:
            feedbackLabel.stringValue = ""
        }
        feedbackLabel.isHidden = feedback == nil
    }

    @objc private func languageChanged(_ sender: NSPopUpButton) {
        guard let rawValue = sender.selectedItem?.representedObject as? String,
              let language = InterfaceLanguage(rawValue: rawValue) else { return }
        preferences.interfaceLanguage = language
    }

    @objc private func orderChanged(_ sender: NSPopUpButton) {
        guard let rawValue = sender.selectedItem?.representedObject as? String,
              let order = ApplicationSortOrder(rawValue: rawValue) else { return }
        preferences.applicationSortOrder = order
    }

    @objc private func gridDimensionChanged(_ sender: NSPopUpButton) {
        guard let value = sender.selectedItem?.representedObject as? Int else { return }
        if sender === columnsPopup {
            preferences.gridColumns = value
        } else {
            preferences.gridRows = value
        }
    }

    @objc private func hotCornerChanged(_ sender: NSPopUpButton) {
        guard let rawValue = sender.selectedItem?.representedObject as? String,
              let corner = HotCorner(rawValue: rawValue) else { return }
        preferences.hotCorner = corner
    }

    @objc private func unhideAll(_ sender: Any?) {
        preferences.unhideAllApplications()
        refreshApplicationCustomizationState()
    }

    @objc private func resetNames(_ sender: Any?) {
        preferences.resetCustomNames()
        refreshApplicationCustomizationState()
    }

    @objc private func addApplicationFolder(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = localizer.string("settings.app-folders.choose")
        NSApp.activate()
        guard panel.runModal() == .OK else { return }
        let paths = panel.urls.map(\.path)
        preferences.additionalApplicationFolders = preferences.additionalApplicationFolders + paths
        refreshApplicationCustomizationState()
    }

    @objc private func clearApplicationFolders(_ sender: Any?) {
        preferences.additionalApplicationFolders = []
        refreshApplicationCustomizationState()
    }

    @objc private func spotlightKeyChanged(_ sender: NSSwitch) {
        preferences.spotlightKeyOpensGridOS = sender.state == .on
    }

    @objc private func addGridOSToDock(_ sender: Any?) {
        onAddGridOSToDock?()
    }

    @objc private func clearShortcut(_ sender: Any?) {
        applyShortcut(.disabled)
    }

    @objc private func loginItemChanged(_ sender: NSSwitch) {
        let requested = sender.state == .on
        switch loginItemController.setEnabled(requested) {
        case .success(let actual):
            sender.state = actual ? .on : .off
            loginItemApprovalButton.isHidden = !loginItemController.requiresApproval
            transientFeedback = nil
        case .failure(let error):
            sender.state = loginItemController.isEnabled ? .on : .off
            transientFeedback = .formatted(
                "settings.launch-at-login.error",
                error.localizedDescription
            )
        }
        refreshFeedback()
    }

    @objc private func openLoginItemSettings(_ sender: Any?) {
        loginItemController.openSystemSettings()
    }

    @objc private func gestureChanged(_ sender: NSSwitch) {
        preferences.gestureEnabled = sender.state == .on
        transientFeedback = nil
        refreshFeedback()
    }

    @objc private func gestureFingerCountChanged(_ sender: NSPopUpButton) {
        guard let rawValue = sender.selectedItem?.representedObject as? Int,
              let fingerCount = GestureFingerCount(rawValue: rawValue) else { return }
        preferences.gestureFingerCount = fingerCount
        transientFeedback = nil
        refreshFeedback()
    }
}
