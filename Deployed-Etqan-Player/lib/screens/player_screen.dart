import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

import '../models/stream_data.dart';
import '../widgets/universal_player.dart';
import '../services/window_service.dart';

/// Intent مخصص للخروج من الفيديو (ESC / اختصارات)
class ExitVideoIntent extends Intent {
  const ExitVideoIntent();
}

/// شاشة مشغل الفيديو
class PlayerScreen extends StatefulWidget {
  final StreamData streamData;
  final String? title;

  /// خروج من الفيديو فقط (مثلاً الرجوع للـ Home)
  final VoidCallback? onClose;

  /// خروج من التطبيق بالكامل (اختياري)
  final VoidCallback? onExit;

  const PlayerScreen({
    super.key,
    required this.streamData,
    this.title,
    this.onClose,
    this.onExit,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  bool _showTopBar = true;

  @override
  void initState() {
    super.initState();
    _updateWindowTitle();

    // إخفاء system UI للهواتف
    _setupMobileUI();

    // تفعيل fullscreen افتراضياً عند فتح المشغل (Desktop فقط)
    _setupFullScreen();

    // إخفاء شريط التحكم العلوي تلقائيًا بعد ثواني
    _scheduleAutoHideTopBar();
  }

  void _scheduleAutoHideTopBar() {
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _showTopBar = false);
    });
  }

  void _showTopBarTemporarily() {
    if (!mounted) return;
    setState(() => _showTopBar = true);
    _scheduleAutoHideTopBar();
  }

  void _setupFullScreen() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      try {
        // التحقق من أن النافذة ليست في وضع fullscreen بالفعل
        final isFs = await WindowService.instance.isFullScreen();
        if (!isFs) {
          // بناءً على طلبك: Borderless Windowed Mode (Maximized)
          await WindowService.instance.maximize();

          // إخفاء system UI للـ Desktop
          await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
          // debugPrint('✅ Fullscreen enabled on player screen');
        }
      } catch (e) {
        // debugPrint('❌ Error setting fullscreen: $e');
      }
    }
  }

  void _setupMobileUI() {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      // الدخول في وضع immersive للحصول على أفضل تجربة مشاهدة
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

      // السماح بجميع الاتجاهات
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  void _restoreSystemUI() {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    } else if (!kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      // إعادة system UI للـ Desktop (لكن لا نخرج من fullscreen تلقائيًا)
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  void dispose() {
    // إعادة الإعدادات الافتراضية عند الخروج
    _restoreSystemUI();
    super.dispose();
  }

  void _updateWindowTitle() {
    if (widget.title != null && WindowService.instance.isDesktop) {
      WindowService.instance.setTitle('مشغل إتقان التعليمي - ${widget.title}');
    }
  }

  void _onVideoEnded() {
    // يمكن إضافة أي إجراء عند انتهاء الفيديو
    // debugPrint('✅ Video playback ended');
  }

  void _onVideoError(String error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error, textDirection: TextDirection.rtl),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// الخروج من الفيديو (مش من التطبيق)
  void _closeVideo() {
    // debugPrint('↩️ Closing player screen');

    _restoreSystemUI();

    if (widget.onClose != null) {
      widget.onClose!();
      return;
    }

    // fallback لو الشاشة معمولة push
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          // زر ESC للخروج من الفيديو (Desktop/Web)
          SingleActivator(LogicalKeyboardKey.escape): ExitVideoIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            ExitVideoIntent: CallbackAction<ExitVideoIntent>(
              onInvoke: (intent) {
                _closeVideo();
                return null;
              },
            ),
          },
          child: Focus(
            autofocus: true,
            child: WillPopScope(
              onWillPop: () async {
                _closeVideo();
                return false; // إحنا بنتعامل مع الرجوع يدويًا
              },
              child: Scaffold(
                backgroundColor: Colors.black,
                body: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _showTopBarTemporarily,
                  child: Stack(
                    children: [
                      // المشغل كامل الشاشة
                      Positioned.fill(
                        child: SafeArea(
                          top: false,
                          bottom: false,
                          child: UniversalPlayer(
                            streamData: widget.streamData,
                            autoPlay: true,
                            onEnded: _onVideoEnded,
                            onError: _onVideoError,
                          ),
                        ),
                      ),

                      // شريط علوي خفيف (يظهر/يختفي)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        top: _showTopBar ? 0 : -(topInset + 90),
                        left: 0,
                        right: 0,
                        child: IgnorePointer(
                          ignoring: !_showTopBar,
                          child: Container(
                            padding: EdgeInsets.only(
                              top: topInset + 10,
                              left: 12,
                              right: 12,
                              bottom: 10,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.65),
                                  Colors.black.withOpacity(0.25),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: Row(
                              children: [
                                // زر الخروج من الفيديو
                                Material(
                                  color: Colors.black.withOpacity(0.35),
                                  borderRadius: BorderRadius.circular(999),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(999),
                                    onTap: _closeVideo,
                                    child: const Padding(
                                      padding: EdgeInsets.all(10),
                                      child: Icon(
                                        Icons.close_rounded,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 10),

                                // عنوان الفيديو
                                Expanded(
                                  child: Text(
                                    (widget.title != null &&
                                            widget.title!.trim().isNotEmpty)
                                        ? widget.title!
                                        : 'مشغل الفيديو',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),

                                // زر خروج التطبيق بالكامل (اختياري)
                                if (widget.onExit != null) ...[
                                  const SizedBox(width: 10),
                                  Material(
                                    color: Colors.black.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(999),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(999),
                                      onTap: widget.onExit,
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.exit_to_app_rounded,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                              'خروج',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}