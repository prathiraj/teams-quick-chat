import AppKit
import SwiftUI
import TeamsQuickChatCore

struct PopoverContentView: View {
    @ObservedObject var viewModel: ContactsViewModel
    @ObservedObject var launchAtLogin = LaunchAtLoginManager.shared

    let onAddTapped: () -> Void
    let onSettingsTapped: () -> Void
    let onOpenContact: (Contact) -> Void
    let onPinToDock: (Contact) -> Void
    let onCheckUpdates: () -> Void
    let onQuit: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            contentBody
        }
        .frame(width: ContactsViewModel.popoverWidth, height: viewModel.preferredPopoverHeight)
    }

    private var headerView: some View {
        HStack(spacing: 8) {
            Text(AppInfo.appName)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            Button(action: onAddTapped) {
                Image(systemName: "plus")
                    .font(.system(size: 12.5, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.07))
                    )
            }
            .buttonStyle(.plain)
            .help("Add contact or Teams chat link")
            .accessibilityLabel("Add Contact")

            Menu {
                Button("Add Contact…", action: onAddTapped)
                Divider()
                Button {
                    toggleLaunchAtLogin()
                } label: {
                    if launchAtLogin.isEnabled {
                        Label("Start at Login", systemImage: "checkmark")
                    } else {
                        Text("Start at Login")
                    }
                }
                Button("Settings…", action: onSettingsTapped)
                    .keyboardShortcut(",", modifiers: .command)
                Button("Check for Updates…", action: onCheckUpdates)
                Divider()
                Button("Quit \(AppInfo.appName)", action: onQuit)
                    .keyboardShortcut("q", modifiers: .command)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Options & Settings")
            .accessibilityLabel("More Options")
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
    }

    @ViewBuilder
    private var contentBody: some View {
        if let errorMessage = viewModel.storageErrorMessage {
            storageUnavailableView(message: errorMessage)
        } else if viewModel.contacts.isEmpty {
            emptyStateView
        } else {
            contactListView
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)
            Text("No contacts yet.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Click + to add a person or Teams chat link.")
                .font(.system(size: 11.5))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func storageUnavailableView(message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "icloud.slash")
                .font(.system(size: 22))
                .foregroundStyle(.red.opacity(0.85))

            Text(message)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button("Retry") {
                    viewModel.refresh()
                }
                .controlSize(.small)

                Button("Settings…", action: onSettingsTapped)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var contactListView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 0) {
                ForEach(viewModel.contacts) { contact in
                    ContactRowView(
                        contact: contact,
                        isDragging: viewModel.draggingContactID == contact.id,
                        isHovered: viewModel.hoveredContactID == contact.id,
                        onHoverChanged: { hovering in
                            if hovering {
                                viewModel.hoveredContactID = contact.id
                            } else if viewModel.hoveredContactID == contact.id {
                                viewModel.hoveredContactID = nil
                            }
                        },
                        onTap: {
                            guard viewModel.draggingContactID == nil else { return }
                            onOpenContact(contact)
                        },
                        onPinToDock: {
                            onPinToDock(contact)
                        },
                        onRemove: {
                            viewModel.remove(contact)
                        }
                    )
                    .gesture(
                        DragGesture(minimumDistance: 5, coordinateSpace: .named("contactList"))
                            .onChanged { value in
                                if viewModel.draggingContactID == nil {
                                    viewModel.draggingContactID = contact.id
                                }
                                let count = viewModel.contacts.count
                                guard count > 1 else { return }
                                let targetIndex = min(
                                    max(Int(value.location.y / ContactsViewModel.rowHeight), 0),
                                    count - 1
                                )
                                if let currentIndex = viewModel.contacts.firstIndex(where: { $0.id == contact.id }),
                                   currentIndex != targetIndex {
                                    withAnimation(.easeInOut(duration: 0.12)) {
                                        viewModel.moveContact(from: currentIndex, to: targetIndex)
                                    }
                                }
                            }
                            .onEnded { _ in
                                if viewModel.draggingContactID != nil {
                                    viewModel.draggingContactID = nil
                                    viewModel.persistCurrentOrder()
                                }
                            }
                    )
                }
            }
            .padding(.vertical, 4)
            .coordinateSpace(name: "contactList")
        }
    }

    private func toggleLaunchAtLogin() {
        do {
            try launchAtLogin.setEnabled(!launchAtLogin.isEnabled)
            if launchAtLogin.requiresApproval {
                AppAlerts.showInfo(
                    title: "Approve in Login Items",
                    message: "Allow \(AppInfo.appName) under System Settings → General → Login Items to finish enabling Start at Login."
                )
            }
        } catch {
            AppAlerts.showWarning(title: AppInfo.appName, message: error.localizedDescription)
        }
    }
}

private struct ContactRowView: View {
    let contact: Contact
    let isDragging: Bool
    let isHovered: Bool
    let onHoverChanged: (Bool) -> Void
    let onTap: () -> Void
    let onPinToDock: () -> Void
    let onRemove: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var avatarBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.42, green: 0.42, blue: 0.96).opacity(0.26)
            : Color(red: 0.35, green: 0.35, blue: 0.90).opacity(0.13)
    }

    private var avatarForeground: Color {
        colorScheme == .dark
            ? Color(red: 0.68, green: 0.68, blue: 1.0)
            : Color(red: 0.35, green: 0.35, blue: 0.90)
    }

    private var rowBackground: Color {
        if isDragging {
            return avatarBackground
        }
        if isHovered {
            return Color.primary.opacity(colorScheme == .dark ? 0.09 : 0.05)
        }
        return Color.clear
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(avatarBackground)
                    Text(contact.initials)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(avatarForeground)
                }
                .frame(width: 30, height: 30)

                HStack(spacing: 5) {
                    Text(contact.name)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if contact.isTeamsLink {
                        Image(systemName: "link")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 4)

                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .help("Drag to reorder")
            }
            .padding(.horizontal, 12)
            .frame(height: ContactsViewModel.rowHeight - 1)
            .contentShape(Rectangle())

            Divider()
                .opacity(0.45)
                .padding(.leading, 52)
        }
        .background(rowBackground)
        .onHover(perform: onHoverChanged)
        .onTapGesture(perform: onTap)
        .help(contact.subtitle)
        .contextMenu {
            Button(action: onTap) {
                Label("Open in Teams", systemImage: "message")
            }
            Button(action: onPinToDock) {
                Label("Pin to Dock…", systemImage: "dock.rectangle")
            }
            Divider()
            Button(role: .destructive, action: onRemove) {
                Label("Remove", systemImage: "trash")
            }
        }
    }
}
