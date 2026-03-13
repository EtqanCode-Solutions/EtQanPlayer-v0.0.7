import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:no_screenshot/no_screenshot.dart';
import 'screen_recording_detection_service.dart';

/// خدمة شاملة لحماية التطبيق من لقطات الشاشة والتسجيل و Screen Recording/Mirroring
class ScreenshotProtectionService {
  static final ScreenshotProtectionService _instance =
      ScreenshotProtectionService._internal();

  factory ScreenshotProtectionService() => _instance;
  ScreenshotProtectionService._internal();

  final NoScreenshot _noScreenshot = NoScreenshot.instance;
  final ScreenRecordingDetectionService _screenRecordingService =
      ScreenRecordingDetectionService();

  StreamSubscription? _screenshotSubscription;
  StreamSubscription<bool>? _screenRecordingSubscription;
  bool _isProtectionEnabled = false;
  
  // Callback عند اكتشاف Screen Recording/Mirroring
  Function(bool)? onScreenRecordingDetected;

  /// تفعيل الحماية من لقطات الشاشة و Screen Recording/Mirroring
  Future<bool> enableProtection() async {
    if (_isProtectionEnabled) return true;

    try {
      // التحقق من المنصة
      if (Platform.isAndroid || Platform.isIOS) {
        // استخدام no_screenshot (الأكثر تطوراً) لحماية Screenshots
        bool result1 = await _noScreenshot.screenshotOff();

        // الاستماع لأحداث التصوير
        _screenshotSubscription = _noScreenshot.screenshotStream.listen((
          event,
        ) {
          debugPrint('⚠️ Screenshot attempt detected: $event');
          _onScreenshotDetected();
        });

        // تفعيل مراقبة Screen Recording/Mirroring على iOS
        if (Platform.isIOS) {
          await _screenRecordingService.startMonitoring();
          
          // الاستماع لتغييرات Screen Recording/Mirroring
          _screenRecordingSubscription = _screenRecordingService.recordingStateStream.listen(
            (isRecording) {
              if (isRecording) {
                debugPrint('🚨 Screen Recording/Mirroring detected!');
                onScreenRecordingDetected?.call(true);
              } else {
                debugPrint('✅ Screen Recording/Mirroring stopped');
                onScreenRecordingDetected?.call(false);
              }
            },
          );
        }

        _isProtectionEnabled = result1;
        debugPrint('✅ Screenshot protection enabled: $_isProtectionEnabled');
        if (Platform.isIOS) {
          debugPrint('✅ Screen Recording/Mirroring monitoring enabled');
        }
        return _isProtectionEnabled;
      } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        // على Desktop، الحماية تتم من خلال native code
        // Windows: SetWindowDisplayAffinity (تم تنفيذه في win32_window.cpp)
        // macOS: يتم من خلال secure_application
        _isProtectionEnabled = true;
        debugPrint('✅ Desktop screenshot protection enabled (native)');
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error enabling screenshot protection: $e');
      return false;
    }

    return false;
  }

  /// تعطيل الحماية من لقطات الشاشة و Screen Recording/Mirroring
  Future<bool> disableProtection() async {
    if (!_isProtectionEnabled) return true;

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await _noScreenshot.screenshotOn();
        await _screenshotSubscription?.cancel();
        _screenshotSubscription = null;
        
        // إيقاف مراقبة Screen Recording/Mirroring على iOS
        if (Platform.isIOS) {
          await _screenRecordingService.stopMonitoring();
          await _screenRecordingSubscription?.cancel();
          _screenRecordingSubscription = null;
        }
      }

      _isProtectionEnabled = false;
      debugPrint('✅ Screenshot protection disabled');
      if (Platform.isIOS) {
        debugPrint('✅ Screen Recording/Mirroring monitoring disabled');
      }
      return true;
    } catch (e) {
      debugPrint('❌ Error disabling screenshot protection: $e');
      return false;
    }
  }

  /// تبديل حالة الحماية
  Future<bool> toggleProtection() async {
    if (_isProtectionEnabled) {
      return await disableProtection();
    } else {
      return await enableProtection();
    }
  }

  /// التحقق من حالة الحماية
  bool get isProtectionEnabled => _isProtectionEnabled;
  
  /// التحقق من حالة Screen Recording/Mirroring (iOS فقط)
  bool get isScreenRecording => _screenRecordingService.isRecording;
  
  /// Stream لتغييرات Screen Recording/Mirroring (iOS فقط)
  Stream<bool> get screenRecordingStream => _screenRecordingService.recordingStateStream;

  /// معالج عند اكتشاف محاولة تصوير
  void _onScreenshotDetected() {
    // يمكن إضافة منطق إضافي هنا مثل:
    // - إظهار تنبيه للمستخدم
    // - تسجيل الحدث
    // - إغلاق التطبيق
    debugPrint('🚨 Screenshot attempt blocked!');
  }

  /// تنظيف الموارد
  void dispose() {
    _screenshotSubscription?.cancel();
    _screenshotSubscription = null;
    _screenRecordingSubscription?.cancel();
    _screenRecordingSubscription = null;
    _screenRecordingService.dispose();
    disableProtection();
  }
}
