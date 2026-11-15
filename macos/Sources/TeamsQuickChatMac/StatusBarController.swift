import AppKit
import SwiftUI
import TeamsQuickChatCore

@MainActor
final class StatusBarController: NSObject {
    nonisolated static let togglePopoverNotification = Notification.Name("com.prathiraj.teamsquickchat.togglePopover")

    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let viewModel: ContactsViewModel

    init(viewModel: ContactsViewModel) {
        self.viewModel = viewModel
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.popover = NSPopover()
        super.init()

        configureStatusButton()
        configurePopover()
        observeExternalToggleRequests()

        viewModel.onContentHeightChanged = { [weak self] newHeight in
            guard let self else { return }
            self.popover.contentSize = NSSize(width: ContactsViewModel.popoverWidth, height: newHeight)
        }
    }

    func showPopoverOnLaunchIfAppropriate() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.showPopover()
        }
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            togglePopover()
            return
        }

        let isRightClick = event.type == .rightMouseUp || event.modifierFlags.contains(.control)
        if isRightClick {
            closePopover()
            presentContextMenu(from: sender)
        } else {
            togglePopover()
        }
    }

    func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    func showPopover() {
        guard let button = statusItem.button else { return }
        viewModel.refresh()
        popover.contentSize = NSSize(
            width: ContactsViewModel.popoverWidth,
            height: viewModel.preferredPopoverHeight
        )
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    func closePopover() {
        if popover.isShown {
            popover.performClose(nil)
        }
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else { return }
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        if let img = NSImage(
            systemSymbolName: "bubble.left.and.bubble.right.fill",
            accessibilityDescription: AppInfo.appName
        )?.withSymbolConfiguration(symbolConfig) {
            img.isTemplate = true
            button.image = img
        } else {
            button.title = "💬"
        }
        button.toolTip = AppInfo.appName
        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true

        let rootView = PopoverContentView(
            viewModel: viewModel,
            onAddTapped: { [weak self] in
                guard let self else { return }
                self.closePopover()
                AddContactWindowController.shared.show(viewModel: self.viewModel)
            },
            onSettingsTapped: { [weak self] in
                guard let self else { return }
                self.closePopover()
                SettingsWindowController.shared.show(viewModel: self.viewModel)
            },
            onOpenContact: { [weak self] contact in
                AppActions.openContact(contact) {
                    self?.closePopover()
                }
            },
            onPinToDock: { [weak self] contact in
                AppActions.pinContactToDock(contact) {
                    self?.closePopover()
                }
            },
            onCheckUpdates: { [weak self] in
                self?.closePopover()
                AppActions.checkForUpdates(showUpToDate: true)
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )

        let controller = NSHostingController(rootView: rootView)
        popover.contentViewController = controller
        popover.contentSize = NSSize(
            width: ContactsViewModel.popoverWidth,
            height: viewModel.preferredPopoverHeight
        )
    }

    private func presentContextMenu(from button: NSStatusBarButton) {
        LaunchAtLoginManager.shared.refreshStatus()

        let menu = NSMenu()

        let openItem = NSMenuItem(
            title: "Open \(AppInfo.appName)",
            action: #selector(menuOpenPopover),
            keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(openItem)

        let addItem = NSMenuItem(
            title: "Add Contact…",
            action: #selector(menuAddContact),
            keyEquivalent: ""
        )
        addItem.target = self
        menu.addItem(addItem)

        menu.addItem(.separator())

        let loginItem = NSMenuItem(
            title: "Start at Login",
            action: #selector(menuToggleLaunchAtLogin),
            keyEquivalent: ""
        )
        loginItem.target = self
        loginItem.state = LaunchAtLoginManager.shared.isEnabled ? .on : .off
        menu.addItem(loginItem)

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(menuOpenSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let updateItem = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(menuCheckUpdates),
            keyEquivalent: ""
        )
        updateItem.target = self
        menu.addItem(updateItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit \(AppInfo.appName)",
            action: #selector(menuQuit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        button.performClick(nil)
        statusItem.menu = nil
    }

    private func observeExternalToggleRequests() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleExternalToggleNotification(_:)),
            name: Self.togglePopoverNotification,
            object: nil
        )
    }

    @objc private func handleExternalToggleNotification(_ notification: Notification) {
        Task { @MainActor in
            showPopover()
        }
    }

    @objc private func menuOpenPopover() {
        showPopover()
    }

    @objc private func menuAddContact() {
        AddContactWindowController.shared.show(viewModel: viewModel)
    }

    @objc private func menuToggleLaunchAtLogin() {
        do {
            try LaunchAtLoginManager.shared.setEnabled(!LaunchAtLoginManager.shared.isEnabled)
        } catch {
            AppAlerts.showWarning(title: AppInfo.appName, message: error.localizedDescription)
        }
    }

    @objc private func menuOpenSettings() {
        SettingsWindowController.shared.show(viewModel: viewModel)
    }

    @objc private func menuCheckUpdates() {
        AppActions.checkForUpdates(showUpToDate: true)
    }

    @objc private func menuQuit() {
        NSApp.terminate(nil)
    }
}
