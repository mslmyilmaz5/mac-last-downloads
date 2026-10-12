import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var viewModel: NotchViewModel!
    private var panelController: NotchPanelController!
    private var statusItem: NSStatusItem!
    private var launchAtLoginItem: NSMenuItem!
    private var permissionItem: NSMenuItem!
    private var instantScreenshotItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        viewModel = NotchViewModel()
        panelController = NotchPanelController(viewModel: viewModel)
        panelController.show()
        viewModel.start()
        setupStatusItem()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    // MARK: - Menü çubuğu

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "arrow.down.circle",
            accessibilityDescription: "Notch Downloads"
        )

        let menu = NSMenu()
        menu.delegate = self

        let showItem = NSMenuItem(
            title: "Show Downloads",
            action: #selector(showPanel),
            keyEquivalent: ""
        )
        showItem.target = self
        menu.addItem(showItem)

        permissionItem = NSMenuItem(
            title: "Allow Downloads Access…",
            action: #selector(openPrivacySettings),
            keyEquivalent: ""
        )
        permissionItem.target = self
        permissionItem.isHidden = true
        menu.addItem(permissionItem)

        menu.addItem(.separator())

        instantScreenshotItem = NSMenuItem(
            title: "Show Screenshots Instantly",
            action: #selector(toggleInstantScreenshots),
            keyEquivalent: ""
        )
        instantScreenshotItem.target = self
        instantScreenshotItem.toolTip = "Turns off the system floating thumbnail so a screenshot is saved and appears here as soon as you take it."
        menu.addItem(instantScreenshotItem)

        launchAtLoginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)

        menu.addItem(.separator())

        let downloadsItem = NSMenuItem(
            title: "Open Downloads Folder",
            action: #selector(openDownloads),
            keyEquivalent: ""
        )
        downloadsItem.target = self
        menu.addItem(downloadsItem)

        let quitItem = NSMenuItem(
            title: "Quit Notch Downloads",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func showPanel() {
        viewModel.expandTemporarily()
    }

    @objc private func openPrivacySettings() {
        viewModel.openPrivacySettings()
    }

    @objc private func openDownloads() {
        viewModel.openDownloadsFolder()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func toggleInstantScreenshots() {
        ScreenshotSettings.setInstantSave(!ScreenshotSettings.isInstantSaveEnabled)
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn’t Set Launch at Login"
            alert.informativeText = "This option is only available when the app is running as an .app bundle. Launch it with `make run`.\n\n\(error.localizedDescription)"
            alert.alertStyle = .warning
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        instantScreenshotItem.state = ScreenshotSettings.isInstantSaveEnabled ? .on : .off
        launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        permissionItem.isHidden = !viewModel.permissionDenied
    }
}
