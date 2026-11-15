import AppKit
import Foundation
import Testing
@testable import TeamsQuickChatCore

struct TeamsQuickChatCoreTests {
    private func withTempDir(_ body: (URL) throws -> Void) throws {
        let rawTempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TeamsQuickChatTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rawTempDir, withIntermediateDirectories: true)
        let tempDir = rawTempDir.resolvingSymlinksInPath()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try body(tempDir)
    }

    @Test
    func windowsContactsJSONCompatibilityAndUTF8BOM() throws {
        try withTempDir { tempDir in
            let windowsJSON = """
            [
              { "Name": "Alice Johnson", "Email": "alice@contoso.com" },
              {
                "Name": "Project Standup",
                "TeamsLink": "msteams:/l/chat/19:7cc41a9f969241a5b4cf65d615126876@thread.v2/conversations?context=%7B%22contextType%22%3A%22chat%22%7D"
              }
            ]
            """
            var dataWithBOM = Data([0xEF, 0xBB, 0xBF])
            dataWithBOM.append(Data(windowsJSON.utf8))

            let home = tempDir.appendingPathComponent("home", isDirectory: true)
            let appSupport = tempDir.appendingPathComponent("appSupport", isDirectory: true)
            try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
            try dataWithBOM.write(to: appSupport.appendingPathComponent("contacts.json"))

            let store = ContactStore(homeDirectory: home, appSupportDirectory: appSupport, portableConfigDirectory: nil)
            let loaded = try store.load()
            #expect(loaded.count == 2)
            #expect(loaded[0].name == "Alice Johnson")
            #expect(loaded[0].email == "alice@contoso.com")
            #expect(!loaded[0].isTeamsLink)
            #expect(loaded[0].initials == "AJ")

            #expect(loaded[1].name == "Project Standup")
            #expect(loaded[1].isTeamsLink)
            #expect(loaded[1].email == nil)
            #expect(loaded[1].initials == "PS")

            try store.save(loaded)
            let savedString = try String(contentsOf: appSupport.appendingPathComponent("contacts.json"), encoding: .utf8)
            #expect(savedString.contains("\"Name\""))
            #expect(savedString.contains("\"Email\""))
            #expect(savedString.contains("\"TeamsLink\""))
            #expect(!savedString.contains("\\/l\\/chat"))
            #expect(!savedString.contains("null"))
        }
    }

    @Test
    func teamsDeepLinkNormalizationAndEncoding() throws {
        let copiedWebLink = "https://teams.microsoft.com/l/chat/19:7cc41a9f969241a5b4cf65d615126876@thread.v2/conversations?context=%7B%22contextType%22%3A%22chat%22%7D"
        let expected = "msteams:/l/chat/19:7cc41a9f969241a5b4cf65d615126876@thread.v2/conversations?context=%7B%22contextType%22%3A%22chat%22%7D"

        #expect(TeamsDeepLink.normalizeTeamsLink(copiedWebLink) == expected)
        #expect(TeamsDeepLink.normalizeTeamsLink(expected) == expected)

        #expect(TeamsDeepLink.normalizeTeamsLink("http://teams.microsoft.com/l/chat/19:abc") == nil)
        #expect(TeamsDeepLink.normalizeTeamsLink("https://evil.example.com/l/chat/19:abc") == nil)
        #expect(TeamsDeepLink.normalizeTeamsLink("https://teams.microsoft.com/l/channel/19:abc") == nil)
        #expect(!TeamsDeepLink.isSupportedChatURI("msteams://evil.example.com/l/chat/19:abc"))
        #expect(!TeamsDeepLink.isSupportedChatURI("msteams:/l/chat/"))

        let contact = Contact.forEmail(name: "Alice", email: "alice+dev@contoso.com")
        #expect(
            try TeamsDeepLink.getURI(for: contact) ==
            "msteams:/l/chat/0/0?users=alice%2Bdev%40contoso.com"
        )
    }

    @Test
    func contactStoreDeduplicationSettingsAndOneDriveResolution() throws {
        try withTempDir { tempDir in
            let home = tempDir.appendingPathComponent("userhome", isDirectory: true)
            let appSupport = home.appendingPathComponent("Library/Application Support/TeamsQuickChat", isDirectory: true)
            try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)

            let store = ContactStore(
                homeDirectory: home,
                appSupportDirectory: appSupport,
                portableConfigDirectory: nil,
                environment: ["HOME": home.path, "CUSTOM_SYNC": "/tmp/custom-sync"]
            )

            #expect(store.resolveDataDirectory().standardizedFileURL == appSupport.standardizedFileURL)

            let personalOD = home.appendingPathComponent("Library/CloudStorage/OneDrive-Personal", isDirectory: true)
            let orgOD = home.appendingPathComponent("Library/CloudStorage/OneDrive-Contoso", isDirectory: true)
            try FileManager.default.createDirectory(at: personalOD, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: orgOD, withIntermediateDirectories: true)
            #expect(
                store.resolveDataDirectory().resolvingSymlinksInPath().path ==
                orgOD.appendingPathComponent("TeamsQuickChat", isDirectory: true).resolvingSymlinksInPath().path
            )

            let msftOD = home.appendingPathComponent("Library/CloudStorage/OneDrive-Microsoft", isDirectory: true)
            try FileManager.default.createDirectory(at: msftOD, withIntermediateDirectories: true)
            #expect(
                store.resolveDataDirectory().resolvingSymlinksInPath().path ==
                msftOD.appendingPathComponent("TeamsQuickChat", isDirectory: true).resolvingSymlinksInPath().path
            )

            #expect(
                store.expandPathVariables("%USERPROFILE%\\Documents\\TeamsQuickChat") ==
                home.appendingPathComponent("Documents/TeamsQuickChat").path
            )
            #expect(
                store.expandPathVariables("~/SyncFolder") ==
                home.appendingPathComponent("SyncFolder").path
            )
            #expect(
                store.expandPathVariables("${CUSTOM_SYNC}/TeamsQuickChat") ==
                "/tmp/custom-sync/TeamsQuickChat"
            )

            let customDir = tempDir.appendingPathComponent("custom-contacts", isDirectory: true)
            try store.saveConfiguredDataDir(customDir.path)
            #expect(store.resolveDataDirectory().standardizedFileURL == customDir.standardizedFileURL)

            try store.addEmail(name: "Alice", email: "alice@contoso.com")
            try store.addEmail(name: "Alice Duplicate", email: "ALICE@CONTOSO.COM")
            try store.addTeamsLink(name: "Standup", teamsLink: "msteams:/l/chat/19:abc@thread.v2/conversations")
            try store.addTeamsLink(name: "Standup Dup", teamsLink: "msteams:/l/chat/19:abc@thread.v2/conversations")

            var contacts = try store.load()
            #expect(contacts.count == 2)

            try store.remove(Contact.forEmail(name: "", email: "ALICE@contoso.com"))
            contacts = try store.load()
            #expect(contacts.count == 1)
            #expect(contacts[0].name == "Standup")

            try store.saveConfiguredDataDir("")
            #expect(store.getConfiguredDataDir() == nil)
        }
    }

    @Test
    func cloudErrorClassification() {
        let fileProviderErr = NSError(domain: "NSFileProviderErrorDomain", code: -1005)
        #expect(ContactStore.isCloudProviderUnavailable(
            error: fileProviderErr,
            path: "/Users/test/Library/CloudStorage/OneDrive-Microsoft/TeamsQuickChat/contacts.json"
        ))

        let cocoaCloudErr = NSError(domain: NSCocoaErrorDomain, code: NSFileReadUnknownError)
        #expect(ContactStore.isCloudProviderUnavailable(
            error: cocoaCloudErr,
            path: "/Users/test/OneDrive - Microsoft/TeamsQuickChat/contacts.json"
        ))
        #expect(!ContactStore.isCloudProviderUnavailable(
            error: cocoaCloudErr,
            path: "/Users/test/Library/Application Support/TeamsQuickChat/contacts.json"
        ))
    }

    @Test
    func iconGenerationAndDockShortcutBundleCreation() throws {
        try withTempDir { tempDir in
            let appIconURL = tempDir.appendingPathComponent("AppIcon.icns")
            try IconGenerator.generateAppIconICNS(to: appIconURL)
            let icnsData = try Data(contentsOf: appIconURL)
            #expect(String(data: icnsData.prefix(4), encoding: .ascii) == "icns")
            #expect(NSImage(contentsOf: appIconURL) != nil)

            let dummyExec = tempDir.appendingPathComponent("DummyLauncher")
            try Data("#!/bin/sh\nexit 0\n".utf8).write(to: dummyExec)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dummyExec.path)

            let shortcutsDir = tempDir.appendingPathComponent("Shortcuts", isDirectory: true)
            let alice1 = Contact.forEmail(name: "Alice Johnson", email: "alice1@contoso.com")
            let alice2 = Contact.forEmail(name: "Alice Johnson", email: "alice2@contoso.com")

            let shortcut1 = try DockPinning.createShortcutApp(
                for: alice1,
                executableURL: dummyExec,
                shortcutsDirectory: shortcutsDir,
                signBundle: true
            )
            #expect(shortcut1.appURL.lastPathComponent == "Alice Johnson.app")
            #expect(DockPinning.isValidShortcutBundleIdentifier(shortcut1.bundleIdentifier))

            let shortcut1Again = try DockPinning.createShortcutApp(
                for: alice1,
                executableURL: dummyExec,
                shortcutsDirectory: shortcutsDir,
                signBundle: true
            )
            #expect(shortcut1Again.appURL == shortcut1.appURL)

            let shortcut2 = try DockPinning.createShortcutApp(
                for: alice2,
                executableURL: dummyExec,
                shortcutsDirectory: shortcutsDir,
                signBundle: true
            )
            #expect(shortcut2.appURL != shortcut1.appURL)
            #expect(shortcut2.appURL.lastPathComponent.hasPrefix("Alice Johnson ("))

            let plistData = try Data(contentsOf: shortcut1.appURL.appendingPathComponent("Contents/Info.plist"))
            let plist = try #require(
                PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any]
            )
            #expect(plist[AppInfo.pinnedChatURIInfoKey] as? String == "msteams:/l/chat/0/0?users=alice1%40contoso.com")
            #expect(plist["LSUIElement"] as? Bool == true)

            let tile = DockPinning.buildDockTileDictionary(for: shortcut1)
            #expect(DockPinning.dockEntriesContain([tile], shortcut: shortcut1))
            #expect(!DockPinning.dockEntriesContain([tile], shortcut: shortcut2))
        }
    }

    @Test
    func updateCheckerVersionAndAssetSelection() {
        let release = GitHubRelease(
            tagName: "v1.10.0",
            assets: [
                GitHubAsset(
                    name: "TeamsQuickChatSetup-1.10.0.exe",
                    downloadURL: "https://example.com/TeamsQuickChatSetup-1.10.0.exe"
                ),
                GitHubAsset(
                    name: "TeamsQuickChat-1.10.0-macos.dmg",
                    downloadURL: "https://example.com/TeamsQuickChat-1.10.0-macos.dmg"
                ),
                GitHubAsset(
                    name: "TeamsQuickChat-1.10.0-macos.zip",
                    downloadURL: "https://example.com/TeamsQuickChat-1.10.0-macos.zip"
                )
            ],
            htmlURL: "https://github.com/prathiraj/teams-quick-chat/releases/tag/v1.10.0"
        )

        let evalNewer = UpdateChecker.evaluateRelease(release, currentVersion: "1.9.0")
        #expect(evalNewer?.newVersion == "1.10.0")
        #expect(UpdateChecker.evaluateRelease(release, currentVersion: "1.10.0") == nil)
        #expect(UpdateChecker.evaluateRelease(release, currentVersion: "2.0.0") == nil)

        let selected = UpdateChecker.selectMacOSAsset(from: release)
        #expect(selected?.name == "TeamsQuickChat-1.10.0-macos.dmg")
    }
}
