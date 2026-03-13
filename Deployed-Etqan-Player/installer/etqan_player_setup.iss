; Inno Setup Script for Samy Player (مشغل منصة المبدع)
; هذا الملف يستخدم لإنشاء ملف تثبيت Setup.exe

#define AppName "مشغل إتقان التعليمي"
#define AppVersion "1.0.0"
#define AppPublisher "Etqan"
#define AppURL "https://etqan.com"
#define AppExeName "etqan_player.exe"
#define BuildPath "..\build\windows\x64\runner\Release"
#define OutputDir "output"

[Setup]
; معلومات التطبيق
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}
; استخدام مسار إنجليزي لتجنب مشاكل المسارات العربية في Windows API
; الاسم العربي يظهر في الواجهة فقط (AppName و DefaultGroupName)
DefaultDirName={autopf}\EtqanEducationalPlayer
DefaultGroupName=Etqan Educational Player
AllowNoIcons=yes
LicenseFile=
OutputDir={#OutputDir}
OutputBaseFilename=Etqan_Educational_Player_Installer
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

; اللغة
[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
; يمكن إضافة ملفات لغة عربية لاحقاً
; Name: "arabic"; MessagesFile: "compiler:Languages\Arabic.isl"

; الصفحات
[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 6.1; Check: not IsAdminInstallMode

; الملفات المراد تثبيتها
[Files]
; الملف التنفيذي الرئيسي
Source: "{#BuildPath}\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion

; جميع ملفات DLL المطلوبة - نسخ صريح لكل ملف DLL
Source: "{#BuildPath}\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildPath}\libmpv-2.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildPath}\libEGL.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildPath}\libGLESv2.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildPath}\d3dcompiler_47.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildPath}\vk_swiftshader.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildPath}\vulkan-1.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildPath}\zlib.dll"; DestDir: "{app}"; Flags: ignoreversion

; جميع ملفات DLL الأخرى (plugins)
Source: "{#BuildPath}\*.dll"; DestDir: "{app}"; Flags: ignoreversion; Excludes: "flutter_windows.dll,libmpv-2.dll,libEGL.dll,libGLESv2.dll,d3dcompiler_47.dll,vk_swiftshader.dll,vulkan-1.dll,zlib.dll"

; مجلد data (يحتوي على flutter_assets وملفات أخرى) - نسخ كامل مع جميع المحتويات
Source: "{#BuildPath}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

; ملفات native_assets (إن وجدت)
Source: "{#BuildPath}\native_assets\*"; DestDir: "{app}\native_assets"; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist

; استثناء ملفات التطوير (PDB files)
; Source: "{#BuildPath}\*.pdb"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

; الاختصارات
[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#AppName}"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"; Tasks: quicklaunchicon

; سجل Windows
[Registry]
; تسجيل URL Scheme للـ Deep Linking
Root: HKCR; Subkey: "etqanplayer"; ValueType: string; ValueData: "URL:Etqan Player Protocol"; Flags: uninsdeletekey
Root: HKCR; Subkey: "etqanplayer"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKCR; Subkey: "etqanplayer\DefaultIcon"; ValueType: string; ValueData: "{app}\{#AppExeName},0"
Root: HKCR; Subkey: "etqanplayer\shell\open\command"; ValueType: string; ValueData: """{app}\{#AppExeName}"" ""%1"""

; إجراءات ما بعد التثبيت
[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent; WorkingDir: "{app}"

; إجراءات ما قبل الإلغاء
[UninstallDelete]
Type: filesandordirs; Name: "{app}"

[Code]
// كود مخصص للتحقق من المتطلبات
function InitializeSetup(): Boolean;
begin
  // هذه الدالة يتم استدعاؤها عند تشغيل installer (ليس عند بنائه)
  // الملفات يجب أن تكون موجودة في installer نفسه (مضمنة)
  // لا نحتاج للتحقق من مجلد البناء هنا
  Result := True;
end;

function InitializeUninstall(): Boolean;
begin
  Result := True;
end;
