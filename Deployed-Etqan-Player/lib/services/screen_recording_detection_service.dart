import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// خدمة للكشف عن Screen Recording و Screen Mirroring على iOS
/// تستخدم UIScreen.isCaptured API المسموح من Apple
class ScreenRecordingDetectionService {
  static final ScreenRecordingDetectionService _instance =
      ScreenRecordingDetectionService._internal();

  factory ScreenRecordingDetectionService() => _instance;
  ScreenRecordingDetectionService._internal();

  static const MethodChannel _channel = MethodChannel(
    'com.etqan.player/screen_recording',
  );

  final StreamController<bool> _recordingStateController =
      StreamController<bool>.broadcast();
  Stream<bool> get recordingStateStream => _recordingStateController.stream;

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  bool _isMonitoring = false;
  bool get isMonitoring => _isMonitoring;

  /// بدء مراقبة Screen Recording/Mirroring
  Future<bool> startMonitoring() async {
    if (_isMonitoring) return true;

    if (!Platform.isIOS) {
      debugPrint('⚠️ Screen recording detection is only available on iOS');
      return false;
    }

    try {
      // إعداد Method Call Handler للاستماع للتغييرات من native code
      _channel.setMethodCallHandler(_handleMethodCall);

      // بدء المراقبة في native code
      final result = await _channel.invokeMethod<bool>('startMonitoring');

      // التحقق من الحالة الحالية
      final currentState = await _channel.invokeMethod<bool>(
        'isScreenRecording',
      );
      _isRecording = currentState ?? false;
      _recordingStateController.add(_isRecording);

      _isMonitoring = result ?? false;

      if (_isMonitoring) {
        debugPrint(
          '✅ Screen recording monitoring started. Current state: $_isRecording',
        );
      } else {
        debugPrint('❌ Failed to start screen recording monitoring');
      }

      return _isMonitoring;
    } catch (e) {
      debugPrint('❌ Error starting screen recording monitoring: $e');
      return false;
    }
  }

  /// إيقاف مراقبة Screen Recording/Mirroring
  Future<bool> stopMonitoring() async {
    if (!_isMonitoring) return true;

    if (!Platform.isIOS) {
      return false;
    }

    try {
      _channel.setMethodCallHandler(null);
      final result = await _channel.invokeMethod<bool>('stopMonitoring');
      _isMonitoring = !(result ?? false);

      if (!_isMonitoring) {
        debugPrint('✅ Screen recording monitoring stopped');
      }

      return !_isMonitoring;
    } catch (e) {
      debugPrint('❌ Error stopping screen recording monitoring: $e');
      return false;
    }
  }

  /// التحقق من حالة Screen Recording/Mirroring الحالية
  Future<bool> checkRecordingState() async {
    if (!Platform.isIOS) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>('isScreenRecording');
      _isRecording = result ?? false;
      return _isRecording;
    } catch (e) {
      debugPrint('❌ Error checking screen recording state: $e');
      return false;
    }
  }

  /// معالج Method Calls من native code
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onScreenRecordingChanged':
        final isRecording = call.arguments as bool? ?? false;
        _isRecording = isRecording;
        _recordingStateController.add(_isRecording);

        if (_isRecording) {
          debugPrint('🚨 Screen Recording/Mirroring detected!');
        } else {
          debugPrint('✅ Screen Recording/Mirroring stopped');
        }
        break;
      default:
        debugPrint('⚠️ Unknown method call: ${call.method}');
    }
  }

  /// تنظيف الموارد
  void dispose() {
    stopMonitoring();
    _recordingStateController.close();
  }
}
