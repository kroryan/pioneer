#define AppExeName "pioneer.exe"
#define AppName "Pioneer"
#define AppVersion "20260203-dev"
#define AppUrl "https://www.pioneerspacesim.net"
#define BuildYear "2026"
#define InstallSource "D:\source\Pioneer\pioneer\out\install\x64-Release"

[Setup]
AppId={{5ba280c9-1d73-4039-b2e1-7fc7800f784c}
AppName="{#AppName}"
AppVersion="{#AppVersion}"
AppPublisher="{#AppName} Developers (kroryan build)"
AppPublisherURL="{#AppUrl}"
AppSupportURL="{#AppUrl}"
AppUpdatesURL="{#AppUrl}"
AppCopyright="Copyright 2008-{#BuildYear} {#AppName} developers"
CreateAppDir=yes
LicenseFile="{#InstallSource}\licenses\GPL-3.txt"
OutputBaseFilename=pioneer-{#AppVersion}-win64-setup
OutputDir="D:\source\Pioneer\pioneer"
Compression=lzma2/ultra64
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64
DefaultDirName={autopf}\Pioneer
DefaultGroupName=Pioneer
UninstallDisplayIcon="{app}\{#AppExeName}"
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "french"; MessagesFile: "compiler:Languages\French.isl"
Name: "german"; MessagesFile: "compiler:Languages\German.isl"
Name: "italian"; MessagesFile: "compiler:Languages\Italian.isl"
Name: "portuguese"; MessagesFile: "compiler:Languages\Portuguese.isl"
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "japanese"; MessagesFile: "compiler:Languages\Japanese.isl"
Name: "polish"; MessagesFile: "compiler:Languages\Polish.isl"
Name: "dutch"; MessagesFile: "compiler:Languages\Dutch.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#InstallSource}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{commondesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[InstallDelete]
Type: filesandordirs; Name: "{app}"

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
