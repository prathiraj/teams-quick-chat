# Teams Quick Chat

A lightweight Windows system-tray app that lets you **one-click open a Microsoft Teams 1:1 chat** with any pinned contact. Built with C# WinForms (.NET 9).

![Flyout demo](https://img.shields.io/badge/platform-Windows-blue) ![.NET 9](https://img.shields.io/badge/.NET-9.0-purple)

## Features

- 🔔 **System tray icon** — lives in your notification area, always one click away
- ⚡ **Instant Teams chat** — opens directly via `msteams:` protocol (no browser roundtrip)
- 📋 **Flyout UI** — borderless popup with rounded corners, positioned above the tray icon
- 🔀 **Drag & drop reordering** — rearrange contacts by dragging, order persists automatically
- ➕ **Add contacts** — built-in dialog to add new contacts (name + email)
- ☁️ **OneDrive roaming** — contacts sync across devices automatically
- 🔄 **Auto-update** — check for new versions from the tray icon context menu
- 🚫 **No Alt-Tab clutter** — hidden from the app switcher
- 📐 **Dynamic sizing** — window height adapts to the number of contacts
- ⚙️ **Configurable data location** — override the contacts storage path via `appsettings.json`

## Installation

### Prerequisites

- Windows 10/11
- Microsoft Teams desktop app (for `msteams:` protocol handling)

> **Note:** The installer and release binaries are self-contained — no .NET runtime install needed.

### Option 1: Installer (recommended)

Download `TeamsQuickChatSetup-x.x.x.exe` from the [Releases](../../releases) page and run it.

The installer will:
- Install to `%LOCALAPPDATA%\TeamsQuickChat` (no admin required)
- Create a Start Menu shortcut
- Optionally configure auto-start on Windows login
- Launch the app after installation

### Option 2: Portable

Download `TeamsQuickChat.exe` + `icon.ico` from the [Releases](../../releases) page, place them in the same folder, and run.

### Option 3: Build from source

```powershell
git clone https://github.com/prathiraj/teams-quick-chat.git
cd teams-quick-chat
dotnet publish -c Release
```

The exe will be at:
```
bin\Release\net9.0-windows\win-x64\publish\TeamsQuickChat.exe
```

### Pin to system tray

1. Run `TeamsQuickChat.exe`
2. The chat-bubble icon appears in your system tray (notification area, bottom-right)
3. If hidden in the overflow (▲), drag the icon onto the taskbar to pin it

### Auto-start on login (optional)

If you used the installer, auto-start is configured during setup. For portable installs, press `Win+R`, type `shell:startup`, and place a shortcut to `TeamsQuickChat.exe` in that folder.

## Usage

| Action | Result |
|---|---|
| **Left-click** tray icon | Toggle the contact flyout open/closed |
| **Click a contact name** | Opens Teams 1:1 chat with that person |
| **Click +** | Add a new contact (name + email) |
| **Right-click** a contact | Context menu with **Remove** option |
| **Drag** a contact up/down | Reorder the list (saved automatically) |
| **Right-click** tray icon | **Check for updates** · **Exit** |
| **Click outside** the flyout | Auto-hides |

## Configuration

### Contacts storage location

By default, contacts are stored in your OneDrive for cross-device roaming:

```
%USERPROFILE%\OneDrive - Microsoft\TeamsQuickChat\contacts.json
```

To override, create an `appsettings.json` file next to the exe:

```json
{
  "DataDir": "%USERPROFILE%\\Documents\\TeamsQuickChat"
}
```

Environment variables like `%USERPROFILE%` are expanded automatically.

### Contacts file format

```json
[
  { "Name": "Alice", "Email": "alice@contoso.com" },
  { "Name": "Bob", "Email": "bob@contoso.com" }
]
```

You can edit this file manually if you prefer.

## How it works

The app uses the Microsoft Teams deep link protocol to open chats directly in the desktop client:

```
msteams:/l/chat/0/0?users=<email>
```

This bypasses the browser entirely — Teams opens straight to the chat window.

## Project structure

```
teams-quick-chat/
├── Program.cs              # Entry point with crash logging
├── Form1.cs                # Main flyout window (tray icon, positioning, contact list UI)
├── Form1.Designer.cs       # WinForms designer partial
├── ContactStore.cs         # Contact CRUD with configurable JSON persistence
├── TeamsDeepLink.cs        # msteams: protocol launcher
├── AddContactDialog.cs     # Modal dialog for adding contacts
├── AppInfo.cs              # Version and repo metadata for update checker
├── UpdateChecker.cs        # GitHub release-based auto-update
├── NoHScrollFlowPanel.cs   # FlowLayoutPanel subclass that suppresses horizontal scrollbar
├── TeamsQuickChat.csproj   # .NET 9 WinForms project
├── icon.ico                # App icon (chat bubble)
├── installer/
│   └── TeamsQuickChat.iss  # Inno Setup installer script
├── docs/
│   └── index.html          # GitHub Pages hero landing page
└── .github/
    └── workflows/
        └── release.yml     # CI/CD: build, installer, release, deploy Pages
```

## Building

```powershell
# Debug build
dotnet build

# Release publish (self-contained single-file exe)
dotnet publish -c Release
```

## License

MIT
