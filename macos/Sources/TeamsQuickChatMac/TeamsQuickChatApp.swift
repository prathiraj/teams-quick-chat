import AppKit
import Foundation
import TeamsQuickChatCore

@main
enum TeamsQuickChatMain {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())

        if args.first == "--remove-dock-pins" {
            DockPinning.removeAllShortcuts()
            return
        }

        if args.count >= 2, args[0] == "--generate-app-icon" {
            do {
                let outputURL = URL(fileURLWithPath: args[1])
                try IconGenerator.generateAppIconICNS(to: outputURL)
                return
            } catch {
                fputs("Failed to generate AppIcon.icns: \(error.localizedDescription)\n", stderr)
                exit(1)
            }
        }

        if let pinnedURI = resolvePinnedChatLaunchURI(args: args) {
            runPinnedChatShortcut(uri: pinnedURI)
            return
        }

        if notifyAlreadyRunningInstance() {
            return
        }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    private static func resolvePinnedChatLaunchURI(args: [String]) -> String? {
        if args.count >= 2, args[0] == "--open-pinned-chat" {
            return args[1]
        }
        if let bundleURI = Bundle.main.object(forInfoDictionaryKey: AppInfo.pinnedChatURIInfoKey) as? String,
           !bundleURI.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return bundleURI
        }
        return nil
    }

    private static func runPinnedChatShortcut(uri: String) {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        do {
            _ = try TeamsDeepLink.openPinnedChat(uri)
        } catch {
            Task { @MainActor in
                AppAlerts.showWarning(title: AppInfo.appName, message: error.localizedDescription)
                exit(1)
            }
            app.run()
        }
    }

    private static func notifyAlreadyRunningInstance() -> Bool {
        guard Bundle.main.bundleIdentifier == AppInfo.bundleIdentifier else {
            return false
        }
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: AppInfo.bundleIdentifier)
            .filter { $0.processIdentifier != currentPID && !$0.isTerminated }

        guard !others.isEmpty else { return false }

        DistributedNotificationCenter.default().postNotificationName(
            StatusBarController.togglePopoverNotification,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
        return true
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var viewModel: ContactsViewModel!
    private var statusBarController: StatusBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        installStandardMenus()
        viewModel = ContactsViewModel()
        statusBarController = StatusBarController(viewModel: viewModel)
        statusBarController.showPopoverOnLaunchIfAppropriate()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusBarController?.showPopover()
        return true
    }

    @objc private func openSettingsFromMenu() {
        SettingsWindowController.shared.show(viewModel: viewModel)
    }

    private func installStandardMenus() {
        let mainMenu = NSMenu()

        // Application Menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettingsFromMenu),
            keyEquivalent: ","
        )
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "Quit \(AppInfo.appName)",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // Edit Menu (essential so Cmd+C / Cmd+V / Cmd+X / Cmd+A / Cmd+Z work in LSUIElement text fields)
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // Window Menu (supports Cmd+W to close Settings / Add Contact windows)
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApp.mainMenu = mainMenu
    }
}
