import Foundation

public struct Contact: Codable, Equatable, Hashable, Identifiable, Sendable {
    public var name: String
    public var email: String?
    public var teamsLink: String?

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case email = "Email"
        case teamsLink = "TeamsLink"
    }

    public init(name: String, email: String? = nil, teamsLink: String? = nil) {
        self.name = name
        self.email = email
        self.teamsLink = teamsLink
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = (try? container.decode(String.self, forKey: .name)) ?? ""
        self.email = try container.decodeIfPresent(String.self, forKey: .email)
        self.teamsLink = try container.decodeIfPresent(String.self, forKey: .teamsLink)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        if let email, !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try container.encode(email, forKey: .email)
        }
        if let teamsLink, !teamsLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try container.encode(teamsLink, forKey: .teamsLink)
        }
    }

    public var isTeamsLink: Bool {
        guard let teamsLink else { return false }
        return !teamsLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var id: String {
        if isTeamsLink, let teamsLink {
            return "link:\(teamsLink)"
        }
        if let email {
            return "email:\(email.lowercased())"
        }
        return "name:\(name)"
    }

    public var initials: String {
        Self.computeInitials(from: name)
    }

    public var subtitle: String {
        if isTeamsLink {
            return "Teams chat shortcut"
        }
        return email ?? ""
    }

    public static func forEmail(name: String, email: String) -> Contact {
        Contact(name: name, email: email, teamsLink: nil)
    }

    public static func forTeamsLink(name: String, teamsLink: String) -> Contact {
        Contact(name: name, email: nil, teamsLink: teamsLink)
    }

    public func hasSameTarget(as other: Contact) -> Bool {
        if isTeamsLink != other.isTeamsLink {
            return false
        }
        if isTeamsLink {
            return teamsLink == other.teamsLink
        }
        guard let lhsEmail = email, let rhsEmail = other.email else {
            return email == nil && other.email == nil
        }
        return lhsEmail.caseInsensitiveCompare(rhsEmail) == .orderedSame
    }

    public static func computeInitials(from name: String) -> String {
        let parts = name.split(whereSeparator: { $0.isWhitespace })
        if parts.count >= 2,
           let first = parts.first?.first,
           let last = parts.last?.first {
            return "\(first)\(last)".uppercased()
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count >= 2 {
            return String(trimmed.prefix(2)).uppercased()
        }
        return trimmed.uppercased()
    }
}
