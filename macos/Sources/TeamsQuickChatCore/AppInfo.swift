import Foundation

public enum AppInfo {
    public static let appName = "Teams Quick Chat"
    public static let bundleIdentifier = "com.prathiraj.teamsquickchat"
    public static let chatShortcutBundlePrefix = bundleIdentifier + ".chat."
    public static let pinnedChatURIInfoKey = "TeamsQuickChatPinnedURI"

    public static let fallbackVersion = "1.9.0"

    public static var version: String {
        if Bundle.main.bundleIdentifier == bundleIdentifier,
           let bundleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           SemanticVersion(bundleVersion) != nil {
            return bundleVersion
        }
        return fallbackVersion
    }

    public static let repoOwner = "prathiraj"
    public static let repoName = "teams-quick-chat"

    public static let releasesAPIURL = URL(
        string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
    )!

    public static let releasesPageURL = URL(
        string: "https://github.com/\(repoOwner)/\(repoName)/releases/latest"
    )!
}

public struct SemanticVersion: Comparable, Equatable, CustomStringConvertible, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int = 0) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public init?(_ rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutPrefix = trimmed.hasPrefix("v") || trimmed.hasPrefix("V")
            ? String(trimmed.dropFirst())
            : trimmed
        let core = withoutPrefix.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? withoutPrefix
        let parts = core.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2 && parts.count <= 4 else { return nil }

        guard let major = Int(parts[0]),
              let minor = Int(parts[1]) else {
            return nil
        }

        let patch: Int
        if parts.count >= 3 {
            guard let parsedPatch = Int(parts[2]) else { return nil }
            patch = parsedPatch
        } else {
            patch = 0
        }

        if parts.count == 4, Int(parts[3]) == nil {
            return nil
        }

        guard major >= 0, minor >= 0, patch >= 0 else { return nil }
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public var description: String {
        "\(major).\(minor).\(patch)"
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
}
