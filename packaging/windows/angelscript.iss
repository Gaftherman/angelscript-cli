; Inno Setup script for the AngelScript command line.
; Build: ISCC /DAppVersion=x.y.z /DSourceExe=<angelscript.exe> /DLicenseFile=<LICENSE> /DOutputDir=<dir> angelscript.iss

#ifndef AppVersion
  #error Pass /DAppVersion=x.y.z
#endif
#ifndef SourceExe
  #error Pass /DSourceExe=<path to angelscript.exe>
#endif
#ifndef LicenseFile
  #error Pass /DLicenseFile=<path to LICENSE>
#endif
#ifndef NoticesFile
  #error Pass /DNoticesFile=<path to THIRD_PARTY_NOTICES.md>
#endif
#ifndef AppArch
  #define AppArch "x64"
#endif
#ifndef OutputDir
  #define OutputDir "."
#endif
; Optional: /DAppArch=x86 builds the 32-bit setup (default x64).
; Optional: /DEngineDir=<folder with angelscript-<version>.exe builds against other AngelScript releases> and
; /DEngineList=<those versions separated by ;, newest first>. Each version becomes its own component.

[Setup]
AppId={{7F3C9A52-6B1E-4D8A-9C0F-2A5E4B7D1C38}
AppName=AngelScript
AppVersion={#AppVersion}
AppVerName=AngelScript {#AppVersion}
AppPublisher=Gaftherman
AppPublisherURL=https://github.com/Gaftherman/angelscript-cli
AppSupportURL=https://github.com/Gaftherman/angelscript-cli/issues
AppUpdatesURL=https://github.com/Gaftherman/angelscript-cli/releases
VersionInfoVersion={#AppVersion}
DefaultDirName={autopf}\AngelScript
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
#if AppArch == "x86"
ArchitecturesAllowed=x86compatible
#else
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
#endif
LicenseFile={#LicenseFile}
OutputDir={#OutputDir}
OutputBaseFilename=angelscript-cli-{#AppVersion}-windows-{#AppArch}-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ShowLanguageDialog=auto
ChangesEnvironment=yes
UninstallDisplayName=AngelScript {#AppVersion}
UninstallDisplayIcon={app}\angelscript.exe

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[CustomMessages]
english.MainComponent=AngelScript command line (angelscript, asc)
english.EnginesGroup=Builds against other AngelScript releases
spanish.MainComponent=Línea de comandos de AngelScript (angelscript, asc)
spanish.EnginesGroup=Compilaciones con otras versiones de AngelScript

#ifdef EngineDir
#ifndef EngineList
  #error Pass /DEngineList=<versions separated by ;> together with /DEngineDir
#endif
; One component per engine version, newest first: engines\as2_38_0 installs angelscript-2.38.0.exe.
#define EngineRest ""
#define EngineVersion ""
#define EngineId ""
#sub EmitEngineComponent
  #expr EngineVersion = Copy(EngineRest, 1, Pos(";", EngineRest) - 1)
  #expr EngineId = "as" + StringChange(EngineVersion, ".", "_")
Name: "engines\{#EngineId}"; Description: "AngelScript {#EngineVersion} (angelscript-{#EngineVersion}.exe)"; Types: full custom
#endsub
#sub EmitEngineFile
  #expr EngineVersion = Copy(EngineRest, 1, Pos(";", EngineRest) - 1)
  #expr EngineId = "as" + StringChange(EngineVersion, ".", "_")
Source: "{#EngineDir}\angelscript-{#EngineVersion}.exe"; DestDir: "{app}"; Components: "engines\{#EngineId}"; Flags: ignoreversion
#endsub

[Components]
Name: "main"; Description: "{cm:MainComponent}"; Types: full compact custom; Flags: fixed
Name: "engines"; Description: "{cm:EnginesGroup}"; Types: full custom
#for {EngineRest = EngineList + ";"; EngineRest != ""; EngineRest = Copy(EngineRest, Pos(";", EngineRest) + 1)} EmitEngineComponent
#endif

[Tasks]
Name: "addtopath"; Description: "Add AngelScript to the &PATH environment variable"; GroupDescription: "Environment:"

[Files]
Source: "{#SourceExe}"; DestDir: "{app}"; DestName: "angelscript.exe"; Flags: ignoreversion
Source: "{#SourceExe}"; DestDir: "{app}"; DestName: "asc.exe"; Flags: ignoreversion
Source: "{#SourceExe}"; DestDir: "{app}"; DestName: "angelscript-cli.exe"; Flags: ignoreversion
Source: "{#LicenseFile}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#NoticesFile}"; DestDir: "{app}"; Flags: ignoreversion
#ifdef EngineDir
#for {EngineRest = EngineList + ";"; EngineRest != ""; EngineRest = Copy(EngineRest, Pos(";", EngineRest) + 1)} EmitEngineFile
#endif

[Code]
function EnvironmentRoot(): Integer;
begin
  if IsAdminInstallMode then
    Result := HKEY_LOCAL_MACHINE
  else
    Result := HKEY_CURRENT_USER;
end;

function EnvironmentSubkey(): String;
begin
  if IsAdminInstallMode then
    Result := 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
  else
    Result := 'Environment';
end;

function ReadUserPath(var Value: String): Boolean;
begin
  Result := RegQueryStringValue(EnvironmentRoot(), EnvironmentSubkey(), 'Path', Value);
end;

procedure AddToPath(Directory: String);
var
  Current: String;
begin
  if not ReadUserPath(Current) then
    Current := '';
  if Pos(';' + Lowercase(Directory) + ';', ';' + Lowercase(Current) + ';') > 0 then
    exit;
  if (Current <> '') and (Current[Length(Current)] <> ';') then
    Current := Current + ';';
  RegWriteExpandStringValue(EnvironmentRoot(), EnvironmentSubkey(), 'Path', Current + Directory);
end;

procedure RemoveFromPath(Directory: String);
var
  Current, Kept, Entry: String;
  Separator: Integer;
begin
  if not ReadUserPath(Current) then
    exit;
  Kept := '';
  while Current <> '' do
  begin
    Separator := Pos(';', Current);
    if Separator = 0 then
    begin
      Entry := Current;
      Current := '';
    end
    else
    begin
      Entry := Copy(Current, 1, Separator - 1);
      Current := Copy(Current, Separator + 1, Length(Current));
    end;
    if (Entry <> '') and (CompareText(Entry, Directory) <> 0) then
    begin
      if Kept <> '' then
        Kept := Kept + ';';
      Kept := Kept + Entry;
    end;
  end;
  RegWriteExpandStringValue(EnvironmentRoot(), EnvironmentSubkey(), 'Path', Kept);
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if (CurStep = ssPostInstall) and WizardIsTaskSelected('addtopath') then
    AddToPath(ExpandConstant('{app}'));
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
    RemoveFromPath(ExpandConstant('{app}'));
end;
