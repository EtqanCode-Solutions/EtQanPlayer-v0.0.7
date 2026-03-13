import 'package:flutter/foundation.dart';

/// خدمة للتحكم في الصوت من أي مكان في التطبيق
/// تستخدم للكتم التلقائي عند اكتشاف التصوير
class AudioControlService {
  static final AudioControlService _instance = AudioControlService._internal();
  factory AudioControlService() => _instance;
  AudioControlService._internal();

  // Callback للتحكم في الصوت
  Function(bool)? _muteCallback;


  /// تسجيل callback للتحكم في الصوت
  void registerMuteCallback(Function(bool) callback) {
    _muteCallback = callback;
    debugPrint('🔊 [AudioControlService] Mute callback registered');
  }

  /// إلغاء تسجيل callback
  void unregisterMuteCallback() {
    _muteCallback = null;
    debugPrint('🔊 [AudioControlService] Mute callback unregistered');
  }

  /// كتم الصوت
  void mute() {
    if (_muteCallback != null) {
      _muteCallback!(true);
      debugPrint('🔇 [AudioControlService] Audio muted');
    } else {
      debugPrint('⚠️ [AudioControlService] No mute callback registered');
    }
  }

  /// إلغاء كتم الصوت
  void unmute() {
    if (_muteCallback != null) {
      _muteCallback!(false);
      debugPrint('🔊 [AudioControlService] Audio unmuted');
    } else {
      debugPrint('⚠️ [AudioControlService] No mute callback registered');
    }
  }

  /// التحقق من وجود callback مسجل
  bool get hasCallback => _muteCallback != null;
}
