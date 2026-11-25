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
; Optional: /DEngineDir=<folder with angelscript-<version>[-jit].exe, one build per AngelScript release> and
; /DEngineList=<entries separated by ;, newest first>. An entry is <version>|<jit>|<missing add-ons>, where <jit> is 1
; when angelscript-<version>-jit.exe exists and <missing add-ons> lists, separated by commas, what the release lacks.
; Each release becomes one radio button (the setup installs one release, like Python), and a release with a JIT build
; gets a check box under it. Without /DEngineDir the setup installs SourceExe only.

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
english.EnginesGroup=AngelScript release (choose one)
english.Current=current
english.JitNone=no JIT
english.JitAvailable=JIT available
english.AddonsAll=all add-ons
english.AddonsMissing=without
english.UseJit=Use the JIT compiler (experimental, 64-bit)
spanish.MainComponent=Línea de comandos de AngelScript (angelscript, asc)
spanish.EnginesGroup=Versión de AngelScript (elige una)
spanish.Current=actual
spanish.JitNone=sin JIT
spanish.JitAvailable=JIT disponible
spanish.AddonsAll=todos los add-ons
spanish.AddonsMissing=sin
spanish.UseJit=Usar el compilador JIT (experimental, 64 bits)

#ifdef EngineDir
#ifndef EngineList
  #error Pass /DEngineList=<entries separated by ;> together with /DEngineDir
#endif
; One radio button per release, newest first: engines\as2_38_0 installs the build of AngelScript 2.38.0 as
; angelscript.exe, asc.exe and angelscript-cli.exe. engines\as2_38_0\jit selects the JIT variant of it.
#define EngineRest ""
#define EngineEntry ""
#define EngineVersion ""
#define EngineId ""
#define EngineJit ""
#define EngineMissing ""
#define EngineIndex 0
#define EngineTypes ""
#define EngineNote ""
#define EngineJitText ""
#define EngineAddonsText ""
#sub ParseEngineEntry
  #expr EngineEntry = Copy(EngineRest, 1, Pos(";", EngineRest) - 1)
  #expr EngineVersion = Copy(EngineEntry, 1, Pos("|", EngineEntry) - 1)
  #expr EngineEntry = Copy(EngineEntry, Pos("|", EngineEntry) + 1)
  #expr EngineJit = Copy(EngineEntry, 1, Pos("|", EngineEntry) - 1)
  #expr EngineMissing = Copy(EngineEntry, Pos("|", EngineEntry) + 1)
  #expr EngineId = "as" + StringChange(EngineVersion, ".", "_")
#endsub
#sub EmitEngineComponent
  #expr ParseEngineEntry
  ; Only the newest release belongs to the setup types, so it is the one a plain install gets. The others have no type
  ; and are picked by hand, which also keeps the exclusive radio buttons from all being preselected.
  #if EngineIndex == 0
    #expr EngineTypes = " Types: full compact custom;"
    #expr EngineNote = " ({cm:Current})"
  #else
    #expr EngineTypes = ""
    #expr EngineNote = ""
  #endif
  #if EngineJit == "1"
    #expr EngineJitText = "{cm:JitAvailable}"
  #else
    #expr EngineJitText = "{cm:JitNone}"
  #endif
  #if EngineMissing == ""
    #expr EngineAddonsText = "{cm:AddonsAll}"
  #else
    #expr EngineAddonsText = "{cm:AddonsMissing} " + StringChange(EngineMissing, ",", ", ")
  #endif
Name: "engines\{#EngineId}"; Description: "AngelScript {#EngineVersion}{#EngineNote} - {#EngineJitText} - {#EngineAddonsText}";{#EngineTypes} Flags: exclusive
  #if EngineJit == "1"
Name: "engines\{#EngineId}\jit"; Description: "{cm:UseJit}"
  #endif
  #expr EngineIndex = EngineIndex + 1
#endsub
#sub EmitEngineFile
  #expr ParseEngineEntry
  #if EngineJit == "1"
Source: "{#EngineDir}\angelscript-{#EngineVersion}.exe"; DestDir: "{app}"; DestName: "angelscript.exe"; Components: "engines\{#EngineId} and not engines\{#EngineId}\jit"; Flags: ignoreversion
Source: "{#EngineDir}\angelscript-{#EngineVersion}.exe"; DestDir: "{app}"; DestName: "asc.exe"; Components: "engines\{#EngineId} and not engines\{#EngineId}\jit"; Flags: ignoreversion
Source: "{#EngineDir}\angelscript-{#EngineVersion}.exe"; DestDir: "{app}"; DestName: "angelscript-cli.exe"; Components: "engines\{#EngineId} and not engines\{#EngineId}\jit"; Flags: ignoreversion
Source: "{#EngineDir}\angelscript-{#EngineVersion}-jit.exe"; DestDir: "{app}"; DestName: "angelscript.exe"; Components: "engines\{#EngineId}\jit"; Flags: ignoreversion
Source: "{#EngineDir}\angelscript-{#EngineVersion}-jit.exe"; DestDir: "{app}"; DestName: "asc.exe"; Components: "engines\{#EngineId}\jit"; Flags: ignoreversion
Source: "{#EngineDir}\angelscript-{#EngineVersion}-jit.exe"; DestDir: "{app}"; DestName: "angelscript-cli.exe"; Components: "engines\{#EngineId}\jit"; Flags: ignoreversion
  #else
Source: "{#EngineDir}\angelscript-{#EngineVersion}.exe"; DestDir: "{app}"; DestName: "angelscript.exe"; Components: "engines\{#EngineId}"; Flags: ignoreversion
Source: "{#EngineDir}\angelscript-{#EngineVersion}.exe"; DestDir: "{app}"; DestName: "asc.exe"; Components: "engines\{#EngineId}"; Flags: ignoreversion
Source: "{#EngineDir}\angelscript-{#EngineVersion}.exe"; DestDir: "{app}"; DestName: "angelscript-cli.exe"; Components: "engines\{#EngineId}"; Flags: ignoreversion
  #endif
#endsub

[Components]
Name: "main"; Description: "{cm:MainComponent}"; Types: full compact custom; Flags: fixed
Name: "engines"; Description: "{cm:EnginesGroup}"; Types: full compact custom; Flags: fixed
#for {EngineRest = EngineList + ";"; EngineRest != ""; EngineRest = Copy(EngineRest, Pos(";", EngineRest) + 1)} EmitEngineComponent
#endif

[Tasks]
Name: "addtopath"; Description: "Add AngelScript to the &PATH environment variable"; GroupDescription: "Environment:"

[InstallDelete]
; Setup 1.1 installed the other releases next to the default one as angelscript-<version>.exe. A setup installs one release now.
Type: files; Name: "{app}\angelscript-2.*.exe"

[Files]
#ifndef EngineDir
Source: "{#SourceExe}"; DestDir: "{app}"; DestName: "angelscript.exe"; Flags: ignoreversion
Source: "{#SourceExe}"; DestDir: "{app}"; DestName: "asc.exe"; Flags: ignoreversion
Source: "{#SourceExe}"; DestDir: "{app}"; DestName: "angelscript-cli.exe"; Flags: ignoreversion
#endif
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
