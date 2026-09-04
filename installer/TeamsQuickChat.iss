; TeamsQuickChat Inno Setup Installer Script
; Version is injected at compile time via /D flag: iscc /DAppVersion=1.0.0

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

#ifndef PublishDir
  #define PublishDir "..\bin\Release\net9.0-windows10.0.17763.0\win-x64\publish"
#endif

[Setup]
AppId={{E7A3B2C1-4D5F-6E7A-8B9C-0D1E2F3A4B5C}
AppName=TeamsQuickChat
AppVersion={#AppVersion}
AppPublisher=prathiraj
AppPublisherURL=https://github.com/prathiraj/teams-quick-chat
DefaultDirName={localappdata}\TeamsQuickChat
DefaultGroupName=TeamsQuickChat
PrivilegesRequired=lowest
OutputBaseFilename=TeamsQuickChatSetup-{#AppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
SetupIconFile=..\icon.ico
UninstallDisplayIcon={app}\TeamsQuickChat.exe
WizardStyle=modern
DisableProgramGroupPage=yes
DisableDirPage=yes
CloseApplications=yes
RestartApplications=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "autostart"; Description: "Start TeamsQuickChat when I sign in to Windows"; Flags: checkedonce

[Files]
Source: "{#PublishDir}\TeamsQuickChat.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#PublishDir}\icon.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\TeamsQuickChat"; Filename: "{app}\TeamsQuickChat.exe"; IconFilename: "{app}\icon.ico"; AppUserModelID: "Prathiraj.TeamsQuickChat"
Name: "{userstartup}\TeamsQuickChat"; Filename: "{app}\TeamsQuickChat.exe"; IconFilename: "{app}\icon.ico"; AppUserModelID: "Prathiraj.TeamsQuickChat"; Tasks: autostart

[Run]
Filename: "{app}\TeamsQuickChat.exe"; Description: "Launch TeamsQuickChat"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{app}\TeamsQuickChat.exe"; Parameters: "--remove-taskbar-pins"; Flags: runhidden waituntilterminated; RunOnceId: "RemoveTaskbarPins"

[UninstallDelete]
Type: files; Name: "{app}\*"
Type: filesandordirs; Name: "{group}\Pinned chats"
