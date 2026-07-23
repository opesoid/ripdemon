; RIP Demon — Inno Setup script
; Compile with: ISCC.exe /DMyAppVersion=1.0.2 RIP-Demon.iss
; Or via build\Build-Release.ps1 when Inno Setup 6 is installed.
;
; Start Menu shortcuts and Apps & features registration are created by
; installer\Install.ps1 (run in [Run]) — do not duplicate them here.

#ifndef MyAppVersion
  #define MyAppVersion "1.0.2"
#endif

#define MyAppName "RIP Demon"
#define MyAppPublisher "Opes"
#define MyAppURL "https://opes.dev"
#define MyAppExeName "yt.cmd"

[Setup]
AppId={{A7C3E91D-4B2F-4E8A-9D1C-8F3E2A1B0C9D}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={localappdata}\RIP-Demon
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\dist
OutputBaseFilename=RIP-Demon-Setup-{#MyAppVersion}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
UninstallDisplayName={#MyAppName}
InfoBeforeFile=..\README.md

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
; Ship sources; Install.ps1 downloads yt-dlp/ffmpeg/deno at configure time
Source: "..\VERSION"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\CHANGELOG.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\src\*"; DestDir: "{app}\src"; Flags: ignoreversion recursesubdirs
Source: "..\installer\*"; DestDir: "{app}\installer"; Flags: ignoreversion recursesubdirs
Source: "..\updater\*"; DestDir: "{app}\updater"; Flags: ignoreversion recursesubdirs

[Run]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\installer\Install.ps1"" -SkipWizard"; StatusMsg: "Configuring RIP Demon, yt-dlp, ffmpeg, and deno..."; Flags: waituntilterminated
