import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// خدمة للتحقق من أمان بيئة التشغيل (وضع المطور، Debugger، إلخ)
class SecurityCheckService {
  static final SecurityCheckService _instance = SecurityCheckService._internal();
  factory SecurityCheckService() => _instance;
  SecurityCheckService._internal();

  static const _channel = MethodChannel('com.etqan.player/security');

  /// إجراء فحص شامل للأمان
  Future<SecurityCheckResult> checkSecurity() async {
    // على الويب لا يوجد وضع مطور بنفس المفهوم أو إمكانية منعه برمجياً بسهولة
    if (kIsWeb) return SecurityCheckResult.safe();

    try {
      // 1. التحقق من وجود Debugger (Android & iOS)
      final bool isDebuggerAttached = await _channel.invokeMethod('isDebuggerAttached') ?? false;
      if (isDebuggerAttached && !kDebugMode) {
        return SecurityCheckResult.unsafe(
          'تم اكتشاف برنامج تصحيح (Debugger). يرجى إغلاق كافة برامج التطوير والمحاولة مرة أخرى.',
        );
      }

      // 2. التحقق من وضع المطور (Android فقط)
      if (Platform.isAndroid) {
        final bool isDevMode = await _channel.invokeMethod('isDeveloperModeEnabled') ?? false;
        if (isDevMode) {
          return SecurityCheckResult.unsafe(
            'وضع المطور (Developer Mode) مفعّل على جهازك. يرجى إيقاف تشغيله من إعدادات النظام لحماية المحتوى التعليمي.',
          );
        }
      }

      debugPrint('🛡️ Security check passed');
      return SecurityCheckResult.safe();
    } catch (e) {
      debugPrint('⚠️ Security check error: $e');
      // في حالة الخطأ، نعتبر البيئة آمنة لتجنب منع المستخدمين بسبب خطأ فني
      return SecurityCheckResult.safe();
    }
  }
}

class SecurityCheckResult {
  final bool isSafe;
  final String? message;

  SecurityCheckResult({required this.isSafe, this.message});

  factory SecurityCheckResult.safe() => SecurityCheckResult(isSafe: true);
   factory SecurityCheckResult.unsafe(String message) => SecurityCheckResult(isSafe: false, message: message);
}
