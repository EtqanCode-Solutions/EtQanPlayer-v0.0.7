import 'dart:io' show Platform;
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:window_manager/window_manager.dart';

/// خدمة إدارة نافذة Desktop
class WindowService {
  static WindowService? _instance;
  bool _isInitialized = false;

  WindowService._();

  static WindowService get instance {
    _instance ??= WindowService._();
    return _instance!;
  }

  /// تهيئة نافذة التطبيق
  Future<void> initialize({
    String title = 'مشغل إتقان التعليمي',
    double minWidth = 800,
    double minHeight = 600,
    double? width,
    double? height,
    bool center = true,
    bool fullScreen = false,
  }) async {
    if (_isInitialized) return;
    if (!_isDesktop) return;

    try {
      await windowManager.ensureInitialized();

      final windowOptions = WindowOptions(
        size: Size(width ?? 1280, height ?? 720),
        minimumSize: Size(minWidth, minHeight),
        center: center,
        backgroundColor: const Color(0xFF000000),
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
        title: title,
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
        
        if (fullScreen) {
          await windowManager.setFullScreen(true);
        }
      });

      _isInitialized = true;
      debugPrint('✅ Window initialized: $title');
    } catch (e) {
      debugPrint('❌ Error initializing window: $e');
    }
  }

  /// تغيير عنوان النافذة
  Future<void> setTitle(String title) async {
    if (!_isDesktop) return;
    try {
      await windowManager.setTitle(title);
    } catch (e) {
      debugPrint('❌ Error setting window title: $e');
    }
  }

  /// تفعيل/تعطيل وضع الشاشة الكاملة
  Future<void> setFullScreen(bool fullScreen) async {
    if (!_isDesktop) return;
    try {
      await windowManager.setFullScreen(fullScreen);
    } catch (e) {
      debugPrint('❌ Error setting fullscreen: $e');
    }
  }

  /// التحقق من وضع الشاشة الكاملة
  Future<bool> isFullScreen() async {
    if (!_isDesktop) return false;
    try {
      return await windowManager.isFullScreen();
    } catch (e) {
      debugPrint('❌ Error checking fullscreen: $e');
      return false;
    }
  }

  /// تبديل وضع الشاشة الكاملة
  Future<void> toggleFullScreen() async {
    if (!_isDesktop) return;
    final isFs = await isFullScreen();
    await setFullScreen(!isFs);
  }

  /// إغلاق النافذة
  Future<void> close() async {
    if (!_isDesktop) return;
    try {
      await windowManager.close();
    } catch (e) {
      debugPrint('❌ Error closing window: $e');
    }
  }

  /// تصغير النافذة
  Future<void> minimize() async {
    if (!_isDesktop) return;
    try {
      await windowManager.minimize();
    } catch (e) {
      debugPrint('❌ Error minimizing window: $e');
    }
  }

  /// استعادة النافذة
  Future<void> restore() async {
    if (!_isDesktop) return;
    try {
      await windowManager.restore();
    } catch (e) {
      debugPrint('❌ Error restoring window: $e');
    }
  }

  /// تكبير النافذة
  Future<void> maximize() async {
    if (!_isDesktop) return;
    try {
      await windowManager.maximize();
    } catch (e) {
      debugPrint('❌ Error maximizing window: $e');
    }
  }

  /// منع إغلاق النافذة (للتأكيد قبل الإغلاق)
  Future<void> setPreventClose(bool prevent) async {
    if (!_isDesktop) return;
    try {
      await windowManager.setPreventClose(prevent);
    } catch (e) {
      debugPrint('❌ Error setting prevent close: $e');
    }
  }

  /// التحقق من كون المنصة Desktop
  bool get _isDesktop => !kIsWeb &&
      (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  bool get isDesktop => _isDesktop;
}

