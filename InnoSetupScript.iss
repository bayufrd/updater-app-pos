[Setup]
AppName=KASIR App Gaspoll Installer DT
AppVersion=1.0
AppPublisher=DTCoding
AppPublisherURL=http://dastrevas.com
AppSupportURL=http://dastrevas.com/support
AppUpdatesURL=http://gaspollmanagementcenter.com/server/update.zip

DefaultDirName={pf}\DTCoding\KASIRinstaller
DefaultGroupName=KASIR
WizardStyle=modern
WizardImageFile=DT-Logo.bmp
WizardImageStretch=no
WizardImageBackColor=$ffffff

Compression=lzma
SolidCompression=yes
MinVersion=6.1

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Buat desktop icon"; GroupDescription: "Additional icons:"; Flags: unchecked
Name: "startmenuicon"; Description: "Buat Start Menu icon"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
Source: "C:\Users\Bayu Farid\Documents\GitHub\DTCoding\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion
Source: "C:\Users\Bayu Farid\Documents\GitHub\DTCoding\0fa224138685e.png.ico"; DestDir: "{app}"; Flags: onlyifdoesntexist

[Icons]
Name: "{group}\KASIR App Gaspoll"; Filename: "{app}\KASIR.exe"; IconFilename: "{app}\0fa224138685e.png.ico"
Name: "{group}\Uninstall KASIR App"; Filename: "{uninstallexe}"; IconFilename: "{sys}\shell32.dll,31"
Name: "{commondesktop}\KASIR App Gaspoll"; Filename: "{app}\KASIR.exe"; IconFilename: "{app}\0fa224138685e.png.ico"; Tasks: desktopicon

[Run]
Filename: "{app}\KASIR.exe"; Description: "Jalankan KASIR App"; Flags: postinstall nowait skipifsilent unchecked

[UninstallDelete]
Type: filesandordirs; Name: "{app}"

[Registry]
Root: HKCU; Subkey: "Software\DTCoding\KASIR"; ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"; Flags: uninsdeletevalue

[Code]

// Fungsi untuk memeriksa instalasi .NET 6.0 atau lebih baru
// Fungsi untuk memeriksa instalasi .NET 6.0 atau lebih baru
function IsDotNet6Installed(): Boolean;
var
  Keys: TArrayOfString;
  I, Major: Integer;
  Version: string;
begin
  Result := False;

  // Cek subkey di registry untuk runtime
  if RegGetSubkeyNames(
    HKEY_LOCAL_MACHINE,
    'SOFTWARE\dotnet\Setup\InstalledVersions\x64\sharedfx\Microsoft.NETCore.App',
    Keys
  ) then
  begin
    for I := 0 to GetArrayLength(Keys) - 1 do
    begin
      Version := Keys[I];
      Major := StrToIntDef(Copy(Version, 1, Pos('.', Version) - 1), 0);

      // Kalau ada versi 6 atau lebih besar → dianggap installed
      if Major >= 6 then
      begin
        Result := True;
        Exit;
      end;
    end;
  end;
end;


// Fungsi inisialisasi setup
function InitializeSetup(): Boolean;
var
  Version: TWindowsVersion;
  NetInstallResponse: Integer;
  ErrorCode: Integer;
begin
  GetWindowsVersionEx(Version);

  // Cek versi Windows minimal 7 (6.1)
  if (Version.Major < 6) or ((Version.Major = 6) and (Version.Minor < 1)) then
  begin
    MsgBox('Aplikasi membutuhkan Windows 7 atau lebih tinggi.', mbError, MB_OK);
    Result := False;
    Exit;
  end;

  // Cek .NET 6.0 atau lebih baru
  if not IsDotNet6Installed() then
  begin
    NetInstallResponse := MsgBox(
      '⚠ .NET Runtime 6.0 atau lebih baru tidak terdeteksi.'#13#10 +
      'Aplikasi mungkin tidak bisa dijalankan sebelum Anda menginstal .NET Runtime.'#13#10#13#10 +
      'Apakah Anda ingin membuka halaman unduhan resmi .NET Runtime sekarang?',
      mbConfirmation, MB_YESNO
    );

    if NetInstallResponse = IDYES then
    begin
      ShellExec(
        '',
        'https://dotnet.microsoft.com/download/dotnet/6.0/runtime',
        '',
        '',
        SW_SHOWNORMAL,
        ewNoWait,
        ErrorCode
      );
    end;

    // ⚡ Bedanya di sini: tetap lanjut install
    Result := True;
  end
  else
    Result := True;
end;

