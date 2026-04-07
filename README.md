# Teams Quick Chat

A lightweight Windows system-tray app that lets you **one-click open a Microsoft Teams 1:1 chat** with any pinned contact. Built with C# WinForms (.NET 9).

![Flyout demo](https://img.shields.io/badge/platform-Windows-blue) ![.NET 9](https://img.shields.io/badge/.NET-9.0-purple)

## Features

- 🔔 **System tray icon** — lives in your notification area, always one click away
- ⚡ **Instant Teams chat** — opens directly via `msteams:` protocol (no browser roundtrip)
- 📋 **Flyout UI** — borderless popup with rounded corners, positioned above the tray icon
- ➕ **Add/remove contacts** — built-in UI to manage your pinned list
- ☁️ **OneDrive roaming** — contacts stored in `OneDrive\TeamsQuickChat\contacts.json`, syncs across devices
- 🚫 **No Alt-Tab clutter** — hidden from the app switcher
- 📐 **Dynamic sizing** — window height adapts to the number of contacts

## Installation

### Prerequisites

- Windows 10/11
- [.NET 9 Runtime](https://dotnet.microsoft.com/download/dotnet/9.0) (or the SDK if you want to build from source)
- Microsoft Teams desktop app (for `msteams:` protocol handling)
- OneDrive syncing `OneDrive - Microsoft` folder (for contact roaming)

### Option 1: Build from source (recommended)

```powershell
git clone https://github.com/<your-username>/teams-quick-chat.git
cd teams-quick-chat
dotnet publish -c Release
```

The exe will be at:
```
bin\Release\net9.0-windows\win-x64\publish\TeamsQuickChat.exe
```

### Option 2: Download release

Download `TeamsQuickChat.exe` from the [Releases](../../releases) page.

### Pin to system tray

1. Run `TeamsQuickChat.exe`
2. The chat-bubble icon appears in your system tray (notification area, bottom-right)
3. If hidden in the overflow (▲), drag the icon onto the taskbar to pin it

### Auto-start on login (optional)

Press `Win+R`, type `shell:startup`, and place a shortcut to `TeamsQuickChat.exe` in that folder.

## Usage

| Action | Result |
|---|---|
| **Left-click** tray icon | Toggle the contact flyout open/closed |
| **Click a contact name** | Opens Teams 1:1 chat with that person |
| **Click +** | Add a new contact (name + email) |
| **Click x** | Remove a contact |
| **Right-click** tray icon | Exit the app |
| **Click outside** the flyout | Auto-hides |

## How it works

The app uses the Microsoft Teams deep link protocol to open chats directly in the desktop client:

```
msteams:/l/chat/0/0?users=<email>
```

This bypasses the browser entirely — Teams opens straight to the chat window.

Contacts are stored as a simple JSON file:

```json
[
  { "Name": "Alice", "Email": "alice@contoso.com" },
  { "Name": "Bob", "Email": "bob@contoso.com" }
]
```

**Location:** `%USERPROFILE%\OneDrive - Microsoft\TeamsQuickChat\contacts.json`

You can edit this file manually if you prefer.

## Project structure

```
teams-quick-chat/
├── Program.cs              # Entry point
├── Form1.cs                # Main flyout window (tray icon, positioning, contact list UI)
├── Form1.Designer.cs       # WinForms designer partial
├── ContactStore.cs         # Contact CRUD with OneDrive-backed JSON persistence
├── TeamsDeepLink.cs        # msteams: protocol launcher
├── AddContactDialog.cs     # Modal dialog for adding contacts
├── TeamsQuickChat.csproj   # .NET 9 WinForms project
└── icon.ico                # App icon (chat bubble)
```

## Building

```powershell
# Debug build
dotnet build

# Release publish (single-file exe)
dotnet publish -c Release
```

## License

MIT
