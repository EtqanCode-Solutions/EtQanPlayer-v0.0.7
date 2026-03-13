import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var screenRecordingChannel: FlutterMethodChannel?
  private var securityChannel: FlutterMethodChannel?
  private var screenRecordingObserver: NSObjectProtocol?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    GeneratedPluginRegistrant.register(with: self)
    
    // إعداد MethodChannel للكشف عن Screen Recording/Mirroring
    // نستخدم DispatchQueue.main.async لضمان أن window جاهز
    DispatchQueue.main.async { [weak self] in
      self?.setupScreenRecordingDetection()
      self?.setupSecurityDetection()
    }
    
    return result
  }
  
  private func setupScreenRecordingDetection() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      // إعادة المحاولة بعد قليل إذا لم يكن window جاهزاً
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
        self?.setupScreenRecordingDetection()
      }
      return
    }
    
    // إنشاء MethodChannel
    screenRecordingChannel = FlutterMethodChannel(
      name: "com.etqan.player/screen_recording",
      binaryMessenger: controller.binaryMessenger
    )
    
    // إعداد Method Handler
    screenRecordingChannel?.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "isScreenRecording":
        result(UIScreen.main.isCaptured)
      case "startMonitoring":
        self?.startMonitoringScreenRecording()
        result(true)
      case "stopMonitoring":
        self?.stopMonitoringScreenRecording()
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    
    // بدء المراقبة تلقائياً
    startMonitoringScreenRecording()
  }
  
  private func setupSecurityDetection() {
    guard let controller = window?.rootViewController as? FlutterViewController else { return }
    
    securityChannel = FlutterMethodChannel(
      name: "com.etqan.player/security",
      binaryMessenger: controller.binaryMessenger
    )
    
    securityChannel?.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "isDebuggerAttached":
        result(self.isDebuggerAttached())
      case "isDeveloperModeEnabled":
        // iOS doesn't have a public "Developer Mode" toggle like Android for apps to check
        // Developer features require physical connection or specific profiles
        result(false)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
  
  private func isDebuggerAttached() -> Bool {
    var info = kinfo_proc()
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
    var size = MemoryLayout<kinfo_proc>.size
    let junk = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
    assert(junk == 0, "sysctl failed")
    return (info.kp_proc.p_flag & P_TRACED) != 0
  }
  
  private func startMonitoringScreenRecording() {
    // إزالة المراقب السابق إن وجد
    stopMonitoringScreenRecording()
    
    // إرسال الحالة الأولية
    checkAndNotifyScreenRecording()
    
    // إضافة Notification Observer للكشف عن تغييرات Screen Recording/Mirroring
    screenRecordingObserver = NotificationCenter.default.addObserver(
      forName: UIScreen.capturedDidChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.checkAndNotifyScreenRecording()
    }
  }
  
  private func stopMonitoringScreenRecording() {
    if let observer = screenRecordingObserver {
      NotificationCenter.default.removeObserver(observer)
      screenRecordingObserver = nil
    }
  }
  
  private func checkAndNotifyScreenRecording() {
    let isCaptured = UIScreen.main.isCaptured
    
    // إرسال الحالة إلى Flutter
    screenRecordingChannel?.invokeMethod("onScreenRecordingChanged", arguments: isCaptured)
    
    if isCaptured {
      print("⚠️ Screen Recording/Mirroring detected!")
    } else {
      print("✅ Screen Recording/Mirroring stopped")
    }
  }
  
  deinit {
    stopMonitoringScreenRecording()
  }
}
