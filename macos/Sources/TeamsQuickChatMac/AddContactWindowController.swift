import AppKit
import SwiftUI
import TeamsQuickChatCore

enum AddContactMode: String, CaseIterable, Identifiable {
    case email = "Email Address"
    case teamsLink = "Teams Chat Link"

    var id: String { rawValue }
}

@MainActor
final class AddContactFormModel: ObservableObject {
    @Published var mode: AddContactMode = .email
    @Published var name: String = ""
    @Published var email: String = ""
    @Published var teamsLink: String = ""
    @Published var validationMessage: String?
}

@MainActor
final class AddContactWindowController {
    static let shared = AddContactWindowController()

    private var window: NSWindow?

    func show(viewModel: ContactsViewModel) {
        let form = AddContactFormModel()
        if let existing = window {
            existing.contentView = NSHostingView(
                rootView: AddContactView(viewModel: viewModel, form: form) { [weak existing] in
                    existing?.close()
                }
            )
            NSApp.activate(ignoringOtherApps: true)
            existing.center()
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 245),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "Add Contact"
        win.isReleasedWhenClosed = false
        win.level = .floating
        win.contentView = NSHostingView(
            rootView: AddContactView(viewModel: viewModel, form: form) { [weak win] in
                win?.close()
            }
        )
        win.center()
        self.window = win

        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }
}

private struct AddContactView: View {
    @ObservedObject var viewModel: ContactsViewModel
    @ObservedObject var form: AddContactFormModel
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Add by:", selection: $form.mode) {
                ForEach(AddContactMode.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: form.mode) { _ in
                form.validationMessage = nil
            }

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    Text("Name:")
                        .frame(width: 78, alignment: .trailing)
                    TextField(
                        form.mode == .email ? "Optional (defaults to email prefix)" : "Required (e.g. Project Standup)",
                        text: $form.name
                    )
                    .textFieldStyle(.roundedBorder)
                }

                if form.mode == .email {
                    GridRow {
                        Text("Email:")
                            .frame(width: 78, alignment: .trailing)
                        TextField("alice@contoso.com", text: $form.email)
                            .textFieldStyle(.roundedBorder)
                    }
                } else {
                    GridRow {
                        Text("Teams link:")
                            .frame(width: 78, alignment: .trailing)
                        HStack(spacing: 6) {
                            TextField("https://teams.microsoft.com/l/chat/...", text: $form.teamsLink)
                                .textFieldStyle(.roundedBorder)
                            Button("Paste") {
                                if let pasted = NSPasteboard.general.string(forType: .string) {
                                    form.teamsLink = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
                                }
                            }
                            .controlSize(.small)
                        }
                    }
                }
            }

            Text(helpText)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .padding(.leading, 88)
                .fixedSize(horizontal: false, vertical: true)

            if let validationMessage = form.validationMessage {
                Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.red)
                    .padding(.leading, 88)
            }

            Spacer(minLength: 4)

            HStack {
                Spacer()
                Button("Cancel", action: onClose)
                    .keyboardShortcut(.cancelAction)
                Button("Add", action: save)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(18)
        .frame(width: 420)
    }

    private var helpText: String {
        switch form.mode {
        case .email:
            return "Opens a direct 1:1 Microsoft Teams chat. Blank names default to the email prefix."
        case .teamsLink:
            return "Paste a chat link copied from Microsoft Teams (••• → Copy link)."
        }
    }

    private func save() {
        form.validationMessage = nil
        do {
            switch form.mode {
            case .email:
                let trimmedEmail = form.email.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedEmail.isEmpty else {
                    form.validationMessage = "Email address is required."
                    return
                }
                var trimmedName = form.name.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedName.isEmpty {
                    trimmedName = String(trimmedEmail.split(separator: "@", maxSplits: 1).first ?? Substring(trimmedEmail))
                }
                try viewModel.addEmail(name: trimmedName, email: trimmedEmail)

            case .teamsLink:
                let trimmedName = form.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedName.isEmpty else {
                    form.validationMessage = "Name is required for Teams chat links."
                    return
                }
                let trimmedLink = form.teamsLink.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedLink.isEmpty else {
                    form.validationMessage = "Teams chat link is required."
                    return
                }
                guard let normalized = TeamsDeepLink.normalizeTeamsLink(trimmedLink) else {
                    form.validationMessage = "Paste a valid Teams chat link copied from Microsoft Teams."
                    return
                }
                try viewModel.addTeamsLink(name: trimmedName, teamsLink: normalized)
            }
            onClose()
        } catch {
            form.validationMessage = error.localizedDescription
        }
    }
}
