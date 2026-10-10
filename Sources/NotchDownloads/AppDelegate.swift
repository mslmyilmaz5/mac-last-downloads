import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var viewModel: NotchViewModel!
    private var panelController: NotchPanelController!
    private var statusItem: NSStatusItem!
    private var launchAtLoginItem: NSMenuItem!
    private var permissionItem: NSMenuItem!

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
            title: "İndirilenleri Göster",
            action: #selector(showPanel),
            keyEquivalent: ""
        )
        showItem.target = self
        menu.addItem(showItem)

        permissionItem = NSMenuItem(
            title: "İndirilenlere Erişim İzni Ver…",
            action: #selector(openPrivacySettings),
            keyEquivalent: ""
        )
        permissionItem.target = self
        permissionItem.isHidden = true
        menu.addItem(permissionItem)

        menu.addItem(.separator())

        launchAtLoginItem = NSMenuItem(
            title: "Oturum Açılışında Başlat",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)

        menu.addItem(.separator())

        let downloadsItem = NSMenuItem(
            title: "İndirilenler Klasörünü Aç",
            action: #selector(openDownloads),
            keyEquivalent: ""
        )
        downloadsItem.target = self
        menu.addItem(downloadsItem)

        let quitItem = NSMenuItem(
            title: "Notch Downloads'tan Çık",
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

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Oturum açılışı ayarlanamadı"
            alert.informativeText = "Bu özellik yalnızca uygulama .app paketi olarak çalıştırıldığında kullanılabilir. (`make run` ile başlatın.)\n\n\(error.localizedDescription)"
            alert.alertStyle = .warning
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        permissionItem.isHidden = !viewModel.permissionDenied
    }
}
