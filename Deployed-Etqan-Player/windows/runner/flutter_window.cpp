#include "flutter_window.h"

#include <optional>
#include <exception>
#include <vector>
#include <windows.h>
#include <fstream>
#include <sstream>

#include "flutter/generated_plugin_registrant.h"
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

// Forward declaration for logging
extern void WriteLog(const std::wstring& message);

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  WriteLog(L"[FlutterWindow] OnCreate started");
  
  if (!Win32Window::OnCreate()) {
    WriteLog(L"[FlutterWindow] Win32Window::OnCreate failed");
    return false;
  }
  WriteLog(L"[FlutterWindow] Win32Window::OnCreate succeeded");

  RECT frame = GetClientArea();
  
  // Log frame size for debugging
  int frameWidth = frame.right - frame.left;
  int frameHeight = frame.bottom - frame.top;
  WriteLog(L"[FlutterWindow] Got client area: " + std::to_wstring(frameWidth) + 
           L"x" + std::to_wstring(frameHeight));
  
  // Fix: If client area is zero (timing issue), use default size
  if (frameWidth == 0 || frameHeight == 0) {
    WriteLog(L"[FlutterWindow] Client area is zero, using default size 1280x720");
    frameWidth = 1280;
    frameHeight = 720;
  }

  try {
    WriteLog(L"[FlutterWindow] Creating FlutterViewController with size: " + 
             std::to_wstring(frameWidth) + L"x" + std::to_wstring(frameHeight));
    
    // التحقق من أن project صالح قبل إنشاء FlutterViewController
    WriteLog(L"[FlutterWindow] Verifying DartProject before creating FlutterViewController");
    
    // التحقق من وجود ملفات البيانات المطلوبة
    wchar_t exePathBuffer[MAX_PATH * 4];
    if (GetModuleFileNameW(nullptr, exePathBuffer, MAX_PATH * 4) != 0) {
      std::wstring exePath = std::wstring(exePathBuffer);
      size_t lastSlash = exePath.find_last_of(L"\\/");
      if (lastSlash != std::wstring::npos) {
        std::wstring exeDir = exePath.substr(0, lastSlash);
        std::wstring dataPath = exeDir + L"\\data";
        std::wstring appSoPath = dataPath + L"\\app.so";
        std::wstring icuPath = dataPath + L"\\icudtl.dat";
        std::wstring flutterAssetsPath = dataPath + L"\\flutter_assets";
        
        // التحقق من وجود الملفات المطلوبة
        if (GetFileAttributesW(appSoPath.c_str()) == INVALID_FILE_ATTRIBUTES) {
          WriteLog(L"[FlutterWindow] ERROR: app.so file not found at: " + appSoPath);
          MessageBoxW(nullptr, 
              (L"ملف app.so غير موجود.\nالمسار المتوقع: " + appSoPath + L"\nيرجى إعادة تثبيت التطبيق.").c_str(),
              L"خطأ - مشغل إتقان التعليمي", MB_OK | MB_ICONERROR);
          return false;
        }
        
        if (GetFileAttributesW(icuPath.c_str()) == INVALID_FILE_ATTRIBUTES) {
          WriteLog(L"[FlutterWindow] ERROR: icudtl.dat file not found at: " + icuPath);
          MessageBoxW(nullptr, 
              (L"ملف icudtl.dat غير موجود.\nالمسار المتوقع: " + icuPath + L"\nيرجى إعادة تثبيت التطبيق.").c_str(),
              L"خطأ - مشغل إتقان التعليمي", MB_OK | MB_ICONERROR);
          return false;
        }
        
        DWORD flutterAssetsAttrib = GetFileAttributesW(flutterAssetsPath.c_str());
        if (flutterAssetsAttrib == INVALID_FILE_ATTRIBUTES || !(flutterAssetsAttrib & FILE_ATTRIBUTE_DIRECTORY)) {
          WriteLog(L"[FlutterWindow] ERROR: flutter_assets directory not found at: " + flutterAssetsPath);
          MessageBoxW(nullptr, 
              (L"مجلد flutter_assets غير موجود.\nالمسار المتوقع: " + flutterAssetsPath + L"\nيرجى إعادة تثبيت التطبيق.").c_str(),
              L"خطأ - مشغل إتقان التعليمي", MB_OK | MB_ICONERROR);
          return false;
        }
        
        WriteLog(L"[FlutterWindow] All required data files verified");
      }
    }
    
    // محاولة إنشاء FlutterViewController مع معالجة أخطاء أفضل
    WriteLog(L"[FlutterWindow] About to create FlutterViewController...");
    
    // استخدام try-catch للتعامل مع الأخطاء
    std::unique_ptr<flutter::FlutterViewController> tempController;
    bool controllerCreated = false;
    
    try {
      WriteLog(L"[FlutterWindow] Calling FlutterViewController constructor...");
      tempController = std::make_unique<flutter::FlutterViewController>(
          frameWidth, frameHeight, project_);
      WriteLog(L"[FlutterWindow] FlutterViewController constructor completed");
      
      // التحقق من أن الـ controller تم إنشاؤه بنجاح
      if (!tempController) {
        WriteLog(L"[FlutterWindow] FlutterViewController is null after creation");
        return false;
      }
      
      flutter_controller_ = std::move(tempController);
      controllerCreated = true;
      WriteLog(L"[FlutterWindow] FlutterViewController created successfully");
    } catch (const std::bad_alloc&) {
      WriteLog(L"[FlutterWindow] Memory allocation failed in FlutterViewController creation");
      MessageBoxW(nullptr, 
          L"فشل في تخصيص الذاكرة لإنشاء FlutterViewController.\nيرجى إعادة تشغيل التطبيق.",
          L"خطأ - مشغل إتقان التعليمي", MB_OK | MB_ICONERROR);
      return false;
    } catch (const std::exception& e) {
      std::wstring errorMsg = L"[FlutterWindow] Exception in FlutterViewController creation: ";
      int size_needed = MultiByteToWideChar(CP_UTF8, 0, e.what(), -1, NULL, 0);
      if (size_needed > 0) {
        std::vector<wchar_t> buffer(size_needed);
        MultiByteToWideChar(CP_UTF8, 0, e.what(), -1, &buffer[0], size_needed);
        errorMsg += std::wstring(&buffer[0]);
      }
      WriteLog(errorMsg);
      MessageBoxW(nullptr, 
          (L"حدث خطأ أثناء إنشاء FlutterViewController:\n" + errorMsg).c_str(),
          L"خطأ - مشغل إتقان التعليمي", MB_OK | MB_ICONERROR);
      return false;
    } catch (...) {
      WriteLog(L"[FlutterWindow] Unknown exception in FlutterViewController creation");
      MessageBoxW(nullptr, 
          L"حدث خطأ غير معروف أثناء إنشاء FlutterViewController.\n"
          L"قد يكون هذا بسبب:\n"
          L"1. ملفات DLL مفقودة أو تالفة\n"
          L"2. ملفات البيانات مفقودة أو تالفة\n"
          L"3. مشكلة في صلاحيات النظام\n\n"
          L"يرجى إعادة تثبيت التطبيق.",
          L"خطأ - مشغل إتقان التعليمي", MB_OK | MB_ICONERROR);
      return false;
    }
    
    if (!controllerCreated) {
      WriteLog(L"[FlutterWindow] FlutterViewController creation failed");
      return false;
    }
    
    // التحقق من engine مع معالجة أخطاء أفضل
    WriteLog(L"[FlutterWindow] Checking Flutter engine...");
    try {
      if (!flutter_controller_->engine()) {
        WriteLog(L"[FlutterWindow] Flutter engine is null");
        return false;
      }
      WriteLog(L"[FlutterWindow] Flutter engine is valid");
    } catch (...) {
      WriteLog(L"[FlutterWindow] Exception while checking Flutter engine");
      return false;
    }
    
    // التحقق من view مع معالجة أخطاء أفضل
    WriteLog(L"[FlutterWindow] Checking Flutter view...");
    try {
      if (!flutter_controller_->view()) {
        WriteLog(L"[FlutterWindow] Flutter view is null");
        return false;
      }
      WriteLog(L"[FlutterWindow] Flutter view is valid");
    } catch (...) {
      WriteLog(L"[FlutterWindow] Exception while checking Flutter view");
      return false;
    }
    
    WriteLog(L"[FlutterWindow] Registering plugins");
    RegisterPlugins(flutter_controller_->engine());
    WriteLog(L"[FlutterWindow] Plugins registered");
    
    WriteLog(L"[FlutterWindow] Setting child content");
    SetChildContent(flutter_controller_->view()->GetNativeWindow());
    WriteLog(L"[FlutterWindow] Child content set");

    WriteLog(L"[FlutterWindow] Setting next frame callback");
    flutter_controller_->engine()->SetNextFrameCallback([&]() {
      this->Show();
    });
    WriteLog(L"[FlutterWindow] Next frame callback set");

    WriteLog(L"[FlutterWindow] Calling ForceRedraw");
    flutter_controller_->ForceRedraw();
    WriteLog(L"[FlutterWindow] ForceRedraw called");
    
    WriteLog(L"[FlutterWindow] OnCreate completed successfully");
    return true;
  } catch (const std::exception& e) {
    std::wstring errorMsg = L"[FlutterWindow] Exception: ";
    // Convert e.what() to wstring
    int size_needed = MultiByteToWideChar(CP_UTF8, 0, e.what(), -1, NULL, 0);
    if (size_needed > 0) {
      std::vector<wchar_t> buffer(size_needed);
      MultiByteToWideChar(CP_UTF8, 0, e.what(), -1, &buffer[0], size_needed);
      errorMsg += std::wstring(&buffer[0]);
    }
    WriteLog(errorMsg);
    return false;
  } catch (...) {
    WriteLog(L"[FlutterWindow] Unknown exception");
    return false;
  }
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    case WM_COPYDATA:
      if (lparam) {
        COPYDATASTRUCT* cds = (COPYDATASTRUCT*)lparam;
        if (cds->dwData == 1 && cds->cbData > 0) {
          std::wstring cmdLine((wchar_t*)cds->lpData);
          WriteLog(L"[FlutterWindow] Received WM_COPYDATA with command line: " + cmdLine);
          
          // تحويل wstring إلى UTF-8 لإرساله لـ Flutter
          std::string cmdLineUtf8 = "";
          int size_needed = WideCharToMultiByte(CP_UTF8, 0, cmdLine.c_str(), (int)cmdLine.length(), NULL, 0, NULL, NULL);
          if (size_needed > 0) {
            cmdLineUtf8.resize(size_needed);
            WideCharToMultiByte(CP_UTF8, 0, cmdLine.c_str(), (int)cmdLine.length(), &cmdLineUtf8[0], size_needed, NULL, NULL);
          }
          
          if (!cmdLineUtf8.empty()) {
            // إرسال الرابط لـ Flutter عبر MethodChannel
            auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
                flutter_controller_->engine()->messenger(),
                "com.etqan.player/deep_link",
                &flutter::StandardMethodCodec::GetInstance());
                
            channel->InvokeMethod("onDeepLink", std::make_unique<flutter::EncodableValue>(cmdLineUtf8));
            WriteLog(L"[FlutterWindow] Sent onDeepLink to Flutter");
          }
          return TRUE;
        }
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
