; MP - instalador
; Genera un unico "Instalador MP.exe" que instala la app completa
; (server + web + voz + grabadora) en la carpeta del usuario, SIN admin.

#define NombreApp "MP"
#define VersionApp "1.0"
#define CarpetaSalida "salida"
#define CarpetaOrigen "MPapp"

[Setup]
AppName={#NombreApp}
AppVersion={#VersionApp}
AppPublisher=MP
DefaultDirName={localappdata}\MP
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir={#CarpetaSalida}
OutputBaseFilename=Instalador MP v{#VersionApp}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\icono.ico
SetupIconFile={#CarpetaOrigen}\icono.ico
CloseApplications=no

[Files]
; Los *.bak son respaldes de trabajo: NUNCA deben acabar en la instalacion del
; cliente (ademas ocupan ~3 MB y confunden si alguien abre la carpeta).
Source: "{#CarpetaOrigen}\*"; DestDir: "{app}"; Excludes: "*.bak,teclas_rama.json,prefs-voz.json,prefs-grabacion.json,MP_puertos.json"; Flags: recursesubdirs createallsubdirs
; Datos del USUARIO: nunca sobrescribir si ya existen (solo se crean en una
; instalacion limpia) y no borrarlos al desinstalar, para no perder las teclas,
; preferencias ni los puertos que el usuario ya tenia configurados.
Source: "{#CarpetaOrigen}\teclas_rama.json"; DestDir: "{app}"; Flags: onlyifdoesntexist uninsneveruninstall
Source: "{#CarpetaOrigen}\prefs-voz.json"; DestDir: "{app}"; Flags: onlyifdoesntexist uninsneveruninstall
Source: "{#CarpetaOrigen}\prefs-grabacion.json"; DestDir: "{app}"; Flags: onlyifdoesntexist uninsneveruninstall
Source: "{#CarpetaOrigen}\MP_puertos.json"; DestDir: "{app}"; Flags: onlyifdoesntexist uninsneveruninstall

[Tasks]
Name: "desktopicon"; Description: "Crear acceso directo en el escritorio"; GroupDescription: "Accesos directos:"

[Icons]
Name: "{group}\{#NombreApp}"; Filename: "{sys}\wscript.exe"; Parameters: """{app}\Iniciar MP oculto.vbs"""; WorkingDir: "{app}"; IconFilename: "{app}\icono.ico"; Flags: createonlyiffileexists; MinVersion: 0,6.0
Name: "{autodesktop}\{#NombreApp}"; Filename: "{sys}\wscript.exe"; Parameters: """{app}\Iniciar MP oculto.vbs"""; WorkingDir: "{app}"; IconFilename: "{app}\icono.ico"; Tasks: desktopicon; Flags: createonlyiffileexists
Name: "{group}\{#NombreApp} (por si la ventana no aparece)"; Filename: "{sys}\wscript.exe"; Parameters: """{app}\Abrir MP oculto.vbs"""; WorkingDir: "{app}"; IconFilename: "{app}\icono.ico"; Flags: createonlyiffileexists

[Run]
Filename: "{sys}\wscript.exe"; Parameters: """{app}\Iniciar MP oculto.vbs"""; Description: "Abrir MP ahora"; Flags: nowait postinstall skipifsilent

[Code]
// Antes de instalar, cerramos CUALQUIER instancia previa de MP (server,
// grabadora, voz) y las ventanas de MP en Edge. Así el install siempre termina
// con UNA sola instancia y UNA sola ventana, sin duplicados.
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  PID: Longint;
begin
  Result := '';
  Exec('powershell.exe',
    '-NoProfile -NonInteractive -WindowStyle Hidden -Command "' +
    'Get-Process msedge -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -like ''MP *'' } | ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }; ' +
    'Get-CimInstance Win32_Process | Where-Object { ($_.Name -eq ''node.exe'' -or $_.Name -eq ''python.exe'') -and ($_.CommandLine -match ''server_nuevo\.js'' -or $_.CommandLine -match ''grabador\.py'' -or $_.CommandLine -match ''voz_servicio'') } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }"',
    '', SW_HIDE, ewWaitUntilTerminated, PID);
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  PID: Longint;
  Msg: string;
begin
  if CurUninstallStep = usUninstall then
  begin
    Msg := 'Antes de desinstalar, cierra la ventana "MP - servicio local" si está abierta.'
    Msg := Msg + #13#10 + '¿Quieres que cierre los procesos de MP por ti?';
    if MsgBox(Msg, mbConfirmation, MB_YESNO) = IDYES then
    begin
      Exec('powershell.exe', '-NoProfile -NonInteractive -Command "Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match ''server_nuevo\.js'' -or $_.CommandLine -match ''grabador\.py'' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }"', '', SW_HIDE, ewWaitUntilTerminated, PID);
    end;
  end;
end;