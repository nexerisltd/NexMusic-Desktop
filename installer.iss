#define AppName "NexMusic"
#define AppVersion "4.0.5"
#define AppPublisher "NexApp"
#define AppExeName "nexmusic.exe"

[Setup]
AppId={{A1B2C3D4-1234-5678-9ABC-NEXMUSIC2026}}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
OutputBaseFilename=NexMusic-Desktop_{#AppVersion}-setup
OutputDir=.
Compression=lzma2/ultra64
SolidCompression=yes
SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
WizardStyle=modern
PrivilegesRequired=admin

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\Uninstall {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
