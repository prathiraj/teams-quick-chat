; TeamsQuickChat Inno Setup Installer Script
; Version is injected at compile time via /D flag: iscc /DAppVersion=1.0.0

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
AppId={{E7A3B2C1-4D5F-6E7A-8B9C-0D1E2F3A4B5C}
AppName=TeamsQuickChat
AppVersion={#AppVersion}
AppPublisher=Prathiraj Chakka
AppPublisherURL=https://github.com/pchakka_microsoft/teams-quick-chat
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

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "autostart"; Description: "Start TeamsQuickChat when I sign in to Windows"; Flags: checkedonce

[Files]
Source: "..\publish\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\TeamsQuickChat"; Filename: "{app}\TeamsQuickChat.exe"
Name: "{userstartup}\TeamsQuickChat"; Filename: "{app}\TeamsQuickChat.exe"; Tasks: autostart

[Run]
Filename: "{app}\TeamsQuickChat.exe"; Description: "Launch TeamsQuickChat"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: files; Name: "{app}\*"
