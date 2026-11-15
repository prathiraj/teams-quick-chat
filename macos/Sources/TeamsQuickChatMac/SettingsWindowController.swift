import AppKit
import SwiftUI
import TeamsQuickChatCore

@MainActor
final class SettingsFormModel: ObservableObject {
    @Published var customDataDir: String
    @Published var errorMessage: String?

    init(customDataDir: String) {
        self.customDataDir = customDataDir
    }
}

@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func show(viewModel: ContactsViewModel) {
        LaunchAtLoginManager.shared.refreshStatus()
        let form = SettingsFormModel(customDataDir: viewModel.store.getConfiguredDataDir() ?? "")

        if let existing = window {
            existing.contentView = NSHostingView(
                rootView: SettingsView(viewModel: viewModel, form: form) { [weak existing] in
                    existing?.close()
                }
            )
            NSApp.activate(ignoringOtherApps: true)
            existing.center()
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 470, height: 295),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "\(AppInfo.appName) Settings"
        win.isReleasedWhenClosed = false
        win.contentView = NSHostingView(
            rootView: SettingsView(viewModel: viewModel, form: form) { [weak win] in
                win?.close()
            }
        )
        win.center()
        self.window = win

        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }
}

private struct SettingsView: View {
    @ObservedObject var viewModel: ContactsViewModel
    @ObservedObject var form: SettingsFormModel
    @ObservedObject var launchAtLogin = LaunchAtLoginManager.shared
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("Startup") {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(
                        "Start \(AppInfo.appName) when I log in to macOS",
                        isOn: Binding(
                            get: { launchAtLogin.isEnabled },
                            set: { newValue in
                                do {
                                    try launchAtLogin.setEnabled(newValue)
                                    form.errorMessage = nil
                                } catch {
                                    form.errorMessage = error.localizedDescription
                                }
                            }
                        )
                    )

                    if launchAtLogin.requiresApproval {
                        HStack(spacing: 8) {
                            Text("Approval needed in System Settings → Login Items.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Button("Open Login Items…") {
                                launchAtLogin.openSystemSettingsLoginItems()
                            }
                            .controlSize(.mini)
                        }
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("Contacts Storage") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Contacts folder override:")
                        .font(.system(size: 12, weight: .medium))

                    HStack(spacing: 6) {
                        TextField("Default (OneDrive or Application Support)", text: $form.customDataDir)
                            .textFieldStyle(.roundedBorder)

                        Button("Choose…") {
                            chooseFolder()
                        }

                        if !form.customDataDir.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button("Default") {
                                form.customDataDir = ""
                            }
                        }
                    }

                    Text("Supports ~, $HOME, and %USERPROFILE%. Leave empty to automatically roam via OneDrive when available.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        Text("Active file:")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(activeContactsPathPreview)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button("Show in Finder") {
                            revealContactsLocation()
                        }
                        .controlSize(.mini)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let errorMessage = form.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.red)
            }

            HStack {
                Text("Version \(AppInfo.version)")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)

                Button("Check for Updates…") {
                    AppActions.checkForUpdates(showUpToDate: true)
                }
                .controlSize(.small)

                Spacer()

                Button("Cancel", action: onClose)
                    .keyboardShortcut(.cancelAction)

                Button("Save") {
                    saveSettings()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(18)
        .frame(width: 470)
    }

    private var activeContactsPathPreview: String {
        let trimmed = form.customDataDir.trimmingCharacters(in: .whitespacesAndNewlines)
        let dirURL: URL
        if trimmed.isEmpty {
            dirURL = viewModel.store.resolveDefaultDataDirectory()
        } else {
            let expanded = viewModel.store.expandPathVariables(trimmed)
            dirURL = expanded.isEmpty
                ? viewModel.store.resolveDefaultDataDirectory()
                : URL(fileURLWithPath: expanded, isDirectory: true)
        }
        return dirURL.appendingPathComponent("contacts.json").path
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select Contacts Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        let currentExpanded = viewModel.store.expandPathVariables(form.customDataDir)
        if !currentExpanded.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: currentExpanded, isDirectory: true)
        } else {
            panel.directoryURL = viewModel.store.resolveDataDirectory()
        }
        if panel.runModal() == .OK, let selected = panel.url {
            form.customDataDir = selected.path
        }
    }

    private func revealContactsLocation() {
        let fileURL = viewModel.store.contactsFileURL
        if FileManager.default.fileExists(atPath: fileURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
        } else {
            let dirURL = fileURL.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
            NSWorkspace.shared.open(dirURL)
        }
    }

    private func saveSettings() {
        do {
            try viewModel.store.saveConfiguredDataDir(form.customDataDir)
            viewModel.refresh()
            onClose()
        } catch {
            form.errorMessage = error.localizedDescription
        }
    }
}
