import AppKit
import Foundation

public enum TeamsDeepLinkError: LocalizedError, Equatable {
    case invalidContact
    case invalidURI(String)
    case teamsAppNotAvailable

    public var errorDescription: String? {
        switch self {
        case .invalidContact:
            return "Contact must have either an email address or a Teams chat link."
        case .invalidURI(let uri):
            return "The Teams deep link is invalid: \(uri)"
        case .teamsAppNotAvailable:
            return "Microsoft Teams could not be opened. Make sure the Microsoft Teams desktop app is installed on your Mac."
        }
    }
}

public enum TeamsDeepLink {
    public static let teamsWebHost = "teams.microsoft.com"
    public static let teamsScheme = "msteams"

    /// Converts a copied `https://teams.microsoft.com/l/chat/...` link (or an existing `msteams:/l/chat/...` link)
    /// into a canonical `msteams:/l/chat/...` deep link.
    public static func normalizeTeamsLink(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased() else {
            return nil
        }

        if scheme == teamsScheme {
            return isSupportedChatURI(trimmed) ? trimmed : nil
        }

        guard scheme == "https",
              let host = components.host?.lowercased(),
              host == teamsWebHost,
              isChatPath(components.percentEncodedPath) else {
            return nil
        }

        var result = "\(teamsScheme):\(components.percentEncodedPath)"
        if let query = components.percentEncodedQuery {
            result += "?\(query)"
        }
        if let fragment = components.percentEncodedFragment {
            result += "#\(fragment)"
        }
        return result
    }

    public static func getURI(for contact: Contact) throws -> String {
        if contact.isTeamsLink, let teamsLink = contact.teamsLink?.trimmingCharacters(in: .whitespacesAndNewlines) {
            return teamsLink
        }

        if let email = contact.email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
            return createChatURI(email: email)
        }

        throw TeamsDeepLinkError.invalidContact
    }

    public static func createChatURI(email: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._*")
        let encoded = email.addingPercentEncoding(withAllowedCharacters: allowed) ?? email
        return "\(teamsScheme):/l/chat/0/0?users=\(encoded)"
    }

    public static func isSupportedChatURI(_ uri: String) -> Bool {
        let trimmed = uri.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let components = URLComponents(string: trimmed),
              components.scheme?.lowercased() == teamsScheme,
              (components.host == nil || components.host?.isEmpty == true) else {
            return false
        }

        let path = components.percentEncodedPath
        guard isChatPath(path) else { return false }
        let suffix = path.dropFirst("/l/chat/".count)
        return !suffix.isEmpty
    }

    @discardableResult
    public static func open(_ contact: Contact) throws -> Bool {
        let uri = try getURI(for: contact)
        return try openURI(uri)
    }

    @discardableResult
    public static func openPinnedChat(_ uri: String) throws -> Bool {
        guard isSupportedChatURI(uri) else {
            throw TeamsDeepLinkError.invalidURI(uri)
        }
        return try openURI(uri)
    }

    @discardableResult
    public static func openURI(_ uri: String) throws -> Bool {
        guard let url = URL(string: uri) else {
            throw TeamsDeepLinkError.invalidURI(uri)
        }

        guard NSWorkspace.shared.urlForApplication(toOpen: url) != nil else {
            throw TeamsDeepLinkError.teamsAppNotAvailable
        }

        let opened = NSWorkspace.shared.open(url)
        if !opened {
            throw TeamsDeepLinkError.teamsAppNotAvailable
        }
        return true
    }

    private static func isChatPath(_ path: String) -> Bool {
        path.lowercased().hasPrefix("/l/chat/")
    }
}
