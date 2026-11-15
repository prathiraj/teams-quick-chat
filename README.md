# Teams Quick Chat

A lightweight native **Windows system-tray** and **macOS menu-bar** app that lets you **one-click open Microsoft Teams chats** with pinned people or saved chat shortcuts.

- **Windows:** Native C# WinForms (.NET 9, self-contained single-file `.exe`)
- **macOS:** Native Swift, AppKit & SwiftUI universal `.app` (Apple Silicon & Intel, macOS 13+)

![Platform Windows & macOS](https://img.shields.io/badge/platform-Windows%20%7C%20macOS-blue) ![.NET 9](https://img.shields.io/badge/.NET-9.0-purple) ![Swift](https://img.shields.io/badge/Swift-macOS%2013%2B-orange)

## Features

- 🔔 **Menu bar & system tray icon** — lives in your macOS menu bar or Windows notification area, always one click away
- ⚡ **Instant Teams chat** — opens directly via `msteams:` protocol (no browser roundtrip)
- 📋 **Native popover / flyout UI** — crisp rounded popup anchored to your menu bar or tray icon, with automatic Light & Dark Mode support on macOS
- 🔀 **Drag & drop reordering** — rearrange contacts by dragging; order persists automatically
- ➕ **Add contacts and chat shortcuts** — add people by email or paste copied Teams chat links
- 📌 **Pin chats to the Taskbar or Dock** — right-click any contact or saved chat for a direct Windows Taskbar or macOS Dock (and Spotlight!) shortcut
- ☁️ **Cross-device OneDrive roaming** — shares the exact same `contacts.json` format across Windows and macOS automatically
- 🚀 **Start at login** — launch automatically when signing in to Windows or macOS
- 🔄 **Auto-update** — check for new GitHub releases right from the app menu
- 🚫 **Zero switcher clutter** — hidden from `Alt+Tab` (Windows) and the Dock / `⌘Tab` switcher (macOS `LSUIElement`)
- 📐 **Dynamic sizing** — popup height adapts cleanly to your contact count
- ⚙️ **Configurable data location** — override the contacts storage folder via **Settings** (`⌘,` on macOS) or `appsettings.json`

## Installation

### Prerequisites

- **Microsoft Teams desktop app** (for `msteams:` protocol handling)
- **macOS:** macOS 13 Ventura or later (Apple Silicon or Intel)
- **Windows:** Windows 10 version 1809 or later, or Windows 11 (self-contained — no .NET runtime install needed)

---

### macOS Installation

#### Option 1: DMG Installer (recommended)

1. Download `TeamsQuickChat-x.x.x-macos.dmg` from the [Releases](../../releases) page.
2. Open the `.dmg` and drag **Teams Quick Chat** into **Applications**.
3. Launch **Teams Quick Chat** from Applications or Spotlight.
   > **First-launch note:** Because this open-source app is ad-hoc signed rather than notarized with a paid Apple Developer ID, if macOS Gatekeeper blocks first launch, **Control-click** `Teams Quick Chat.app` → **Open** (or go to **System Settings → Privacy & Security → Open Anyway**, or run `xattr -cr "/Applications/Teams Quick Chat.app"`).
4. Enable **Start at Login** anytime from the menu bar icon menu (`•••` → **Start at Login**) or **Settings…** (`⌘,`).

#### Option 2: Build from source (macOS)

```bash
git clone https://github.com/prathiraj/teams-quick-chat.git
cd teams-quick-chat
./macos/scripts/package_macos.sh
```

Output bundles are created in `macos/dist/`:
- `macos/dist/Teams Quick Chat.app`
- `macos/dist/TeamsQuickChat-x.x.x-macos.dmg`
- `macos/dist/TeamsQuickChat-x.x.x-macos.zip`

---

### Windows Installation

#### Option 1: Installer (recommended)

Download `TeamsQuickChatSetup-x.x.x.exe` from the [Releases](../../releases) page and run it.

The installer will:
- Install to `%LOCALAPPDATA%\TeamsQuickChat` (no admin required)
- Create a Start Menu shortcut
- Optionally configure auto-start on Windows login
- Launch the app after installation

#### Option 2: Portable

Download `TeamsQuickChat.exe` + `icon.ico` from the [Releases](../../releases) page, place them in the same folder, and run.

#### Option 3: Build from source (Windows)

```powershell
git clone https://github.com/prathiraj/teams-quick-chat.git
cd teams-quick-chat
dotnet publish -c Release
```

The exe will be at:
```
bin\Release\net9.0-windows10.0.17763.0\win-x64\publish\TeamsQuickChat.exe
```

#### Pin to system tray & auto-start (Windows)

1. Run `TeamsQuickChat.exe`; if the chat-bubble icon is in the overflow (`▲`), drag it onto the taskbar.
2. If you used the installer, auto-start is configured during setup. For portable installs, press `Win+R`, type `shell:startup`, and place a shortcut to `TeamsQuickChat.exe` in that folder.

## Usage

| Action | Windows | macOS |
|---|---|---|
| **Open / close contact list** | Left-click tray icon | Click menu bar icon |
| **Open a Teams chat** | Click a contact row | Click a contact row |
| **Add contact / chat link** | Click **+** | Click **+** (supports `⌘V` or **Paste** button) |
| **Pin a chat shortcut** | Right-click contact → **Pin to taskbar** | Right-click contact → **Pin to Dock…** |
| **Remove a contact** | Right-click contact → **Remove** | Right-click contact → **Remove** |
| **Reorder contacts** | Drag a contact up/down | Drag a contact up/down |
| **App menu & Settings** | Right-click tray icon | Right-click (or Control-click) menu bar icon, or click `•••` in header (`⌘,`) |
| **Dismiss popup** | Click outside | Click outside or press `Esc` |

### Pin a chat to the Taskbar or Dock

- **macOS (Dock & Spotlight):** Right-click any contact or saved chat and select **Pin to Dock…**. Teams Quick Chat creates a lightweight standalone chat launcher `.app` (with the contact's initials icon) in `~/Applications/Teams Quick Chat Shortcuts/` and offers **Add to Dock** or **Show in Finder**. Once created, you can also open that chat directly from **Spotlight (`⌘Space`)** by typing the contact's name. Remove a Dock icon anytime via **Right-click → Options → Remove from Dock**.
- **Windows (Taskbar):** Right-click a contact or saved chat and select **Pin to taskbar**. Confirm the Windows 11 pin prompt (or use the Start menu folder fallback if automatic pinning is unavailable). Each shortcut has a separate taskbar identity so multiple chats can sit side-by-side. Uninstalling removes generated pins automatically.

## Configuration

### Contacts storage location & cross-device sync

Contacts use the same `contacts.json` file on both Windows and macOS so your list syncs seamlessly via OneDrive:

- **Windows default:**
  ```
  %USERPROFILE%\OneDrive - Microsoft\TeamsQuickChat\contacts.json
  ```
- **macOS default:**
  Automatically uses OneDrive when present (`~/Library/CloudStorage/OneDrive-Microsoft/TeamsQuickChat/contacts.json` or your active `~/Library/CloudStorage/OneDrive*/TeamsQuickChat/contacts.json`), and falls back to `~/Library/Application Support/TeamsQuickChat/contacts.json` when OneDrive is not installed.

To override the folder:
- **macOS:** Open **Settings…** (`⌘,`) and choose any folder (such as iCloud Drive, Dropbox, or a local directory), or edit `~/Library/Application Support/TeamsQuickChat/appsettings.json`. Supports `~`, `$HOME`, and `%USERPROFILE%`.
- **Windows:** Open **Settings** from the tray icon menu, or create `appsettings.json` next to `TeamsQuickChat.exe`:
  ```json
  {
    "DataDir": "%USERPROFILE%\\Documents\\TeamsQuickChat"
  }
  ```

> **OneDrive not running?** When contacts live in OneDrive and cloud files can't be reached, both the Windows and macOS apps stay running and show an inline notice rather than crashing. Start OneDrive and retry, or choose a local folder in Settings.

### Contacts file format

```json
[
  { "Name": "Alice", "Email": "alice@contoso.com" },
  {
    "Name": "Project chat",
    "TeamsLink": "msteams:/l/chat/19:7cc41a9f969241a5b4cf65d615126876@thread.v2/conversations?context=%7B%22contextType%22%3A%22chat%22%7D"
  }
]
```

Older email-only entries remain supported. You can edit this file manually if you prefer.

## How it works

The app uses the Microsoft Teams deep link protocol to open chats directly in the desktop client on both Windows and macOS.

Email contacts are opened with:

```
msteams:/l/chat/0/0?users=<email>
```

Teams chat links copied from Teams are stored by replacing the `https://teams.microsoft.com` prefix with `msteams:`:

```
https://teams.microsoft.com/l/chat/...  ->  msteams:/l/chat/...
```

This bypasses the browser entirely — Teams opens straight to the chat window.

## Project structure

```
teams-quick-chat/
├── Program.cs                  # Windows entry point with crash logging
├── Form1.cs                    # Windows flyout window (tray icon, positioning, contact list UI)
├── Form1.Designer.cs           # WinForms designer partial
├── ContactStore.cs             # Windows contact CRUD with configurable JSON persistence
├── TeamsDeepLink.cs            # Windows msteams: protocol launcher
├── TaskbarPinning.cs           # Windows per-chat shortcut creation and launch handling
├── TaskbarPinRequestForm.cs    # Windows taskbar pin request and manual fallback
├── ShellShortcut.cs            # Windows .lnk creation with AppUserModelID metadata
├── AppIdentity.cs              # Windows process AppUserModelID registration
├── AddContactDialog.cs         # Windows modal dialog for adding contacts and chat links
├── SettingsDialog.cs           # Windows settings dialog
├── AppInfo.cs                  # Windows version and repo metadata
├── UpdateChecker.cs            # Windows GitHub release-based auto-update
├── NoHScrollFlowPanel.cs       # FlowLayoutPanel subclass without horizontal scrollbar
├── TeamsQuickChat.csproj       # .NET 9 WinForms project (canonical version source)
├── installer/
│   └── TeamsQuickChat.iss      # Inno Setup Windows installer script
├── macos/                      # Native macOS app (Swift, AppKit & SwiftUI)
│   ├── Package.swift           # Swift Package manifest (macOS 13+)
│   ├── Sources/
│   │   ├── TeamsQuickChatCore/ # ContactStore, TeamsDeepLink, DockPinning, IconGenerator, UpdateChecker
│   │   └── TeamsQuickChatMac/  # NSStatusItem menu bar controller, SwiftUI popover, Add & Settings windows
│   ├── Tests/
│   │   └── TeamsQuickChatCoreTests/ # Unit tests for JSON compat, deep links, OneDrive, Dock shortcuts
│   └── scripts/
│       └── package_macos.sh    # Universal (arm64 + x86_64) .app, .icns, codesign, .dmg & .zip builder
├── docs/
│   └── index.html              # GitHub Pages landing page
└── .github/
    └── workflows/
        └── release.yml         # CI/CD: Windows & macOS builds, unified GitHub Release, GitHub Pages
```

## Building & Testing

```bash
# macOS: run unit tests & package universal .app / .dmg
cd macos && swift test
./macos/scripts/package_macos.sh
```

```powershell
# Windows: debug build & release publish
dotnet build
dotnet publish -c Release
```

## License

MIT
