#define MyAppId "{{E054A5F8-8C48-4D85-9E1F-36E7D0375A31}"
#define MyProductName "教师工具箱"
#define MyAppName "Teacher Hub License Manager"
#define MyAppDisplayName "教师工具箱授权管理器"
#define MyAppPublisher "教师工具箱"
#define MyAppExeName "teacher_hub_license_manager.exe"
#define MyAppURL "https://github.com/ccool3974-lq/teacher_hub"
#define MyReleaseDir AddBackslash(SourcePath) + "build\\windows\\x64\\runner\\Release"
#define MyAppExePath MyReleaseDir + "\\" + MyAppExeName
#define MyOutputDir AddBackslash(SourcePath) + "dist"
#define MyOutputBaseName "teacher_toolkit_license_manager_setup"
#define MyAppIconPath AddBackslash(SourcePath) + "windows\\runner\\resources\\app_icon.ico"

#ifnexist MyAppExePath
  #error "未找到 Windows Release 可执行文件。请先执行 flutter build windows --release。"
#endif

#ifnexist MyAppIconPath
  #error "未找到安装包图标文件 windows\\runner\\resources\\app_icon.ico。"
#endif

#define MyAppVersion GetVersionNumbersString(MyAppExePath)

[Setup]
AppId={#MyAppId}
AppName={#MyAppDisplayName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppDisplayName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\Teacher Toolkit\License Manager
DefaultGroupName={#MyAppDisplayName}
OutputDir={#MyOutputDir}
OutputBaseFilename={#MyOutputBaseName}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=lowest
SetupIconFile={#MyAppIconPath}
UninstallDisplayIcon={app}\{#MyAppExeName}
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppDisplayName} 安装程序
VersionInfoProductName={#MyProductName}
VersionInfoProductVersion={#MyAppVersion}
UninstallDisplayName={#MyAppDisplayName}

[Languages]
Name: "chinesesimp"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加图标："

[Files]
Source: "{#MyReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppDisplayName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppDisplayName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "启动 {#MyAppDisplayName}"; Flags: nowait postinstall skipifsilent
