import AppKit
import Foundation
import TeamsQuickChatCore

@MainActor
final class ContactsViewModel: ObservableObject {
    @Published var contacts: [Contact] = []
    @Published var storageErrorMessage: String?
    @Published var draggingContactID: String?
    @Published var hoveredContactID: String?

    let store: ContactStore
    var onContentHeightChanged: ((CGFloat) -> Void)?

    static let popoverWidth: CGFloat = 320
    static let rowHeight: CGFloat = 44
    private static let headerAndDividerHeight: CGFloat = 49

    init(store: ContactStore = .shared) {
        self.store = store
        refresh()
    }

    var preferredPopoverHeight: CGFloat {
        let maxScreenHeight = (NSScreen.main?.visibleFrame.height ?? 800) - 80
        let rawHeight: CGFloat
        if storageErrorMessage != nil {
            rawHeight = 205
        } else if contacts.isEmpty {
            rawHeight = 170
        } else {
            rawHeight = Self.headerAndDividerHeight + CGFloat(contacts.count) * Self.rowHeight + 8
        }
        return min(max(rawHeight, 130), max(220, maxScreenHeight))
    }

    func refresh() {
        do {
            contacts = try store.load()
            storageErrorMessage = nil
        } catch {
            contacts = []
            storageErrorMessage = error.localizedDescription
        }
        notifyHeightChanged()
    }

    func addEmail(name: String, email: String) throws {
        try store.addEmail(name: name, email: email)
        refresh()
    }

    func addTeamsLink(name: String, teamsLink: String) throws {
        try store.addTeamsLink(name: name, teamsLink: teamsLink)
        refresh()
    }

    func remove(_ contact: Contact) {
        do {
            try store.remove(contact)
            refresh()
        } catch {
            AppAlerts.showWarning(title: AppInfo.appName, message: error.localizedDescription)
        }
    }

    func moveContact(from sourceIndex: Int, to destinationIndex: Int) {
        guard contacts.indices.contains(sourceIndex),
              contacts.indices.contains(destinationIndex),
              sourceIndex != destinationIndex else {
            return
        }
        let item = contacts.remove(at: sourceIndex)
        contacts.insert(item, at: destinationIndex)
    }

    func persistCurrentOrder() {
        guard !contacts.isEmpty else { return }
        do {
            try store.save(contacts)
        } catch {
            AppAlerts.showWarning(title: AppInfo.appName, message: error.localizedDescription)
            refresh()
        }
    }

    private func notifyHeightChanged() {
        onContentHeightChanged?(preferredPopoverHeight)
    }
}
