import AppKit
import Foundation

public struct GitHubAsset: Codable, Equatable, Sendable {
    public let name: String
    public let downloadURL: String

    enum CodingKeys: String, CodingKey {
        case name
        case downloadURL = "browser_download_url"
    }

    public init(name: String, downloadURL: String) {
        self.name = name
        self.downloadURL = downloadURL
    }
}

public struct GitHubRelease: Codable, Equatable, Sendable {
    public let tagName: String
    public let assets: [GitHubAsset]
    public let htmlURL: String

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case assets
        case htmlURL = "html_url"
    }

    public init(tagName: String, assets: [GitHubAsset], htmlURL: String) {
        self.tagName = tagName
        self.assets = assets
        self.htmlURL = htmlURL
    }
}

public enum UpdateChecker {
    public static func evaluateRelease(
        _ release: GitHubRelease,
        currentVersion: String = AppInfo.version
    ) -> (newVersion: String, release: GitHubRelease)? {
        let normalizedTag = release.tagName.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"^[vV]"#, with: "", options: .regularExpression)

        guard let latest = SemanticVersion(normalizedTag),
              let current = SemanticVersion(currentVersion),
              latest > current else {
            return nil
        }
        return (normalizedTag, release)
    }

    public static func selectMacOSAsset(from release: GitHubRelease) -> GitHubAsset? {
        let dmgAsset = release.assets.first { asset in
            let lower = asset.name.lowercased()
            return lower.hasSuffix(".dmg") &&
                (lower.contains("macos") || lower.contains("mac") || lower.contains("darwin") || lower.hasPrefix("teamsquickchat"))
        }
        if let dmgAsset {
            return dmgAsset
        }

        return release.assets.first { asset in
            let lower = asset.name.lowercased()
            return lower.hasSuffix(".zip") &&
                (lower.contains("macos") || lower.contains("mac") || lower.contains("darwin"))
        }
    }

    public static func check(
        currentVersion: String = AppInfo.version,
        session: URLSession = .shared
    ) async -> (newVersion: String, release: GitHubRelease)? {
        var request = URLRequest(url: AppInfo.releasesAPIURL)
        request.timeoutInterval = 10
        request.setValue("TeamsQuickChat/\(currentVersion) (macOS)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                return nil
            }
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            return evaluateRelease(release, currentVersion: currentVersion)
        } catch {
            return nil
        }
    }

    public static func downloadAndOpenInstaller(
        from release: GitHubRelease,
        session: URLSession = .shared
    ) async -> Bool {
        guard let asset = selectMacOSAsset(from: release),
              let url = URL(string: asset.downloadURL) else {
            return false
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        request.setValue("TeamsQuickChat/\(AppInfo.version) (macOS)", forHTTPHeaderField: "User-Agent")

        do {
            let (tempURL, response) = try await session.download(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                return false
            }

            let safeName = DockPinning.sanitizeBundleFileName(
                (asset.name as NSString).deletingPathExtension
            )
            let ext = (asset.name as NSString).pathExtension
            let fileName = ext.isEmpty ? safeName : "\(safeName).\(ext)"

            let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let destinationURL = downloadsDir.appendingPathComponent(fileName, isDirectory: false)

            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: tempURL, to: destinationURL)

            return await MainActor.run {
                NSWorkspace.shared.open(destinationURL)
            }
        } catch {
            return false
        }
    }
}
