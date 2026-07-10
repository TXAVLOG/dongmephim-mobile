; ============================================================
; Inno Setup Script - DongMePhim v5.0.0
; Tác giả: TXA TEAM
; ============================================================

#define MyAppName "DongMePhim"
#define MyAppVersion "5.0.0"
#define MyAppPublisher "TXA TEAM"
#define MyAppURL "https://fb.com/vlog.txa.2311"
#define MyAppExeName "tphimx_setup.exe"
#define MyAppIcon "..\windows\runner\resources\app_icon.ico"
#define BuildDir "..\build\windows\x64\runner\Release"
#define OldAppId "{{B4F5A6D2-3E1C-4F8A-9D7B-2C6E8F1A5D3B}"

[Setup]
AppId={{B4F5A6D2-3E1C-4F8A-9D7B-2C6E8F1A5D3B}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
LicenseFile=
OutputDir=Output
OutputBaseFilename=DongMePhim_v{#MyAppVersion}_Setup
SetupIconFile={#MyAppIcon}
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=lowest
; Không dùng CloseApplications=force vì ta tự xử lý bằng [Code]
CloseApplications=no
RestartApplications=no

[Languages]
Name: "vietnamese"; MessagesFile: "Languages\Vietnamese.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 6.1
Name: "associatefiles"; Description: "Associate video file types with {#MyAppName}"; GroupDescription: "File Associations:"; Flags: unchecked

[Files]
; === Main Executable ===
Source: "{#BuildDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion

; === Flutter Engine ===
Source: "{#BuildDir}\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion

; === Plugin DLLs ===
Source: "{#BuildDir}\dartjni.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\local_notifier_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\permission_handler_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\screen_brightness_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\share_plus_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\url_launcher_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\video_player_win_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion

; === ICU Data ===
Source: "{#BuildDir}\data\icudtl.dat"; DestDir: "{app}\data"; Flags: ignoreversion

; === Flutter Assets ===
Source: "{#BuildDir}\data\flutter_assets\AssetManifest.bin"; DestDir: "{app}\data\flutter_assets"; Flags: ignoreversion
Source: "{#BuildDir}\data\flutter_assets\FontManifest.json"; DestDir: "{app}\data\flutter_assets"; Flags: ignoreversion
Source: "{#BuildDir}\data\flutter_assets\NativeAssetsManifest.json"; DestDir: "{app}\data\flutter_assets"; Flags: ignoreversion
Source: "{#BuildDir}\data\flutter_assets\NOTICES.Z"; DestDir: "{app}\data\flutter_assets"; Flags: ignoreversion

; === AOT Compiled Dart (Release only) ===
Source: "{#BuildDir}\data\app.so"; DestDir: "{app}\data"; Flags: ignoreversion

; === App Assets ===
Source: "{#BuildDir}\data\flutter_assets\assets\*"; DestDir: "{app}\data\flutter_assets\assets"; Flags: ignoreversion recursesubdirs createallsubdirs

; === Fonts ===
Source: "{#BuildDir}\data\flutter_assets\fonts\*"; DestDir: "{app}\data\flutter_assets\fonts"; Flags: ignoreversion recursesubdirs createallsubdirs

; === Packages ===
Source: "{#BuildDir}\data\flutter_assets\packages\*"; DestDir: "{app}\data\flutter_assets\packages"; Flags: ignoreversion recursesubdirs createallsubdirs

; === Shaders ===
Source: "{#BuildDir}\data\flutter_assets\shaders\*"; DestDir: "{app}\data\flutter_assets\shaders"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: quicklaunchicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}\data"

[Registry]
; === File Associations ===
Root: HKCU; Subkey: "Software\Classes\.mp4\OpenWithProgids"; ValueType: string; ValueName: "DongMePhim.mp4"; ValueData: ""; Flags: uninsdeletevalue; Tasks: associatefiles
Root: HKCU; Subkey: "Software\Classes\.mkv\OpenWithProgids"; ValueType: string; ValueName: "DongMePhim.mkv"; ValueData: ""; Flags: uninsdeletevalue; Tasks: associatefiles
Root: HKCU; Subkey: "Software\Classes\.avi\OpenWithProgids"; ValueType: string; ValueName: "DongMePhim.avi"; ValueData: ""; Flags: uninsdeletevalue; Tasks: associatefiles
Root: HKCU; Subkey: "Software\Classes\.mov\OpenWithProgids"; ValueType: string; ValueName: "DongMePhim.mov"; ValueData: ""; Flags: uninsdeletevalue; Tasks: associatefiles
Root: HKCU; Subkey: "Software\Classes\.flv\OpenWithProgids"; ValueType: string; ValueName: "DongMePhim.flv"; ValueData: ""; Flags: uninsdeletevalue; Tasks: associatefiles
Root: HKCU; Subkey: "Software\Classes\.wmv\OpenWithProgids"; ValueType: string; ValueName: "DongMePhim.wmv"; ValueData: ""; Flags: uninsdeletevalue; Tasks: associatefiles
Root: HKCU; Subkey: "Software\Classes\.webm\OpenWithProgids"; ValueType: string; ValueName: "DongMePhim.webm"; ValueData: ""; Flags: uninsdeletevalue; Tasks: associatefiles

Root: HKCU; Subkey: "Software\Classes\DongMePhim.mp4"; ValueType: string; ValueName: ""; ValueData: "DongMePhim Video"; Flags: uninsdeletekey; Tasks: associatefiles
Root: HKCU; Subkey: "Software\Classes\DongMePhim.mp4\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"; Tasks: associatefiles
Root: HKCU; Subkey: "Software\Classes\DongMePhim.mp4\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: associatefiles

Root: HKCU; Subkey: "Software\Classes\DongMePhim.mkv"; ValueType: string; ValueName: ""; ValueData: "DongMePhim Video"; Flags: uninsdeletekey; Tasks: associatefiles
Root: HKCU; Subkey: "Software\Classes\DongMePhim.mkv\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"; Tasks: associatefiles
Root: HKCU; Subkey: "Software\Classes\DongMePhim.mkv\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: associatefiles

Root: HKCU; Subkey: "Software\Classes\DongMePhim.avi"; ValueType: string; ValueName: ""; ValueData: "DongMePhim Video"; Flags: uninsdeletekey; Tasks: associatefiles
Root: HKCU; Subkey: "Software\Classes\DongMePhim.avi\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"; Tasks: associatefiles
Root: HKCU; Subkey: "Software\Classes\DongMePhim.avi\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: associatefiles

Root: HKCU; Subkey: "Software\Classes\DongMePhim.mov"; ValueType: string; ValueName: ""; ValueData: "DongMePhim Video"; Flags: uninsdeletekey; Tasks: associatefiles
Root: HKCU; Subkey: "Software\Classes\DongMePhim.mov\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"; Tasks: associatefiles
Root: HKCU; Subkey: "Software\Classes\DongMePhim.mov\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: associatefiles

Root: HKCU; Subkey: "Software\Classes\DongMePhim.flv"; ValueType: string; ValueName: ""; ValueData: "DongMePhim Video"; Flags: uninsdeletekey; Tasks: associatefiles
Root: HKCU; Subkey: "Software\Classes\DongMePhim.flv\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"; Tasks: associatefiles
Root: HKCU; Subkey: "Software\Classes\DongMePhim.flv\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: associatefiles

Root: HKCU; Subkey: "Software\Classes\DongMePhim.wmv"; ValueType: string; ValueName: ""; ValueData: "DongMePhim Video"; Flags: uninsdeletekey; Tasks: associatefiles
Root: HKCU; Subkey: "Software\Classes\DongMePhim.wmv\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"; Tasks: associatefiles
Root: HKCU; Subkey: "Software\Classes\DongMePhim.wmv\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: associatefiles

Root: HKCU; Subkey: "Software\Classes\DongMePhim.webm"; ValueType: string; ValueName: ""; ValueData: "DongMePhim Video"; Flags: uninsdeletekey; Tasks: associatefiles
Root: HKCU; Subkey: "Software\Classes\DongMePhim.webm\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"; Tasks: associatefiles
Root: HKCU; Subkey: "Software\Classes\DongMePhim.webm\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: associatefiles

; ============================================================
; [Code] - Xử lý tự động:
;   1. Kill app nếu đang chạy (trước khi cài hoặc gỡ)
;   2. Gỡ bản cũ 4.7.5 (hoặc bất kỳ bản nào cùng AppId) trước khi cài 5.0.0
; ============================================================
[Code]

// --- Hằng số ---
const
  APP_EXE_NAME = 'tphimx_setup.exe';
  // AppId của bản cũ (4.7.5) - dùng chung AppId nên tìm qua registry
  OLD_UNINSTALL_KEY = 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{B4F5A6D2-3E1C-4F8A-9D7B-2C6E8F1A5D3B}_is1';

// --- Kill process nếu đang chạy ---
function KillAppIfRunning(): Boolean;
var
  ResultCode: Integer;
begin
  Result := True;
  // Dùng taskkill để kill toàn bộ instance
  if Exec('taskkill', '/F /IM ' + APP_EXE_NAME, '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    // Chờ thêm 1 giây cho process thực sự kết thúc
    Sleep(1000);
    Log('Killed ' + APP_EXE_NAME + ' (exit code: ' + IntToStr(ResultCode) + ')');
  end
  else
    Log(APP_EXE_NAME + ' was not running or could not be killed.');
end;

// --- Lấy đường dẫn uninstaller của bản cũ ---
function GetOldUninstallString(): String;
var
  sUnInstPath: String;
begin
  Result := '';
  // Thử HKCU trước (PrivilegesRequired=lowest)
  if RegQueryStringValue(HKCU, OLD_UNINSTALL_KEY, 'UninstallString', sUnInstPath) then
    Result := sUnInstPath
  else if RegQueryStringValue(HKLM, OLD_UNINSTALL_KEY, 'UninstallString', sUnInstPath) then
    Result := sUnInstPath;
end;

// --- Lấy version hiện tại đã cài ---
function GetInstalledVersion(): String;
var
  sVersion: String;
begin
  Result := '';
  if RegQueryStringValue(HKCU, OLD_UNINSTALL_KEY, 'DisplayVersion', sVersion) then
    Result := sVersion
  else if RegQueryStringValue(HKLM, OLD_UNINSTALL_KEY, 'DisplayVersion', sVersion) then
    Result := sVersion;
end;

// --- Gỡ bản cũ nếu version khác với bản đang cài ---
function UninstallOldVersion(): Boolean;
var
  sUnInstallString: String;
  sInstalledVersion: String;
  iResultCode: Integer;
begin
  Result := True;

  sInstalledVersion := GetInstalledVersion();

  // Chỉ uninstall nếu version khác với bản mới (5.0.0)
  // Ví dụ: đang cài 5.0.0 đè lên 4.7.5
  if (sInstalledVersion <> '') and (sInstalledVersion <> '{#MyAppVersion}') then
  begin
    Log('Found old version: ' + sInstalledVersion + '. Uninstalling...');

    sUnInstallString := GetOldUninstallString();
    if sUnInstallString <> '' then
    begin
      // Chạy uninstaller ở chế độ silent
      sUnInstallString := RemoveQuotes(sUnInstallString);
      if Exec(sUnInstallString, '/SILENT /NORESTART', '', SW_HIDE, ewWaitUntilTerminated, iResultCode) then
      begin
        Log('Old version uninstalled (exit code: ' + IntToStr(iResultCode) + ')');
        Sleep(1500);
      end
      else
      begin
        Log('Failed to uninstall old version.');
        Result := False;
      end;
    end;
  end
  else
    Log('No old version found or same version, skipping uninstall.');
end;

// --- Hook: Trước khi bắt đầu cài ---
function InitializeSetup(): Boolean;
begin
  // 1. Kill app nếu đang chạy
  KillAppIfRunning();

  // 2. Gỡ bản cũ (khác version)
  UninstallOldVersion();

  Result := True;
end;

// --- Hook: Trước khi bắt đầu gỡ ---
function InitializeUninstall(): Boolean;
begin
  // Kill app nếu đang chạy khi người dùng gỡ cài đặt
  KillAppIfRunning();
  Result := True;
end;
