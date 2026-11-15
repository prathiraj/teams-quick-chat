import AppKit
import Foundation
import TeamsQuickChatCore

@MainActor
enum AppAlerts {
    static func showInfo(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    static func showWarning(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

@MainActor
enum AppActions {
    private static var isCheckingUpdates = false

    static func openContact(_ contact: Contact, onSuccess: (() -> Void)? = nil) {
        do {
            try TeamsDeepLink.open(contact)
            onSuccess?()
        } catch {
            AppAlerts.showWarning(title: AppInfo.appName, message: error.localizedDescription)
        }
    }

    static func pinContactToDock(_ contact: Contact, closePopover: (() -> Void)? = nil) {
        closePopover?()
        do {
            let shortcut = try DockPinning.createShortcutApp(for: contact)

            if DockPinning.isPinnedInDock(shortcut) {
                NSApp.activate(ignoringOtherApps: true)
                let alert = NSAlert()
                alert.alertStyle = .informational
                alert.messageText = "\"\(shortcut.displayName)\" is already in your Dock"
                alert.informativeText = "The chat shortcut was refreshed in ~/Applications/Teams Quick Chat Shortcuts."
                alert.addButton(withTitle: "OK")
                alert.addButton(withTitle: "Show in Finder")
                if alert.runModal() == .alertSecondButtonReturn {
                    DockPinning.revealInFinder(shortcut.appURL)
                }
                return
            }

            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = "Pin \"\(shortcut.displayName)\" to Dock?"
            alert.informativeText =
                "Adds a direct Microsoft Teams chat icon for \(shortcut.displayName) to your Dock " +
                "(and makes it searchable in Spotlight). Remove anytime via Right-Click → Options → Remove from Dock."
            alert.addButton(withTitle: "Add to Dock")
            alert.addButton(withTitle: "Show in Finder")
            alert.addButton(withTitle: "Cancel")

            let response = alert.runModal()
            switch response {
            case .alertFirstButtonReturn:
                do {
                    _ = try DockPinning.addToDock(shortcut)
                } catch {
                    let fallback = NSAlert()
                    fallback.alertStyle = .warning
                    fallback.messageText = "Drag Shortcut to Dock"
                    fallback.informativeText =
                        "\(error.localizedDescription)\n\n" +
                        "The shortcut was created in Finder — drag \"\(shortcut.displayName)\" onto your Dock to pin it."
                    fallback.addButton(withTitle: "Show in Finder")
                    fallback.runModal()
                    DockPinning.revealInFinder(shortcut.appURL)
                }
            case .alertSecondButtonReturn:
                DockPinning.revealInFinder(shortcut.appURL)
            default:
                break
            }
        } catch {
            AppAlerts.showWarning(title: "Pin to Dock", message: error.localizedDescription)
        }
    }

    static func checkForUpdates(showUpToDate: Bool) {
        guard !isCheckingUpdates else { return }
        isCheckingUpdates = true

        Task { @MainActor in
            defer { isCheckingUpdates = false }

            guard let (newVersion, release) = await UpdateChecker.check() else {
                if showUpToDate {
                    AppAlerts.showInfo(
                        title: "You’re Up to Date",
                        message: "\(AppInfo.appName) v\(AppInfo.version) is currently the newest version available."
                    )
                }
                return
            }

            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = "Update Available"
            alert.informativeText =
                "A new version of \(AppInfo.appName) is available!\n\n" +
                "Current: v\(AppInfo.version)\n" +
                "Latest: v\(newVersion)\n\n" +
                "Would you like to download and open the macOS installer?"
            alert.addButton(withTitle: "Download Update")
            alert.addButton(withTitle: "Later")

            guard alert.runModal() == .alertFirstButtonReturn else { return }

            let ok = await UpdateChecker.downloadAndOpenInstaller(from: release)
            if !ok {
                AppAlerts.showWarning(
                    title: "Update Download",
                    message: "Opening the GitHub Releases page so you can download v\(newVersion) directly."
                )
                NSWorkspace.shared.open(AppInfo.releasesPageURL)
            }
        }
    }
}
