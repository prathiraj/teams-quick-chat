import Foundation

public enum ContactStoreError: LocalizedError, Equatable {
    case cloudUnavailable(String)
    case readFailed(String)
    case writeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .cloudUnavailable(let message),
             .readFailed(let message),
             .writeFailed(let message):
            return message
        }
    }
}

private struct AppSettingsConfig: Codable {
    var dataDir: String?

    enum CodingKeys: String, CodingKey {
        case dataDir = "DataDir"
    }
}

public final class ContactStore {
    public static let shared = ContactStore()

    private let fileManager: FileManager
    public let homeDirectory: URL
    public let appSupportDirectory: URL
    public let portableConfigDirectory: URL?
    private let environment: [String: String]

    public init(
        fileManager: FileManager = .default,
        homeDirectory: URL? = nil,
        appSupportDirectory: URL? = nil,
        portableConfigDirectory: URL? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.fileManager = fileManager
        let resolvedHome = homeDirectory ?? fileManager.homeDirectoryForCurrentUser
        self.homeDirectory = resolvedHome
        if let appSupportDirectory {
            self.appSupportDirectory = appSupportDirectory
        } else {
            let baseSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? resolvedHome.appendingPathComponent("Library/Application Support", isDirectory: true)
            self.appSupportDirectory = baseSupport.appendingPathComponent("TeamsQuickChat", isDirectory: true)
        }
        self.portableConfigDirectory = portableConfigDirectory ?? Bundle.main.executableURL?.deletingLastPathComponent()
        self.environment = environment
    }

    public var settingsFileURL: URL {
        appSupportDirectory.appendingPathComponent("appsettings.json", isDirectory: false)
    }

    public func getConfiguredDataDir() -> String? {
        for candidate in candidateSettingsFiles() {
            guard fileManager.fileExists(atPath: candidate.path),
                  let rawData = try? Data(contentsOf: candidate) else {
                continue
            }
            let cleanData = Self.stripUTF8BOM(rawData)
            if let config = try? JSONDecoder().decode(AppSettingsConfig.self, from: cleanData),
               let dir = config.dataDir?.trimmingCharacters(in: .whitespacesAndNewlines),
               !dir.isEmpty {
                return dir
            }
        }
        return nil
    }

    public func saveConfiguredDataDir(_ rawDir: String?) throws {
        let trimmed = rawDir?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            if fileManager.fileExists(atPath: settingsFileURL.path) {
                try fileManager.removeItem(at: settingsFileURL)
            }
            return
        }

        try fileManager.createDirectory(at: appSupportDirectory, withIntermediateDirectories: true)
        let config = AppSettingsConfig(dataDir: trimmed)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        let data = try encoder.encode(config)
        try data.write(to: settingsFileURL, options: [.atomic])
    }

    public func resolveDataDirectory() -> URL {
        if let configured = getConfiguredDataDir() {
            let expanded = expandPathVariables(configured)
            if !expanded.isEmpty {
                return URL(fileURLWithPath: expanded, isDirectory: true)
            }
        }
        return resolveDefaultDataDirectory()
    }

    public func resolveDefaultDataDirectory() -> URL {
        if let oneDriveRoot = detectOneDriveDirectory() {
            return oneDriveRoot.appendingPathComponent("TeamsQuickChat", isDirectory: true)
        }
        return appSupportDirectory
    }

    public var contactsFileURL: URL {
        resolveDataDirectory().appendingPathComponent("contacts.json", isDirectory: false)
    }

    public func expandPathVariables(_ rawPath: String) -> String {
        var result = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { return "" }

        var env = environment
        if env["HOME"] == nil {
            env["HOME"] = homeDirectory.path
        }

        // Support Windows-style %VAR% (e.g. %USERPROFILE%\Documents\TeamsQuickChat)
        if result.contains("%") {
            result = result.replacingOccurrences(of: "\\", with: "/")
            let pattern = #"%([A-Za-z_][A-Za-z0-9_]*)%"#
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let nsRange = NSRange(result.startIndex..<result.endIndex, in: result)
                let matches = regex.matches(in: result, options: [], range: nsRange).reversed()
                for match in matches {
                    guard let fullRange = Range(match.range(at: 0), in: result),
                          let nameRange = Range(match.range(at: 1), in: result) else { continue }
                    let varName = String(result[nameRange])
                    let replacement: String?
                    if varName.caseInsensitiveCompare("USERPROFILE") == .orderedSame {
                        replacement = homeDirectory.path
                    } else {
                        replacement = env[varName] ?? env.first(where: {
                            $0.key.caseInsensitiveCompare(varName) == .orderedSame
                        })?.value
                    }
                    if let replacement {
                        result.replaceSubrange(fullRange, with: replacement)
                    }
                }
            }
        }

        // Expand ${VAR} and $VAR
        let dollarPattern = #"\$\{([A-Za-z_][A-Za-z0-9_]*)\}|\$([A-Za-z_][A-Za-z0-9_]*)"#
        if let regex = try? NSRegularExpression(pattern: dollarPattern, options: []) {
            let nsRange = NSRange(result.startIndex..<result.endIndex, in: result)
            let matches = regex.matches(in: result, options: [], range: nsRange).reversed()
            for match in matches {
                guard let fullRange = Range(match.range(at: 0), in: result) else { continue }
                let nameRange = Range(match.range(at: 1), in: result) ?? Range(match.range(at: 2), in: result)
                guard let nameRange else { continue }
                let varName = String(result[nameRange])
                if let replacement = env[varName] {
                    result.replaceSubrange(fullRange, with: replacement)
                }
            }
        }

        // Expand leading ~
        if result == "~" {
            result = homeDirectory.path
        } else if result.hasPrefix("~/") {
            result = homeDirectory.path + String(result.dropFirst(1))
        }

        return (result as NSString).standardizingPath
    }

    public func load() throws -> [Contact] {
        let fileURL = contactsFileURL
        do {
            guard fileManager.fileExists(atPath: fileURL.path) else {
                return []
            }
            let rawData = try Data(contentsOf: fileURL)
            let cleanData = Self.stripUTF8BOM(rawData)
            if cleanData.allSatisfy({ $0 == 0x20 || $0 == 0x0A || $0 == 0x0D || $0 == 0x09 }) {
                return []
            }
            return try JSONDecoder().decode([Contact].self, from: cleanData)
        } catch {
            if Self.isCloudProviderUnavailable(error: error, path: fileURL.path) {
                throw Self.cloudUnavailableError()
            }
            throw ContactStoreError.readFailed("Could not read contacts from \(fileURL.path): \(error.localizedDescription)")
        }
    }

    public func save(_ contacts: [Contact]) throws {
        let dataDir = resolveDataDirectory()
        let fileURL = dataDir.appendingPathComponent("contacts.json", isDirectory: false)
        do {
            try fileManager.createDirectory(at: dataDir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
            let data = try encoder.encode(contacts)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            if Self.isCloudProviderUnavailable(error: error, path: fileURL.path) {
                throw Self.cloudUnavailableError()
            }
            throw ContactStoreError.writeFailed("Could not save contacts to \(fileURL.path): \(error.localizedDescription)")
        }
    }

    public func addEmail(name: String, email: String) throws {
        try add(.forEmail(name: name, email: email))
    }

    public func addTeamsLink(name: String, teamsLink: String) throws {
        try add(.forTeamsLink(name: name, teamsLink: teamsLink))
    }

    public func add(_ contact: Contact) throws {
        var contacts = try load()
        if contacts.contains(where: { $0.hasSameTarget(as: contact) }) {
            return
        }
        contacts.append(contact)
        try save(contacts)
    }

    public func remove(_ contact: Contact) throws {
        var contacts = try load()
        contacts.removeAll(where: { $0.hasSameTarget(as: contact) })
        try save(contacts)
    }

    private func candidateSettingsFiles() -> [URL] {
        var urls = [settingsFileURL]
        if let portableConfigDirectory {
            let portableURL = portableConfigDirectory.appendingPathComponent("appsettings.json", isDirectory: false)
            if portableURL.standardizedFileURL != settingsFileURL.standardizedFileURL {
                urls.append(portableURL)
            }
        }
        return urls
    }

    private func detectOneDriveDirectory() -> URL? {
        let cloudStorage = homeDirectory.appendingPathComponent("Library/CloudStorage", isDirectory: true)
        let preferredFixed = [
            cloudStorage.appendingPathComponent("OneDrive-Microsoft", isDirectory: true),
            homeDirectory.appendingPathComponent("OneDrive - Microsoft", isDirectory: true)
        ]

        for candidate in preferredFixed where isDirectory(candidate) {
            return candidate
        }

        if let entries = try? fileManager.contentsOfDirectory(
            at: cloudStorage,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            let oneDriveDirs = entries
                .filter { $0.lastPathComponent.hasPrefix("OneDrive") && isDirectory($0) }
                .sorted { lhs, rhs in
                    let lhsPersonal = lhs.lastPathComponent.localizedCaseInsensitiveContains("Personal")
                    let rhsPersonal = rhs.lastPathComponent.localizedCaseInsensitiveContains("Personal")
                    if lhsPersonal != rhsPersonal {
                        return !lhsPersonal
                    }
                    return lhs.lastPathComponent < rhs.lastPathComponent
                }
            if let first = oneDriveDirs.first {
                return cloudStorage.appendingPathComponent(first.lastPathComponent, isDirectory: true)
            }
        }

        let legacyOneDrive = homeDirectory.appendingPathComponent("OneDrive", isDirectory: true)
        if isDirectory(legacyOneDrive) {
            return legacyOneDrive
        }

        return nil
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    public static func stripUTF8BOM(_ data: Data) -> Data {
        if data.count >= 3 {
            let prefix = [UInt8](data.prefix(3))
            if prefix == [0xEF, 0xBB, 0xBF] {
                return data.dropFirst(3)
            }
        }
        return data
    }

    public static func isCloudProviderUnavailable(error: Error, path: String) -> Bool {
        let lowerPath = path.lowercased()
        let isCloudPath = lowerPath.contains("/cloudstorage/") || lowerPath.contains("onedrive")
        let nsError = error as NSError

        if nsError.domain == "NSFileProviderErrorDomain" || nsError.domain.contains("FileProvider") {
            return true
        }

        guard isCloudPath else { return false }

        if nsError.domain == NSCocoaErrorDomain {
            let cloudCocoaCodes: Set<Int> = [
                NSFileReadUnknownError,
                NSFileWriteUnknownError,
                4353, // NSUbiquitousFileUnavailableError
                4354, // NSUbiquitousFileNotUploadedDueToQuotaError
                4355  // NSUbiquitousFileUbiquityServerNotAvailable
            ]
            if cloudCocoaCodes.contains(nsError.code) {
                return true
            }
            if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error,
               isCloudProviderUnavailable(error: underlying, path: path) {
                return true
            }
        }

        if nsError.domain == NSPOSIXErrorDomain {
            let cloudPosixCodes: Set<Int32> = [EDEADLK, EAGAIN, ETIMEDOUT, ENOTCONN, ECANCELED, EIO]
            if cloudPosixCodes.contains(Int32(nsError.code)) {
                return true
            }
        }

        return false
    }

    private static func cloudUnavailableError() -> ContactStoreError {
        .cloudUnavailable(
            "Your contacts are stored in OneDrive, but the cloud files aren't available right now. " +
            "Start OneDrive (or wait for it to finish syncing), or choose a local folder in Settings."
        )
    }
}
