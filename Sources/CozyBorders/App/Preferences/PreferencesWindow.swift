import AppKit
import KnitCore
import ServiceManagement

/// Border width, stitch size, per-app pattern and palette overrides, exclusions, login item.
final class PreferencesWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private let store: PreferencesStore

    private let enabledCheckbox = NSButton(checkboxWithTitle: "Knit borders around windows", target: nil, action: nil)
    private let loginCheckbox = NSButton(checkboxWithTitle: "Open at login", target: nil, action: nil)
    private let orderingPopup = NSPopUpButton()
    private let borderWidth = LabeledSlider(min: 6, max: 30, format: "%.0f pt")
    private let stitchWidth = LabeledSlider(min: 3, max: 10, format: "%.1f pt")
    private let stitchHeight = LabeledSlider(min: 2.5, max: 8, format: "%.1f pt")
    private let cornerRadius = LabeledSlider(min: 0, max: 30, format: "%.0f pt")

    private let appPopup = NSPopUpButton()
    private let patternPopup = NSPopUpButton()
    private let customColorsCheckbox = NSButton(checkboxWithTitle: "Custom yarn colours", target: nil, action: nil)
    private let colorWells = (0..<3).map { _ in NSColorWell(style: .minimal) }
    private let excludeCheckbox = NSButton(checkboxWithTitle: "Don't knit borders for this app", target: nil, action: nil)

    private let excludedTable = NSTableView()
    private let removeExcludedButton = NSButton(title: "Remove", target: nil, action: nil)

    /// Bundle IDs listed in the app popup, parallel to its items.
    private var appBundleIDs: [String] = []

    init(store: PreferencesStore) {
        self.store = store
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 640),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Cozy Borders Preferences"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildUI()
        reload()
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func showWindow(_ sender: Any?) {
        reloadApps()
        reload()
        super.showWindow(sender)
    }

    // MARK: Layout

    private func buildUI() {
        for mode in OrderingMode.allCases {
            orderingPopup.addItem(withTitle: mode.displayName)
            orderingPopup.lastItem?.representedObject = mode.rawValue
        }

        enabledCheckbox.target = self; enabledCheckbox.action = #selector(changed)
        loginCheckbox.target = self; loginCheckbox.action = #selector(toggleLogin)
        orderingPopup.target = self; orderingPopup.action = #selector(changed)
        for slider in [borderWidth, stitchWidth, stitchHeight, cornerRadius] {
            slider.onChange = { [weak self] in self?.changed() }
        }

        appPopup.target = self; appPopup.action = #selector(appSelectionChanged)
        patternPopup.target = self; patternPopup.action = #selector(appSettingsChanged)
        customColorsCheckbox.target = self; customColorsCheckbox.action = #selector(appSettingsChanged)
        excludeCheckbox.target = self; excludeCheckbox.action = #selector(appSettingsChanged)
        for well in colorWells {
            well.target = self
            well.action = #selector(appSettingsChanged)
            well.widthAnchor.constraint(equalToConstant: 44).isActive = true
        }

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("app"))
        column.title = "Excluded apps"
        excludedTable.addTableColumn(column)
        excludedTable.headerView = nil
        excludedTable.dataSource = self
        excludedTable.delegate = self
        excludedTable.usesAlternatingRowBackgroundColors = true
        let scroll = NSScrollView()
        scroll.documentView = excludedTable
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.heightAnchor.constraint(equalToConstant: 90).isActive = true
        removeExcludedButton.target = self
        removeExcludedButton.action = #selector(removeExcluded)

        let general = grid([
            [NSView(), enabledCheckbox],
            [NSView(), loginCheckbox],
            [label("Stacking:"), orderingPopup],
        ])
        let knit = grid([
            [label("Border width:"), borderWidth],
            [label("Stitch width:"), stitchWidth],
            [label("Stitch height:"), stitchHeight],
            [label("Window corners:"), cornerRadius],
        ])
        let wells = NSStackView(views: colorWells)
        wells.spacing = 8
        let perApp = grid([
            [label("App:"), appPopup],
            [label("Pattern:"), patternPopup],
            [NSView(), customColorsCheckbox],
            [NSView(), wells],
            [NSView(), excludeCheckbox],
        ])

        let excludedRow = NSStackView(views: [scroll, removeExcludedButton])
        excludedRow.alignment = .top

        let stackingNote = NSTextField(wrappingLabelWithString: """
        All Windows keeps borders beneath every window using public API; where two windows \
        overlap, a border can hide behind the window in front of its own. Exact Stacking uses \
        private macOS API to fix that and may stop working after a macOS update.
        """)
        stackingNote.font = .systemFont(ofSize: 11)
        stackingNote.textColor = .secondaryLabelColor
        stackingNote.preferredMaxLayoutWidth = 460

        let stack = NSStackView(views: [
            section("General"), general, stackingNote,
            section("Knitting"), knit,
            section("Per App"), perApp,
            section("Excluded Apps"), excludedRow,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false
        excludedRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -48).isActive = true

        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor),
        ])
        window?.contentView = content
        window?.setContentSize(stack.fittingSize)
    }

    private func grid(_ rows: [[NSView]]) -> NSGridView {
        let grid = NSGridView(views: rows)
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 0).width = 110
        grid.rowSpacing = 8
        grid.columnSpacing = 10
        for i in 0..<grid.numberOfRows { grid.row(at: i).yPlacement = .center }
        return grid
    }

    private func label(_ text: String) -> NSTextField {
        NSTextField(labelWithString: text)
    }

    private func section(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: 13, weight: .semibold)
        return field
    }

    // MARK: Model -> UI

    func reload() {
        let prefs = store.preferences
        enabledCheckbox.state = prefs.enabled ? .on : .off
        loginCheckbox.state = SMAppService.mainApp.status == .enabled ? .on : .off
        orderingPopup.selectItem(at: OrderingMode.allCases.firstIndex(of: prefs.ordering) ?? 0)
        borderWidth.value = prefs.borderWidth
        stitchWidth.value = prefs.stitchWidth
        stitchHeight.value = prefs.stitchHeight
        cornerRadius.value = prefs.windowCornerRadius
        excludedTable.reloadData()
        removeExcludedButton.isEnabled = !prefs.excludedBundleIDs.isEmpty
        reloadAppSettings()
    }

    private func reloadApps() {
        let prefs = store.preferences
        var entries: [String: String] = [:]
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            if let id = app.bundleIdentifier, app.processIdentifier != getpid() {
                entries[id] = app.localizedName ?? id
            }
        }
        for id in Array(prefs.patternOverrides.keys) + Array(prefs.paletteOverrides.keys) + prefs.excludedBundleIDs where entries[id] == nil {
            entries[id] = Self.name(forBundleID: id)
        }
        let selected = selectedBundleID
        let sorted = entries.sorted { $0.value.localizedCaseInsensitiveCompare($1.value) == .orderedAscending }
        appBundleIDs = sorted.map(\.key)
        appPopup.removeAllItems()
        for (id, name) in sorted {
            appPopup.addItem(withTitle: name)
            appPopup.lastItem?.toolTip = id
        }
        if let selected, let index = appBundleIDs.firstIndex(of: selected) {
            appPopup.selectItem(at: index)
        }
    }

    private var selectedBundleID: String? {
        let index = appPopup.indexOfSelectedItem
        return appBundleIDs.indices.contains(index) ? appBundleIDs[index] : nil
    }

    private func reloadAppSettings() {
        let prefs = store.preferences
        let controls: [NSControl] = [patternPopup, customColorsCheckbox, excludeCheckbox] + colorWells
        guard let bundleID = selectedBundleID else {
            controls.forEach { $0.isEnabled = false }
            return
        }
        controls.forEach { $0.isEnabled = true }

        patternPopup.removeAllItems()
        patternPopup.addItem(withTitle: "Automatic (\(PatternID.assigned(toBundleID: bundleID).displayName))")
        for pattern in PatternID.allCases {
            patternPopup.addItem(withTitle: pattern.displayName)
            patternPopup.lastItem?.representedObject = pattern.rawValue
        }
        if let override = prefs.patternOverrides[bundleID], let index = PatternID.allCases.firstIndex(of: override) {
            patternPopup.selectItem(at: index + 1)
        } else {
            patternPopup.selectItem(at: 0)
        }

        let override = prefs.paletteOverride(forBundleID: bundleID)
        customColorsCheckbox.state = override == nil ? .off : .on
        let shown = override ?? iconPalette(for: bundleID)
        for (well, color) in zip(colorWells, shown.colors) {
            well.color = NSColor(cgColor: color.cgColor) ?? .gray
            well.isEnabled = override != nil
        }
        excludeCheckbox.state = prefs.excludedBundleIDs.contains(bundleID) ? .on : .off
    }

    private func iconPalette(for bundleID: String) -> YarnPalette {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
            return PaletteExtractor.palette(forPID: app.processIdentifier)
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
           let pixels = IconSampler.pixels(for: NSWorkspace.shared.icon(forFile: url.path)) {
            return PaletteExtractor.palette(from: pixels)
        }
        return .undyed
    }

    private static func name(forBundleID id: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return id }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    // MARK: UI -> Model

    @objc private func changed() {
        let mode = (orderingPopup.selectedItem?.representedObject as? String).flatMap(OrderingMode.init(rawValue:)) ?? .belowAll
        store.update { prefs in
            prefs.enabled = enabledCheckbox.state == .on
            prefs.ordering = mode
            prefs.borderWidth = borderWidth.value.rounded()
            prefs.stitchWidth = (stitchWidth.value * 2).rounded() / 2
            prefs.stitchHeight = (stitchHeight.value * 2).rounded() / 2
            prefs.windowCornerRadius = cornerRadius.value.rounded()
        }
    }

    @objc private func appSelectionChanged() {
        reloadAppSettings()
    }

    @objc private func appSettingsChanged() {
        guard let bundleID = selectedBundleID else { return }
        let pattern = (patternPopup.selectedItem?.representedObject as? String).flatMap(PatternID.init(rawValue:))
        let useCustom = customColorsCheckbox.state == .on
        let hexes = colorWells.map { well -> String in
            let c = well.color.usingColorSpace(.sRGB) ?? .gray
            return YarnColor(r: c.redComponent, g: c.greenComponent, b: c.blueComponent).hex
        }
        let exclude = excludeCheckbox.state == .on
        store.update { prefs in
            prefs.patternOverrides[bundleID] = pattern
            prefs.paletteOverrides[bundleID] = useCustom ? hexes : nil
            if exclude, !prefs.excludedBundleIDs.contains(bundleID) {
                prefs.excludedBundleIDs.append(bundleID)
            } else if !exclude {
                prefs.excludedBundleIDs.removeAll { $0 == bundleID }
            }
        }
        reloadAppSettings()
    }

    @objc private func removeExcluded() {
        let row = excludedTable.selectedRow
        let ids = store.preferences.excludedBundleIDs
        guard ids.indices.contains(row) else { return }
        store.update { $0.excludedBundleIDs.remove(at: row) }
    }

    @objc private func toggleLogin() {
        do {
            if loginCheckbox.state == .on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.informativeText = "Open at login needs Cozy Borders to run from its app bundle, ideally in /Applications. (\(error.localizedDescription))"
            alert.runModal()
        }
        loginCheckbox.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    // MARK: Table

    func numberOfRows(in tableView: NSTableView) -> Int {
        store.preferences.excludedBundleIDs.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = store.preferences.excludedBundleIDs[row]
        let field = NSTextField(labelWithString: "\(Self.name(forBundleID: id))  —  \(id)")
        field.lineBreakMode = .byTruncatingTail
        return field
    }
}

/// A slider with a live value readout.
final class LabeledSlider: NSStackView {
    var onChange: (() -> Void)?
    private let slider = NSSlider()
    private let readout = NSTextField(labelWithString: "")
    private let format: String

    init(min: Double, max: Double, format: String) {
        self.format = format
        super.init(frame: .zero)
        slider.minValue = min
        slider.maxValue = max
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(slid)
        slider.widthAnchor.constraint(equalToConstant: 240).isActive = true
        readout.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        readout.widthAnchor.constraint(equalToConstant: 60).isActive = true
        addArrangedSubview(slider)
        addArrangedSubview(readout)
        spacing = 8
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    var value: Double {
        get { slider.doubleValue }
        set {
            slider.doubleValue = newValue
            readout.stringValue = String(format: format, newValue)
        }
    }

    @objc private func slid() {
        readout.stringValue = String(format: format, slider.doubleValue)
        onChange?()
    }
}
