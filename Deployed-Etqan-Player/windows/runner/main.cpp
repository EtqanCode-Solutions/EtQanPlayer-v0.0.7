#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <string>
#include <fstream>
#include <sstream>
#include <vector>
#include <locale>
#include <codecvt>

#include "flutter_window.h"
#include "utils.h"

// For FlashWindowEx
#ifndef FLASHWINFO
#include <winuser.h>
#endif

// Single Instance: Mutex name
static const wchar_t* kSingleInstanceMutexName = L"EtqanPlayer_SingleInstance_Mutex";
// Custom message for activating existing window
static const UINT WM_ACTIVATE_WINDOW = WM_USER + 1;

// دالة مساعدة للحصول على المسار الكامل (Long Path) لدعم المسارات العربية
std::wstring GetLongPath(const std::wstring& path) {
  wchar_t longPath[MAX_PATH * 4]; // دعم مسارات أطول
  DWORD result = GetLongPathNameW(path.c_str(), longPath, MAX_PATH * 4);
  if (result > 0 && result < MAX_PATH * 4) {
    return std::wstring(longPath);
  }
  return path; // إرجاع المسار الأصلي إذا فشل
}

// دالة مساعدة لتحويل wstring إلى UTF-8 string
std::string WStringToUTF8(const std::wstring& wstr) {
  if (wstr.empty()) return std::string();
  int size_needed = WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), NULL, 0, NULL, NULL);
  if (size_needed <= 0) return std::string();
  std::string strTo(size_needed, 0);
  int converted = WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), &strTo[0], size_needed, NULL, NULL);
  if (converted <= 0) return std::string();
  return strTo;
}

// دالة مساعدة لكتابة نص في ملف مع encoding صحيح
void WriteToFile(const std::wstring& filePath, const std::wstring& content) {
  try {
    // استخدام FILE* بدلاً من wofstream لدعم أفضل للأحرف العربية
    FILE* file = nullptr;
    if (_wfopen_s(&file, filePath.c_str(), L"a, ccs=UTF-8") == 0 && file != nullptr) {
      fwprintf_s(file, L"%s\n", content.c_str());
      fflush(file);
      fclose(file);
    }
  } catch (...) {
    // Silently fail
  }
}

// دالة تسجيل الأخطاء في ملف log
void WriteLog(const std::wstring& message) {
  try {
    wchar_t exePathBuffer[MAX_PATH * 4];
    std::wstring logPath;
    bool useTempPath = false;
    
    // محاولة فتح ملف log في مجلد التطبيق
    if (GetModuleFileNameW(nullptr, exePathBuffer, MAX_PATH * 4) != 0) {
      std::wstring exePath = GetLongPath(std::wstring(exePathBuffer));
      size_t lastSlash = exePath.find_last_of(L"\\/");
      if (lastSlash != std::wstring::npos) {
        std::wstring exeDir = exePath.substr(0, lastSlash);
        logPath = exeDir + L"\\etqan_player.log";
        
        // محاولة الكتابة في ملف log
        SYSTEMTIME st;
        GetLocalTime(&st);
        std::wstring logMessage = L"[" + std::to_wstring(st.wYear) + L"-" + 
                                 std::to_wstring(st.wMonth) + L"-" + 
                                 std::to_wstring(st.wDay) + L" " +
                                 std::to_wstring(st.wHour) + L":" + 
                                 std::to_wstring(st.wMinute) + L":" + 
                                 std::to_wstring(st.wSecond) + L"] " + message;
        
        WriteToFile(logPath, logMessage);
        
        // التحقق من نجاح الكتابة
        FILE* testFile = nullptr;
        if (_wfopen_s(&testFile, logPath.c_str(), L"r, ccs=UTF-8") == 0 && testFile != nullptr) {
          fclose(testFile);
          return; // نجحت الكتابة
        }
        useTempPath = true;
      } else {
        useTempPath = true;
      }
    } else {
      useTempPath = true;
    }
    
    // إذا فشل فتح الملف في مجلد التطبيق، استخدم ملف مؤقت
    if (useTempPath) {
      wchar_t tempPath[MAX_PATH];
      if (GetTempPathW(MAX_PATH, tempPath) != 0) {
        std::wstring tempLogPath = std::wstring(tempPath) + L"etqan_player.log";
        SYSTEMTIME st;
        GetLocalTime(&st);
        std::wstring logMessage = L"[" + std::to_wstring(st.wYear) + L"-" + 
                                 std::to_wstring(st.wMonth) + L"-" + 
                                 std::to_wstring(st.wDay) + L" " +
                                 std::to_wstring(st.wHour) + L":" + 
                                 std::to_wstring(st.wMinute) + L":" + 
                                 std::to_wstring(st.wSecond) + L"] " + message;
        WriteToFile(tempLogPath, logMessage);
      }
    }
  } catch (...) {
    // Silently fail - we don't want logging errors to crash the app
  }
}

// دالة للتحقق من وجود ملفات DLL المطلوبة
bool CheckRequiredDLLs(const std::wstring& exeDir) {
  std::vector<std::wstring> requiredDLLs = {
    L"flutter_windows.dll",
    L"libmpv-2.dll",
    L"libEGL.dll",
    L"libGLESv2.dll"
  };
  
  for (const auto& dll : requiredDLLs) {
    std::wstring dllPath = exeDir + L"\\" + dll;
    if (GetFileAttributesW(dllPath.c_str()) == INVALID_FILE_ATTRIBUTES) {
      std::wstring errorMsg = L"ملف DLL مفقود: " + dll;
      WriteLog(errorMsg);
      MessageBoxW(nullptr, errorMsg.c_str(), L"خطأ - مشغل إتقان التعليمي", MB_OK | MB_ICONERROR);
      return false;
    }
  }
  WriteLog(L"[CheckRequiredDLLs] All required DLLs found");
  return true;
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Wrap everything in try-catch to catch any unhandled exceptions
  try {
    // محاولة كتابة log في بداية التطبيق - حتى قبل GetModuleFileNameW
    // استخدام مسار مؤقت للـ log للتأكد من أننا نستطيع الكتابة
    wchar_t tempPath[MAX_PATH];
    if (GetTempPathW(MAX_PATH, tempPath) != 0) {
      std::wstring tempLogPath = std::wstring(tempPath) + L"etqan_player_startup.log";
      SYSTEMTIME st;
      GetLocalTime(&st);
      std::wstring logMsg = L"[" + std::to_wstring(st.wYear) + L"-" + 
                           std::to_wstring(st.wMonth) + L"-" + 
                           std::to_wstring(st.wDay) + L" " +
                           std::to_wstring(st.wHour) + L":" + 
                           std::to_wstring(st.wMinute) + L":" + 
                           std::to_wstring(st.wSecond) + L"] [Startup] wWinMain called";
      WriteToFile(tempLogPath, logMsg);
      std::wstring pathMsg = L"[Startup] Temp log path: " + tempLogPath;
      WriteToFile(tempLogPath, pathMsg);
    }
    
    // محاولة كتابة في ملف startup log مباشرة قبل استدعاء WriteLog
    wchar_t tempPathStartup[MAX_PATH];
    if (GetTempPathW(MAX_PATH, tempPathStartup) != 0) {
      std::wstring tempLogPath = std::wstring(tempPathStartup) + L"etqan_player_startup.log";
      SYSTEMTIME st;
      GetLocalTime(&st);
      std::wstring logMsg = L"[" + std::to_wstring(st.wYear) + L"-" + 
                           std::to_wstring(st.wMonth) + L"-" + 
                           std::to_wstring(st.wDay) + L" " +
                           std::to_wstring(st.wHour) + L":" + 
                           std::to_wstring(st.wMinute) + L":" + 
                           std::to_wstring(st.wSecond) + L"] [Main] About to call WriteLog";
      WriteToFile(tempLogPath, logMsg);
    }
    
    WriteLog(L"[Main] Application starting");
  
  // تغيير مسار العمل إلى مجلد الملف التنفيذي
  wchar_t exePathBuffer[MAX_PATH * 4]; // دعم مسارات أطول
  std::wstring exeDir;
  DWORD pathResult = GetModuleFileNameW(nullptr, exePathBuffer, MAX_PATH * 4);
  
  if (pathResult == 0) {
    // فشل الحصول على المسار - خطأ حرج
    DWORD error = GetLastError();
    std::wstring errorMsg = L"فشل في الحصول على مسار الملف التنفيذي.\n";
    errorMsg += L"Error code: " + std::to_wstring(error) + L"\n\n";
    errorMsg += L"قد يكون هذا بسبب:\n";
    errorMsg += L"1. مشكلة في صلاحيات النظام\n";
    errorMsg += L"2. مشكلة في المسار (أحرف غير مدعومة)\n";
    errorMsg += L"3. مشكلة في ملف التثبيت\n\n";
    errorMsg += L"يرجى إعادة تثبيت التطبيق.";
    
    // محاولة كتابة في ملف log مؤقت
    wchar_t tempPath2[MAX_PATH];
    if (GetTempPathW(MAX_PATH, tempPath2) != 0) {
      std::wstring tempLogPath = std::wstring(tempPath2) + L"etqan_player_error.log";
      SYSTEMTIME st;
      GetLocalTime(&st);
      std::wstring logMsg = L"[" + std::to_wstring(st.wYear) + L"-" + 
                          std::to_wstring(st.wMonth) + L"-" + 
                          std::to_wstring(st.wDay) + L" " +
                          std::to_wstring(st.wHour) + L":" + 
                          std::to_wstring(st.wMinute) + L":" + 
                          std::to_wstring(st.wSecond) + L"] " + errorMsg;
      WriteToFile(tempLogPath, logMsg);
    }
    
    MessageBoxW(nullptr, errorMsg.c_str(), L"خطأ حرج - مشغل إتقان التعليمي", MB_OK | MB_ICONERROR);
    return EXIT_FAILURE;
  }
  
  // الحصول على المسار الكامل
  std::wstring exePath = std::wstring(exePathBuffer);
  WriteLog(L"[Main] Raw executable path from GetModuleFileNameW: " + exePath);
  
  // محاولة الحصول على المسار الكامل (Long Path)
  std::wstring longExePath = GetLongPath(exePath);
  if (longExePath != exePath) {
    WriteLog(L"[Main] Long path obtained: " + longExePath);
    exePath = longExePath;
  } else {
    WriteLog(L"[Main] Long path same as original, using original path");
  }
  
  // استخراج مجلد التطبيق
  size_t lastSlash = exePath.find_last_of(L"\\/");
  if (lastSlash != std::wstring::npos && lastSlash > 0) {
    exeDir = exePath.substr(0, lastSlash);
  } else {
    // حالة غير متوقعة - المسار لا يحتوي على مجلد
    std::wstring errorMsg = L"مسار الملف التنفيذي غير صحيح: " + exePath + L"\n\n";
    errorMsg += L"يرجى إعادة تثبيت التطبيق.";
    WriteLog(L"[Main] ERROR: Invalid executable path format: " + exePath);
    MessageBoxW(nullptr, errorMsg.c_str(), L"خطأ - مشغل إتقان التعليمي", MB_OK | MB_ICONERROR);
    return EXIT_FAILURE;
  }
  
  WriteLog(L"[Main] Executable path: " + exePath);
  WriteLog(L"[Main] Executable directory: " + exeDir);
  
  // التحقق من أن المجلد موجود
  DWORD dirAttrib = GetFileAttributesW(exeDir.c_str());
  if (dirAttrib == INVALID_FILE_ATTRIBUTES || !(dirAttrib & FILE_ATTRIBUTE_DIRECTORY)) {
    std::wstring errorMsg = L"مجلد التطبيق غير موجود أو غير قابل للوصول.\n";
    errorMsg += L"المسار: " + exeDir + L"\n\n";
    errorMsg += L"يرجى إعادة تثبيت التطبيق.";
    WriteLog(L"[Main] ERROR: Executable directory not found or inaccessible: " + exeDir);
    MessageBoxW(nullptr, errorMsg.c_str(), L"خطأ - مشغل منصة المبدع", MB_OK | MB_ICONERROR);
    return EXIT_FAILURE;
  }
  
  // تعيين مسار العمل
  if (!SetCurrentDirectoryW(exeDir.c_str())) {
    DWORD setDirError = GetLastError();
    std::wstring errorMsg = L"فشل في تعيين مسار العمل.\n";
    errorMsg += L"المسار: " + exeDir + L"\n";
    errorMsg += L"Error code: " + std::to_wstring(setDirError) + L"\n\n";
    errorMsg += L"قد يكون هذا بسبب:\n";
    errorMsg += L"1. مشكلة في صلاحيات النظام\n";
    errorMsg += L"2. المسار غير موجود\n";
    errorMsg += L"3. مشكلة في المسار (أحرف غير مدعومة)\n\n";
    errorMsg += L"يرجى إعادة تثبيت التطبيق.";
    WriteLog(L"[Main] ERROR: Failed to set working directory: " + exeDir + L", error: " + std::to_wstring(setDirError));
    MessageBoxW(nullptr, errorMsg.c_str(), L"خطأ - مشغل إتقان التعليمي", MB_OK | MB_ICONERROR);
    return EXIT_FAILURE;
  }
  
  WriteLog(L"[Main] Working directory set successfully to: " + exeDir);

  // التحقق من وجود ملفات DLL المطلوبة
  if (!CheckRequiredDLLs(exeDir)) {
    WriteLog(L"[Main] Required DLLs check failed");
    return EXIT_FAILURE;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Single Instance Check: Create a named mutex
  WriteLog(L"[Main] Creating mutex");
  HANDLE mutex = ::CreateMutexW(nullptr, TRUE, kSingleInstanceMutexName);
  if (mutex == nullptr) {
    // Failed to create mutex - exit
    WriteLog(L"[Main] Failed to create mutex");
    MessageBoxW(nullptr, L"فشل في إنشاء mutex.", L"خطأ - مشغل إتقان التعليمي", MB_OK | MB_ICONERROR);
    return EXIT_FAILURE;
  }
  WriteLog(L"[Main] Mutex created successfully");

  // Check if another instance is already running
  DWORD lastError = ::GetLastError();
  WriteLog(L"[Main] GetLastError after mutex creation: " + std::to_wstring(lastError));
  
  if (lastError == ERROR_ALREADY_EXISTS) {
    WriteLog(L"[Main] Another instance detected, attempting to activate existing window");
    
    // البحث عن النافذة مع timeout
    HWND existingWindow = nullptr;
    bool foundValidWindow = false;
    
    for (int i = 0; i < 5; i++) {
      existingWindow = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", nullptr);
      if (existingWindow == nullptr) {
        // Try finding by title as fallback
        existingWindow = ::FindWindowW(nullptr, L"مشغل إتقان التعليمي");
      }
      
      if (existingWindow != nullptr) {
        // التحقق من أن النافذة تنتمي إلى process حي
        DWORD processId;
        ::GetWindowThreadProcessId(existingWindow, &processId);
        HANDLE processHandle = ::OpenProcess(PROCESS_QUERY_INFORMATION, FALSE, processId);
        if (processHandle != nullptr) {
          DWORD exitCode;
          if (::GetExitCodeProcess(processHandle, &exitCode) && exitCode == STILL_ACTIVE) {
            // النافذة موجودة وتنتمي إلى process حي
            WriteLog(L"[Main] Found valid existing window, process ID: " + std::to_wstring(processId));
            ::CloseHandle(processHandle);
            foundValidWindow = true;
            break;
          }
          ::CloseHandle(processHandle);
        }
        existingWindow = nullptr; // Reset if process is not active
      }
      
      if (i < 4) {
        ::Sleep(100); // انتظر 100ms قبل المحاولة التالية
        WriteLog(L"[Main] Waiting for window, attempt " + std::to_wstring(i + 2) + L" of 5");
      }
    }
    
    if (foundValidWindow && existingWindow != nullptr) {
      // تفعيل النافذة الموجودة
      WriteLog(L"[Main] Activating existing window");
      DWORD processId;
      ::GetWindowThreadProcessId(existingWindow, &processId);
      ::AllowSetForegroundWindow(processId);
      
      ::ShowWindow(existingWindow, SW_RESTORE);
      ::SetForegroundWindow(existingWindow);
      ::SetActiveWindow(existingWindow);
      ::BringWindowToTop(existingWindow);
      
      // إرسال الـ command line للـ instance الموجود عبر WM_COPYDATA
      std::wstring cmdLine = ::GetCommandLineW();
      COPYDATASTRUCT cds;
      cds.dwData = 1; // معرف مخصص
      cds.cbData = (DWORD)((cmdLine.length() + 1) * sizeof(wchar_t));
      cds.lpData = (void*)cmdLine.c_str();
      
      WriteLog(L"[Main] Sending WM_COPYDATA with command line: " + cmdLine);
      ::SendMessageW(existingWindow, WM_COPYDATA, (WPARAM)nullptr, (LPARAM)&cds);
      
      // Flash window to get user attention
      FLASHWINFO flashInfo;
      flashInfo.cbSize = sizeof(FLASHWINFO);
      flashInfo.hwnd = existingWindow;
      flashInfo.dwFlags = FLASHW_ALL | FLASHW_TIMERNOFG;
      flashInfo.uCount = 2;
      flashInfo.dwTimeout = 0;
      ::FlashWindowEx(&flashInfo);
      
      WriteLog(L"[Main] Releasing mutex and exiting (instance already running)");
      ::ReleaseMutex(mutex);
      ::CloseHandle(mutex);
      return EXIT_SUCCESS;
    } else {
      // لم نجد نافذة - Mutex معلق من instance سابق
      WriteLog(L"[Main] No valid window found - mutex is likely orphaned, continuing anyway");
      // إغلاق Mutex الحالي وإنشاء واحد جديد
      ::ReleaseMutex(mutex);
      ::CloseHandle(mutex);
      
      // إنشاء Mutex جديد
      mutex = ::CreateMutexW(nullptr, TRUE, kSingleInstanceMutexName);
      if (mutex == nullptr) {
        WriteLog(L"[Main] Failed to create new mutex after cleanup");
        MessageBoxW(nullptr, L"فشل في إنشاء mutex بعد التنظيف.", L"خطأ - مشغل إتقان التعليمي", MB_OK | MB_ICONERROR);
        return EXIT_FAILURE;
      }
      WriteLog(L"[Main] New mutex created after cleanup, continuing");
    }
  }

  WriteLog(L"[Main] No existing instance found, continuing with initialization");

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  WriteLog(L"[Main] Initializing COM");
  HRESULT hr = ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  if (FAILED(hr)) {
    WriteLog(L"[Main] COM initialization failed");
    std::wstring errorMsg = L"فشل في تهيئة COM. Error code: " + std::to_wstring(hr);
    MessageBoxW(nullptr, errorMsg.c_str(), L"خطأ - مشغل إتقان التعليمي", MB_OK | MB_ICONERROR);
    ::ReleaseMutex(mutex);
    ::CloseHandle(mutex);
    return EXIT_FAILURE;
  }
  WriteLog(L"[Main] COM initialized successfully");

  // التحقق من وجود مجلد data (استخدام exeDir من الأعلى)
  std::wstring dataPath = exeDir + L"\\data";
  WriteLog(L"[Main] Checking data directory: " + dataPath);

  // التحقق من وجود المجلد
  DWORD dwAttrib = GetFileAttributesW(dataPath.c_str());
  if (dwAttrib == INVALID_FILE_ATTRIBUTES || !(dwAttrib & FILE_ATTRIBUTE_DIRECTORY)) {
    // إظهار رسالة خطأ
    std::wstring errorMsg = L"لا يمكن العثور على مجلد البيانات.\nالمسار المتوقع: " + dataPath + L"\nيرجى إعادة تثبيت التطبيق.";
    WriteLog(L"[Main] Data directory not found: " + dataPath);
    MessageBoxW(nullptr, 
        errorMsg.c_str(), 
        L"خطأ - مشغل إتقان التعليمي", 
        MB_OK | MB_ICONERROR);
    ::ReleaseMutex(mutex);
    ::CloseHandle(mutex);
    ::CoUninitialize();
    return EXIT_FAILURE;
  }
  WriteLog(L"[Main] Data directory found");

  WriteLog(L"[Main] Creating DartProject");
  
  // التحقق من وجود ملفات مهمة في مجلد data قبل إنشاء DartProject
  std::wstring dataFlutterAssets = dataPath + L"\\flutter_assets";
  std::wstring dataAppSo = dataPath + L"\\app.so";
  std::wstring dataIcu = dataPath + L"\\icudtl.dat";
  
  WriteLog(L"[Main] Checking critical data files...");
  WriteLog(L"[Main] Checking: " + dataFlutterAssets);
  WriteLog(L"[Main] Checking: " + dataAppSo);
  WriteLog(L"[Main] Checking: " + dataIcu);
  
  DWORD flutterAssetsAttrib = GetFileAttributesW(dataFlutterAssets.c_str());
  DWORD appSoAttrib = GetFileAttributesW(dataAppSo.c_str());
  DWORD icuAttrib = GetFileAttributesW(dataIcu.c_str());
  
  // التحقق من وجود جميع الملفات المطلوبة قبل إنشاء DartProject
  bool allFilesPresent = true;
  std::wstring missingFiles;
  
  if (flutterAssetsAttrib == INVALID_FILE_ATTRIBUTES || !(flutterAssetsAttrib & FILE_ATTRIBUTE_DIRECTORY)) {
    WriteLog(L"[Main] ERROR: flutter_assets directory not found!");
    allFilesPresent = false;
    missingFiles += L"flutter_assets\\\n";
  } else {
    WriteLog(L"[Main] flutter_assets directory found");
  }
  
  if (appSoAttrib == INVALID_FILE_ATTRIBUTES) {
    WriteLog(L"[Main] ERROR: app.so file not found!");
    allFilesPresent = false;
    missingFiles += L"app.so\n";
  } else {
    WriteLog(L"[Main] app.so file found");
  }
  
  if (icuAttrib == INVALID_FILE_ATTRIBUTES) {
    WriteLog(L"[Main] ERROR: icudtl.dat file not found!");
    allFilesPresent = false;
    missingFiles += L"icudtl.dat\n";
  } else {
    WriteLog(L"[Main] icudtl.dat file found");
  }
  
  if (!allFilesPresent) {
    std::wstring errorMsg = L"ملفات البيانات المطلوبة مفقودة:\n\n" + missingFiles + L"\n";
    errorMsg += L"المسار المتوقع: " + dataPath + L"\n\n";
    errorMsg += L"يرجى إعادة تثبيت التطبيق.";
    WriteLog(L"[Main] CRITICAL: Required data files missing, cannot create DartProject");
    MessageBoxW(nullptr, errorMsg.c_str(), L"خطأ حرج - مشغل إتقان التعليمي", MB_OK | MB_ICONERROR);
    ::ReleaseMutex(mutex);
    ::CloseHandle(mutex);
    ::CoUninitialize();
    return EXIT_FAILURE;
  }
  
  WriteLog(L"[Main] All required data files verified, creating DartProject");
  
  // إنشاء DartProject - يستخدم مسار نسبي "data" لأننا قمنا بتعيين working directory
  // DartProject سيبحث عن "data" في المسار الحالي (working directory)
  flutter::DartProject project(L"data");
  WriteLog(L"[Main] DartProject created successfully with path: data (relative to working directory: " + exeDir + L")");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();
  WriteLog(L"[Main] Command line arguments parsed: " + std::to_wstring(command_line_arguments.size()));

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));
  WriteLog(L"[Main] Dart entrypoint arguments set");

  WriteLog(L"[Main] Creating FlutterWindow object");
  FlutterWindow window(project);
  WriteLog(L"[Main] FlutterWindow object created");
  
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  WriteLog(L"[Main] Window parameters set: origin(10,10), size(1280,720)");
  
  WriteLog(L"[Main] Attempting to create window");
  WriteLog(L"[Main] About to call window.Create()");
  
  // محاولة إنشاء النافذة مع معالجة أخطاء أفضل
  bool windowCreated = false;
  try {
    windowCreated = window.Create(L"مشغل إتقان التعليمي", origin, size);
    WriteLog(L"[Main] window.Create() returned: " + std::wstring(windowCreated ? L"true" : L"false"));
  } catch (...) {
    WriteLog(L"[Main] Exception thrown in window.Create()");
    windowCreated = false;
  }
  
  if (!windowCreated) {
    WriteLog(L"[Main] Window creation failed");
    DWORD windowError = GetLastError();
    std::wstring errorMsg = L"فشل في إنشاء نافذة التطبيق.\n";
    errorMsg += L"Error code: " + std::to_wstring(windowError) + L"\n\n";
    errorMsg += L"يرجى التحقق من:\n";
    errorMsg += L"1. وجود جميع ملفات DLL\n";
    errorMsg += L"2. صلاحيات النظام\n";
    errorMsg += L"3. إعادة تثبيت التطبيق\n\n";
    errorMsg += L"راجع ملف etqan_player.log لمزيد من التفاصيل.";
    
    // إظهار MessageBox مع تفاصيل أكثر
    MessageBoxW(nullptr, 
        errorMsg.c_str(), 
        L"خطأ - مشغل إتقان التعليمي", 
        MB_OK | MB_ICONERROR);
    
    // كتابة في ملف log مؤقت أيضاً
    wchar_t tempPath4[MAX_PATH];
    if (GetTempPathW(MAX_PATH, tempPath4) != 0) {
      std::wstring tempLogPath = std::wstring(tempPath4) + L"etqan_player_error.log";
      SYSTEMTIME st;
      GetLocalTime(&st);
      std::wstring logMsg = L"[" + std::to_wstring(st.wYear) + L"-" + 
                           std::to_wstring(st.wMonth) + L"-" + 
                           std::to_wstring(st.wDay) + L" " +
                           std::to_wstring(st.wHour) + L":" + 
                           std::to_wstring(st.wMinute) + L":" + 
                           std::to_wstring(st.wSecond) + L"] Window creation failed. Error: " + 
                           std::to_wstring(windowError);
      WriteToFile(tempLogPath, logMsg);
    }
    
    ::ReleaseMutex(mutex);
    ::CloseHandle(mutex);
    ::CoUninitialize();
    return EXIT_FAILURE;
  }
  WriteLog(L"[Main] Window created successfully");
  window.SetQuitOnClose(true);
  WriteLog(L"[Main] Entering message loop");

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  // Release mutex before exit
  WriteLog(L"[Main] Application exiting");
  ::ReleaseMutex(mutex);
  ::CloseHandle(mutex);

  ::CoUninitialize();
  WriteLog(L"[Main] Application exited successfully");
  return EXIT_SUCCESS;
  } catch (const std::exception& e) {
    // Log exception
    std::wstring errorMsg = L"[Main] Unhandled exception: ";
    int size_needed = MultiByteToWideChar(CP_UTF8, 0, e.what(), -1, NULL, 0);
    if (size_needed > 0) {
      std::vector<wchar_t> buffer(size_needed);
      MultiByteToWideChar(CP_UTF8, 0, e.what(), -1, &buffer[0], size_needed);
      errorMsg += std::wstring(&buffer[0]);
    }
    WriteLog(errorMsg);
    MessageBoxW(nullptr, errorMsg.c_str(), L"خطأ - مشغل إتقان التعليمي", MB_OK | MB_ICONERROR);
    return EXIT_FAILURE;
  } catch (...) {
    WriteLog(L"[Main] Unknown unhandled exception");
    MessageBoxW(nullptr, L"حدث خطأ غير معروف في التطبيق.", L"خطأ - مشغل إتقان التعليمي", MB_OK | MB_ICONERROR);
    return EXIT_FAILURE;
  }
}
