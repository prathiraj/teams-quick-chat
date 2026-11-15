import AppKit
import CoreServices
import CryptoKit
import Foundation

public struct DockShortcutApp: Equatable, Sendable {
    public let appURL: URL
    public let bundleIdentifier: String
    public let displayName: String
    public let chatURI: String

    public init(appURL: URL, bundleIdentifier: String, displayName: String, chatURI: String) {
        self.appURL = appURL
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.chatURI = chatURI
    }
}

public enum DockPinningError: LocalizedError, Equatable {
    case executableNotFound
    case unsupportedChatURI
    case shortcutCreationFailed(String)
    case dockLocked
    case dockUpdateFailed(String)

    public var errorDescription: String? {
        switch self {
        case .executableNotFound:
            return "Teams Quick Chat could not locate its executable to create the Dock shortcut."
        case .unsupportedChatURI:
            return "This contact does not have a valid Microsoft Teams chat link."
        case .shortcutCreationFailed(let detail):
            return "Could not create the chat shortcut app: \(detail)"
        case .dockLocked:
            return "Your macOS Dock is locked by system settings or an organization profile. Use 'Show in Finder' to keep the shortcut elsewhere."
        case .dockUpdateFailed(let detail):
            return "Could not add the shortcut to the Dock automatically: \(detail)"
        }
    }
}

public enum DockPinning {
    private static let dockDomain: CFString = "com.apple.dock" as CFString
    private static let persistentAppsKey: CFString = "persistent-apps" as CFString
    private static let contentsImmutableKey: CFString = "contents-immutable" as CFString
    private static let hashByteCount = 12

    public static func defaultShortcutsDirectory(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        homeDirectory
            .appendingPathComponent("Applications", isDirectory: true)
            .appendingPathComponent("Teams Quick Chat Shortcuts", isDirectory: true)
    }

    public static func computeTargetHash(for chatURI: String) -> String {
        let digest = SHA256.hash(data: Data(chatURI.utf8))
        return digest.prefix(hashByteCount).map { String(format: "%02x", $0) }.joined()
    }

    public static func bundleIdentifier(forChatURI chatURI: String) -> String {
        AppInfo.chatShortcutBundlePrefix + computeTargetHash(for: chatURI)
    }

    public static func isValidShortcutBundleIdentifier(_ bundleId: String) -> Bool {
        guard bundleId.hasPrefix(AppInfo.chatShortcutBundlePrefix) else { return false }
        let suffix = bundleId.dropFirst(AppInfo.chatShortcutBundlePrefix.count)
        guard suffix.count == hashByteCount * 2 else { return false }
        return suffix.allSatisfy { $0.isHexDigit }
    }

    public static func normalizeDisplayName(_ rawName: String) -> String {
        let filtered = rawName.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }
        let trimmed = String(String.UnicodeScalarView(filtered)).trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Teams Chat"
        }
        if trimmed.count > 80 {
            return String(trimmed.prefix(80)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }

    public static func sanitizeBundleFileName(_ displayName: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "/:\\?%*|\"<>")
            .union(.controlCharacters)
        let scalars = displayName.unicodeScalars.map { invalidChars.contains($0) ? UnicodeScalar(" ") : $0 }
        let collapsed = String(String.UnicodeScalarView(scalars))
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))

        if collapsed.isEmpty {
            return "Teams Chat"
        }
        if collapsed.count > 64 {
            return String(collapsed.prefix(64)).trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        }
        return collapsed
    }

    public static func createShortcutApp(
        for contact: Contact,
        executableURL: URL? = Bundle.main.executableURL,
        shortcutsDirectory: URL? = nil,
        signBundle: Bool = true
    ) throws -> DockShortcutApp {
        guard let sourceExecutable = executableURL,
              FileManager.default.isExecutableFile(atPath: sourceExecutable.path) else {
            throw DockPinningError.executableNotFound
        }

        let chatURI = try TeamsDeepLink.getURI(for: contact)
        guard TeamsDeepLink.isSupportedChatURI(chatURI) else {
            throw DockPinningError.unsupportedChatURI
        }

        let hash = computeTargetHash(for: chatURI)
        let bundleId = AppInfo.chatShortcutBundlePrefix + hash
        let displayName = normalizeDisplayName(contact.name)
        let safeFileName = sanitizeBundleFileName(displayName)
        let baseDir = shortcutsDirectory ?? defaultShortcutsDirectory()

        let fm = FileManager.default
        do {
            try fm.createDirectory(at: baseDir, withIntermediateDirectories: true)

            let appURL = resolveShortcutBundleURL(
                in: baseDir,
                safeFileName: safeFileName,
                bundleIdentifier: bundleId,
                hash: hash
            )

            let contentsDir = appURL.appendingPathComponent("Contents", isDirectory: true)
            let macOSDir = contentsDir.appendingPathComponent("MacOS", isDirectory: true)
            let resourcesDir = contentsDir.appendingPathComponent("Resources", isDirectory: true)

            try fm.createDirectory(at: macOSDir, withIntermediateDirectories: true)
            try fm.createDirectory(at: resourcesDir, withIntermediateDirectories: true)

            let launcherName = "TeamsQuickChatShortcut"
            let destExecutable = macOSDir.appendingPathComponent(launcherName, isDirectory: false)
            if fm.fileExists(atPath: destExecutable.path) {
                try fm.removeItem(at: destExecutable)
            }
            try fm.copyItem(at: sourceExecutable, to: destExecutable)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destExecutable.path)

            let iconURL = resourcesDir.appendingPathComponent("ShortcutIcon.icns", isDirectory: false)
            try IconGenerator.generateContactShortcutICNS(
                initials: contact.initials,
                isGroupChat: contact.isTeamsLink,
                to: iconURL
            )

            let infoPlist: [String: Any] = [
                "CFBundleDevelopmentRegion": "en",
                "CFBundleDisplayName": displayName,
                "CFBundleExecutable": launcherName,
                "CFBundleIconFile": "ShortcutIcon",
                "CFBundleIdentifier": bundleId,
                "CFBundleInfoDictionaryVersion": "6.0",
                "CFBundleName": displayName,
                "CFBundlePackageType": "APPL",
                "CFBundleShortVersionString": AppInfo.version,
                "CFBundleVersion": AppInfo.version,
                "LSMinimumSystemVersion": "13.0",
                "LSUIElement": true,
                "NSHighResolutionCapable": true,
                AppInfo.pinnedChatURIInfoKey: chatURI
            ]
            let plistData = try PropertyListSerialization.data(
                fromPropertyList: infoPlist,
                format: .xml,
                options: 0
            )
            try plistData.write(to: contentsDir.appendingPathComponent("Info.plist"), options: [.atomic])
            try Data("APPL????".utf8).write(to: contentsDir.appendingPathComponent("PkgInfo"), options: [.atomic])

            if signBundle {
                try adHocCodeSign(bundleURL: appURL)
            }

            LSRegisterURL(appURL as CFURL, true)

            return DockShortcutApp(
                appURL: appURL,
                bundleIdentifier: bundleId,
                displayName: displayName,
                chatURI: chatURI
            )
        } catch let error as DockPinningError {
            throw error
        } catch {
            throw DockPinningError.shortcutCreationFailed(error.localizedDescription)
        }
    }

    public static func buildDockTileDictionary(for shortcut: DockShortcutApp) -> [String: Any] {
        var urlString = shortcut.appURL.standardizedFileURL.absoluteString
        if !urlString.hasSuffix("/") {
            urlString += "/"
        }
        return [
            "tile-type": "file-tile",
            "tile-data": [
                "bundle-identifier": shortcut.bundleIdentifier,
                "file-label": shortcut.displayName,
                "file-type": 41,
                "file-data": [
                    "_CFURLString": urlString,
                    "_CFURLStringType": 15
                ]
            ]
        ]
    }

    public static func isPinnedInDock(_ shortcut: DockShortcutApp) -> Bool {
        guard let rawApps = CFPreferencesCopyAppValue(persistentAppsKey, dockDomain) as? [[String: Any]] else {
            return false
        }
        return dockEntriesContain(rawApps, shortcut: shortcut)
    }

    public static func dockEntriesContain(_ entries: [[String: Any]], shortcut: DockShortcutApp) -> Bool {
        let normalizedTargetPath = shortcut.appURL.standardizedFileURL.path
        for entry in entries {
            guard let tileData = entry["tile-data"] as? [String: Any] else { continue }
            if let bundleId = tileData["bundle-identifier"] as? String,
               bundleId == shortcut.bundleIdentifier {
                return true
            }
            if let fileData = tileData["file-data"] as? [String: Any],
               let urlStr = fileData["_CFURLString"] as? String,
               let entryURL = URL(string: urlStr),
               entryURL.standardizedFileURL.path == normalizedTargetPath {
                return true
            }
        }
        return false
    }

    /// Adds the shortcut `.app` to the macOS Dock if not already pinned.
    /// Returns `true` if newly added, `false` if already present in the Dock.
    @discardableResult
    public static func addToDock(_ shortcut: DockShortcutApp) throws -> Bool {
        if let immutable = CFPreferencesCopyAppValue(contentsImmutableKey, dockDomain) as? Bool,
           immutable {
            throw DockPinningError.dockLocked
        }

        var apps = (CFPreferencesCopyAppValue(persistentAppsKey, dockDomain) as? [[String: Any]]) ?? []
        if dockEntriesContain(apps, shortcut: shortcut) {
            return false
        }

        apps.append(buildDockTileDictionary(for: shortcut))
        CFPreferencesSetAppValue(persistentAppsKey, apps as CFArray, dockDomain)
        guard CFPreferencesAppSynchronize(dockDomain) else {
            throw DockPinningError.dockUpdateFailed("macOS preferences could not synchronize Dock settings.")
        }

        restartDock()
        return true
    }

    public static func revealInFinder(_ appURL: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([appURL])
    }

    public static func removeAllShortcuts(shortcutsDirectory: URL? = nil, updateDock: Bool = true) {
        let dir = shortcutsDirectory ?? defaultShortcutsDirectory()
        let fm = FileManager.default
        if fm.fileExists(atPath: dir.path) {
            try? fm.removeItem(at: dir)
        }

        guard updateDock,
              let apps = CFPreferencesCopyAppValue(persistentAppsKey, dockDomain) as? [[String: Any]] else {
            return
        }

        let filtered = apps.filter { entry in
            guard let tileData = entry["tile-data"] as? [String: Any],
                  let bundleId = tileData["bundle-identifier"] as? String else {
                return true
            }
            return !bundleId.hasPrefix(AppInfo.chatShortcutBundlePrefix)
        }

        if filtered.count != apps.count {
            CFPreferencesSetAppValue(persistentAppsKey, filtered as CFArray, dockDomain)
            _ = CFPreferencesAppSynchronize(dockDomain)
            restartDock()
        }
    }

    private static func resolveShortcutBundleURL(
        in directory: URL,
        safeFileName: String,
        bundleIdentifier: String,
        hash: String
    ) -> URL {
        let primary = directory.appendingPathComponent("\(safeFileName).app", isDirectory: true)
        let infoPlistURL = primary.appendingPathComponent("Contents/Info.plist", isDirectory: false)

        if !FileManager.default.fileExists(atPath: primary.path) {
            return primary
        }

        if let data = try? Data(contentsOf: infoPlistURL),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
           let existingId = plist["CFBundleIdentifier"] as? String,
           existingId == bundleIdentifier {
            return primary
        }

        return directory.appendingPathComponent("\(safeFileName) (\(hash.prefix(6))).app", isDirectory: true)
    }

    private static func adHocCodeSign(bundleURL: URL) throws {
        let codesignURL = URL(fileURLWithPath: "/usr/bin/codesign")
        guard FileManager.default.isExecutableFile(atPath: codesignURL.path) else { return }

        let process = Process()
        process.executableURL = codesignURL
        process.arguments = ["--force", "--deep", "--sign", "-", bundleURL.path]
        let stderr = Pipe()
        process.standardError = stderr
        process.standardOutput = Pipe()
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errText = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "codesign failed"
            throw DockPinningError.shortcutCreationFailed(errText.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private static func restartDock() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Dock"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
    }
}
