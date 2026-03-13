import 'dart:async';
import 'package:flutter/material.dart';
import 'package:secure_application/secure_application.dart';
import '../services/screenshot_protection_service.dart';
import '../services/process_monitor_service.dart';
import '../services/progress_service.dart';
import '../services/audio_control_service.dart';

/// Widget wrapper يوفر حماية شاملة للتطبيق
class SecureAppWrapper extends StatefulWidget {
  final Widget child;
  final bool enableScreenshotProtection;
  final bool enableProcessMonitoring;
  final bool enableSecureApplication;
  final Function(bool)? onProtectionStatusChanged;

  const SecureAppWrapper({
    super.key,
    required this.child,
    this.enableScreenshotProtection = true,
    this.enableProcessMonitoring = true,
    this.enableSecureApplication = true,
    this.onProtectionStatusChanged,
  });

  @override
  State<SecureAppWrapper> createState() => _SecureAppWrapperState();
}

class _SecureAppWrapperState extends State<SecureAppWrapper>
    with WidgetsBindingObserver {
  final ScreenshotProtectionService _screenshotService =
      ScreenshotProtectionService();
  final ProcessMonitorService _processMonitor = ProcessMonitorService();
  bool _hasActiveCaptureApps = false;
  bool _isScreenRecording = false;
  StreamSubscription<bool>? _screenRecordingSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeProtection();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _screenRecordingSubscription?.cancel();
    _screenshotService.dispose();
    _processMonitor.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        // إعادة تفعيل الحماية عند العودة للتطبيق
        if (widget.enableScreenshotProtection) {
          _screenshotService.enableProtection();
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // يمكن تعطيل الحماية مؤقتاً إذا لزم الأمر
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _initializeProtection() async {
    // تفعيل حماية لقطات الشاشة و Screen Recording/Mirroring
    if (widget.enableScreenshotProtection) {
      // إعداد callback للكشف عن Screen Recording/Mirroring
      _screenshotService.onScreenRecordingDetected = (isRecording) {
        if (mounted) {
          setState(() {
            _isScreenRecording = isRecording;
          });

          if (isRecording) {
            debugPrint('🚨 Screen Recording/Mirroring detected!');
            debugPrint('🛡️ Showing security overlay');
            // حفظ التقدم الحالي عند اكتشاف تسجيل الشاشة
            ProgressService.instance.saveCurrentProgress();
            // كتم الصوت تلقائياً
            AudioControlService().mute();
          } else {
            debugPrint('✅ Screen Recording/Mirroring stopped');
            debugPrint('🟢 Removing security overlay');
            // إلغاء كتم الصوت
            AudioControlService().unmute();
          }
        }
      };

      bool enabled = await _screenshotService.enableProtection();
      widget.onProtectionStatusChanged?.call(enabled);

      // الاستماع لتغييرات Screen Recording/Mirroring
      _screenRecordingSubscription = _screenshotService.screenRecordingStream.listen(
        (isRecording) {
          if (mounted) {
            setState(() {
              _isScreenRecording = isRecording;
            });
          }
        },
      );

      // التحقق من الحالة الأولية
      _isScreenRecording = _screenshotService.isScreenRecording;
    }

    // تفعيل مراقبة برامج التصوير
    if (widget.enableProcessMonitoring) {
      _processMonitor.onAppsDetected = (hasApps, apps) {
        if (mounted) {
          setState(() {
            _hasActiveCaptureApps = hasApps;
          });

          if (hasApps) {
            debugPrint('🚨 Screen capture apps detected: ${apps.join(", ")}');
            debugPrint('🛡️ Showing security overlay');
            // حفظ التقدم الحالي عند اكتشاف برامج تصوير
            ProgressService.instance.saveCurrentProgress();
            // كتم الصوت تلقائياً
            AudioControlService().mute();
          } else {
            debugPrint('✅ All screen capture apps closed');
            debugPrint('🟢 Removing security overlay');
            // إلغاء كتم الصوت
            AudioControlService().unmute();
          }
        }
      };

      _processMonitor.startMonitoring();

      // تحديث الحالة الأولية
      _hasActiveCaptureApps = _processMonitor.hasActiveCaptureApps;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget app = widget.child;

    // تطبيق secure_application إذا كان مفعلاً
    if (widget.enableSecureApplication) {
      app = SecureApplication(
        nativeRemoveDelay: 800,
        autoUnlockNative: true, // فتح تلقائي
        onNeedUnlock: (secureApplicationController) async {
          // يمكن إضافة مصادقة بيومترية هنا
          secureApplicationController?.authSuccess(unlock: true);
          return null;
        },
        child: Builder(
          builder: (context) {
            // إخفاء مؤشر الحماية الافتراضي
            return SecureGate(
              blurr: 0,
              opacity: 0,
              lockedBuilder: (context, secureNotifier) =>
                  const SizedBox.shrink(),
              child: app,
            );
          },
        ),
      );
    }

    // دائماً استخدام Stack للحفاظ على استقرار widget tree
    // هذا يمنع إعادة بناء المشغل عند ظهور/إخفاء الـ overlay
    final bool showOverlay = _hasActiveCaptureApps || _isScreenRecording;
    
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          // الـ child دائماً موجود في الـ tree
          app,
          // الـ overlay يظهر فقط عند الحاجة
          if (showOverlay)
            _buildSecurityOverlayContent(_isScreenRecording),
        ],
      ),
    );
  }

  Widget _buildSecurityOverlayContent(bool isScreenRecording) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Image.asset(
          'assets/images/Logo.png',
          width: 200,
          height: 200,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

