; Taskbar Pull - per-user installer (no administrator rights needed).
; Built by build\build.ps1:  ISCC /DAppVersion=1.0.0 /DStageDir=<dist\stage\TaskbarPull> /DOutDir=<dist> /DRepoUrl=<url> TaskbarPull.iss
;
; Installs to %LOCALAPPDATA%\Programs\Taskbar Pull, adds a Start menu shortcut and, optionally,
; the HKCU Run entry "Taskbar Pull". The uninstaller stops the app, removes the Run entry and the
; admin-mode task (UAC prompt only if that task exists), and asks whether to keep the settings.

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#ifndef StageDir
  #define StageDir "..\..\dist\stage\TaskbarPull"
#endif
#ifndef OutDir
  #define OutDir "..\..\dist"
#endif
#ifndef RepoUrl
  #define RepoUrl "https://github.com/OWNER/taskbar-pull"
#endif

[Setup]
AppId={{4C6A7F2E-1B3D-4E58-9A0C-7D2E5B9F1A63}
AppName=Taskbar Pull
AppVersion={#AppVersion}
AppVerName=Taskbar Pull {#AppVersion}
AppPublisher=Yasser Chkam
AppPublisherURL={#RepoUrl}
AppSupportURL={#RepoUrl}/issues
AppUpdatesURL={#RepoUrl}/releases
AppCopyright=Copyright (c) 2026 Yasser Chkam
VersionInfoVersion={#AppVersion}.0
VersionInfoDescription=Taskbar Pull setup
DefaultDirName={autopf}\Taskbar Pull
DisableProgramGroupPage=yes
DisableDirPage=auto
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
OutputDir={#OutDir}
OutputBaseFilename=TaskbarPull-{#AppVersion}-setup
SetupIconFile={#StageDir}\assets\TaskbarPull.ico
UninstallDisplayIcon={app}\assets\TaskbarPull.ico
UninstallDisplayName=Taskbar Pull
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
LicenseFile={#StageDir}\LICENSE.txt

[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"
Name: "fr"; MessagesFile: "compiler:Languages\French.isl"

[CustomMessages]
en.StartWithWindows=Start Taskbar Pull with &Windows
fr.StartWithWindows=Lancer Taskbar Pull au démarrage de &Windows
en.KeepSettings=Keep your Taskbar Pull settings and logs?%n%nChoose No to remove them too.
fr.KeepSettings=Conserver les paramètres et le journal de Taskbar Pull ?%n%nChoisissez Non pour les supprimer aussi.
en.AdminTask=Taskbar Pull's admin mode is on. Windows will ask for confirmation to remove its scheduled task.
fr.AdminTask=Le mode administrateur de Taskbar Pull est activé. Windows va demander une confirmation pour supprimer sa tâche planifiée.

[Tasks]
Name: "startup"; Description: "{cm:StartWithWindows}"

[Files]
Source: "{#StageDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{userprograms}\Taskbar Pull"; Filename: "{app}\TaskbarPull.exe"; WorkingDir: "{app}"; IconFilename: "{app}\assets\TaskbarPull.ico"; Comment: "Bring a window to the screen whose taskbar you click"

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "Taskbar Pull"; ValueData: """{app}\TaskbarPull.exe"""; Flags: uninsdeletevalue; Tasks: startup

[Run]
Filename: "{app}\TaskbarPull.exe"; Description: "{cm:LaunchProgram,Taskbar Pull}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; ask a running Taskbar Pull (normal or elevated) to exit before its files are removed
Filename: "{app}\TaskbarPull.exe"; Parameters: """{app}\TaskbarPull.ahk"" /quit"; WorkingDir: "{app}"; Flags: runhidden waituntilterminated; RunOnceId: "QuitTaskbarPull"

[UninstallDelete]
Type: filesandordirs; Name: "{app}\lib"
Type: filesandordirs; Name: "{app}\assets"
Type: dirifempty; Name: "{app}"

[Code]
const
  AdminTask = 'Taskbar Pull (admin mode)';

function AdminTaskExists(): Boolean;
var
  Code: Integer;
begin
  Result := Exec(ExpandConstant('{sys}\schtasks.exe'), '/Query /TN "' + AdminTask + '"', '', SW_HIDE, ewWaitUntilTerminated, Code) and (Code = 0);
end;

procedure StopRunningApp();
var
  Code: Integer;
begin
  if FileExists(ExpandConstant('{app}\TaskbarPull.exe')) then
    Exec(ExpandConstant('{app}\TaskbarPull.exe'), AddQuotes(ExpandConstant('{app}\TaskbarPull.ahk')) + ' /quit', ExpandConstant('{app}'), SW_HIDE, ewWaitUntilTerminated, Code);
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  { an upgrade: stop the running copy so its files can be replaced }
  StopRunningApp();
  Result := '';
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Code: Integer;
begin
  if CurUninstallStep = usUninstall then
  begin
    { the app may have written the Run entry itself (start with Windows chosen in the app) }
    RegDeleteValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Run', 'Taskbar Pull');
    if AdminTaskExists() then
    begin
      if not UninstallSilent() then
        MsgBox(CustomMessage('AdminTask'), mbInformation, MB_OK);
      ShellExec('runas', ExpandConstant('{sys}\schtasks.exe'), '/Delete /TN "' + AdminTask + '" /F', '', SW_HIDE, ewWaitUntilTerminated, Code);
    end;
  end;
  { silent uninstall keeps the settings; otherwise ask }
  if (CurUninstallStep = usPostUninstall) and not UninstallSilent() then
    if MsgBox(CustomMessage('KeepSettings'), mbConfirmation, MB_YESNO or MB_DEFBUTTON1) = IDNO then
    begin
      DelTree(ExpandConstant('{userappdata}\Taskbar Pull'), True, True, True);
      DelTree(ExpandConstant('{localappdata}\Taskbar Pull'), True, True, True);
    end;
end;
