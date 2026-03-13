// lib/main.dart
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show ImageFilter;

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

import 'widgets/secure_app_wrapper.dart';
import 'screens/splash_screen.dart';
import 'screens/player_screen.dart';
import 'screens/error_screen.dart';
import 'services/app_arguments_service.dart';
import 'services/window_service.dart';
import 'models/stream_data.dart';

/// نقطة الدخول الرئيسية للتطبيق
void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة MediaKit للـ Desktop
  MediaKit.ensureInitialized();

  // إعداد system UI
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // تهيئة arguments service
  final argsService = AppArgumentsService.instance;

  // على Windows، deep links يتم تمريرها كـ command line arguments
  debugPrint('📋 Command line args count: ${args.length}');
  for (int i = 0; i < args.length; i++) {
    debugPrint('📋 Arg[$i]: ${args[i]}');
  }

  // البحث عن deep link في command line arguments (دمج args لتفادي تقسيم الرابط)
  final allArgsString = args.join(' ');
  String? deepLinkFromArgs;

  if (allArgsString.contains('etqanplayer://')) {
    final match = RegExp(r'(etqanplayer://[^\s"]+)').firstMatch(allArgsString);
    if (match != null) {
      deepLinkFromArgs = match.group(0);
      debugPrint('🔗 Found deep link by joining args: $deepLinkFromArgs');
    }
  }

  // إذا وجدنا deep link في command line، استخدمه
  if (deepLinkFromArgs != null) {
    debugPrint('🔗 Initializing from command line deep link: $deepLinkFromArgs');
    argsService.initializeFromDeepLink(deepLinkFromArgs);
  } else {
    // محاولة الحصول على Deep Link من app_links (للموبايل)
    String? initialLink;
    try {
      final appLinks = AppLinks();
      final link = await appLinks.getInitialLink();
      if (link != null) {
        initialLink = link.toString();
        debugPrint('🔗 Initial deep link from app_links: $initialLink');
        argsService.initializeFromDeepLink(initialLink);
      }
    } catch (e) {
      debugPrint('⚠️ Error getting initial link: $e');
    }

    // إذا لم يكن هناك Deep Link، استخدم command line arguments العادية
    if (initialLink == null) {
      if (args.isNotEmpty) {
        // debugPrint('📋 Parsing command line arguments: $args');
        argsService.initialize(args);
      } else {
        // debugPrint('⏳ No arguments provided - waiting for deep link');
      }
    }
  }

  // تهيئة نافذة Desktop (فقط لغير الويب)
  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    await WindowService.instance.initialize(
      title: 'مشغل إتقان التعليمي',
      width: 1280,
      height: 720,
      minWidth: 800,
      minHeight: 600,
      center: true,
    );
  }

  runApp(const SamyPlayerApp());
}

/// التطبيق الرئيسي
class SamyPlayerApp extends StatelessWidget {
  const SamyPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return SecureAppWrapper(
      enableScreenshotProtection: true,
      enableProcessMonitoring: true,
      enableSecureApplication: false, // تعطيل لإخفاء مؤشر "Protected"
      onProtectionStatusChanged: (isProtected) {
        debugPrint('🛡️ Protection status: $isProtected');
      },
      child: MaterialApp(
        title: 'مشغل إتقان التعليمي',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        builder: (context, child) {
          // ✅ فرض اتجاه عربي على مستوى التطبيق كله
          return Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const AppNavigator(),
      ),
    );
  }

  ThemeData _buildTheme() {
    // ألوان من ثيم Frontend
    const brandColor = Color(0xFFFF5A1F); // برتقالي محمر
    const accentColor = Color(0xFFFFB000); // أصفر ذهبي
    const deepColor = Color(0xFF6E0008); // أحمر داكن
    const charcoalColor = Color(0xFF1F1F1F); // رمادي داكن

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: charcoalColor,
      colorScheme: const ColorScheme.dark(
        primary: brandColor,
        secondary: accentColor,
        surface: charcoalColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.white,
        error: deepColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          shadowColor: brandColor.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

/// شاشات التطبيق
enum AppScreen { splash, home, player, error }

/// مدير التنقل بين الشاشات (Splash -> Home/Player/Error)
class AppNavigator extends StatefulWidget {
  const AppNavigator({super.key});

  @override
  State<AppNavigator> createState() => _AppNavigatorState();
}

class _AppNavigatorState extends State<AppNavigator> {
  AppScreen _currentScreen = AppScreen.splash;

  StreamData? _streamData;
  String? _errorMessage;
  String? _videoTitle;

  StreamSubscription<Uri>? _linkSubscription;
  StreamSubscription<String>? _customLinkSubscription;
  final _appLinks = AppLinks();



  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  void _initDeepLinks() {
    debugPrint('🔗 Initializing deep link listener...');

    // app_links stream
    try {
      _linkSubscription = _appLinks.uriLinkStream.listen(
        (Uri uri) {
          final link = uri.toString();
          if (link.isNotEmpty) {
            debugPrint('🔗 Deep link received via stream: $link');
            _handleDeepLink(link);
          }
        },
        onError: (err) {
          debugPrint('❌ Deep link stream error: $err');
        },
      );
    } catch (e) {
      debugPrint('⚠️ Failed to initialize link stream: $e');
      debugPrint(
        '⚠️ This is normal on Windows - deep links come via command line / IPC',
      );
    }

    // custom stream (IPC/MethodChannel)
    _customLinkSubscription =
        AppArgumentsService.instance.onDeepLinkReceived.listen((link) {
      if (link.isEmpty) return;
      debugPrint('🔗 Deep link received via custom stream: $link');
      _handleDeepLink(link);
    });

    // initial link
    _appLinks.getInitialLink().then((uri) {
      if (uri == null) return;
      final link = uri.toString();
      if (link.isNotEmpty) {
        debugPrint('🔗 Initial deep link found: $link');
        _handleDeepLink(link);
      }
    }).catchError((err) {
      debugPrint(
        '⚠️ Error getting initial link: $err (this is normal on Windows)',
      );
    });

    // windows/mac/linux: check again shortly (when app opened while running)
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      Future.delayed(const Duration(milliseconds: 500), _checkForNewArguments);
    }
  }

  void _checkForNewArguments() {
    final currentArgs = AppArgumentsService.instance.arguments;
    if (currentArgs == null || !currentArgs.isValid || currentArgs.token == null) {
      debugPrint('🔄 Checking for new arguments... (none)');
      return;
    }

    debugPrint('✅ New valid arguments found, going to splash...');
    setState(() {
      _currentScreen = AppScreen.splash;
      _streamData = null;
      _errorMessage = null;
      _videoTitle = null;
    });
  }

  void _handleDeepLink(String link) {


    debugPrint('🔗 Processing deep link: $link');
    AppArgumentsService.instance.initializeFromDeepLink(link);

    // رجّع Splash عشان هي اللي تعمل load وتفتح Player
    setState(() {
      _currentScreen = AppScreen.splash;
      _streamData = null;
      _errorMessage = null;
      _videoTitle = null;
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _customLinkSubscription?.cancel();
    super.dispose();
  }

  void _goHome() {
    setState(() {
      _currentScreen = AppScreen.home;
      _streamData = null;
      _errorMessage = null;
      _videoTitle = null;
    });
  }

  void _openPlayer(StreamData data, {String? title}) {
    setState(() {
      _streamData = data;
      _videoTitle = title;
      _currentScreen = AppScreen.player;
    });
  }

  void _openDemoVideo() {
    // YouTube Demo Video
    const videoId = 'FYIv8liLXBw';

    final demoStream = StreamData.youtube(videoId, lessonTitle: 'فيديو تجريبي');
    _openPlayer(demoStream, title: 'فيديو تجريبي');
  }

  void _retry() {
    setState(() {
      _currentScreen = AppScreen.splash;
      _errorMessage = null;
      _streamData = null;
      _videoTitle = null;
    });
  }

  void _exitApp() {
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      WindowService.instance.close();
    } else {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_currentScreen) {
      case AppScreen.splash:
        // key ديناميكي لتجديد splash عند تغيير token
        final args = AppArgumentsService.instance.arguments;
        final keyValue =
            args?.token ?? 'waiting_${DateTime.now().millisecondsSinceEpoch}';

        return SplashScreen(
          key: ValueKey('splash_$keyValue'),
          onVideoDataLoaded: (streamData) {
            final argsNow = AppArgumentsService.instance.arguments;
            _openPlayer(streamData, title: argsNow?.splashTitle);
          },
          onError: (error) {
            setState(() {
              _errorMessage = error;
              _currentScreen = AppScreen.error;
            });
          },
          onGoHome: _goHome, // ✅ مهم
        );

      case AppScreen.home:
        return HomeScreen(

          onPlayDemo: _openDemoVideo,
          onExit: _exitApp,
        );

      case AppScreen.player:
        if (_streamData == null) {
          return SplashScreen(
            onVideoDataLoaded: (d) => _openPlayer(d),
            onError: (e) {
              setState(() {
                _errorMessage = e;
                _currentScreen = AppScreen.error;
              });
            },
            onGoHome: _goHome,
          );
        }
        return PlayerScreen(
          streamData: _streamData!,
          title: _videoTitle,
          onClose: _goHome, // ✅ مهم جدًا: رجوع من الفيديو إلى الصفحة الرئيسية
          onExit: _exitApp,
        );

      case AppScreen.error:
        return ErrorScreen(
          errorMessage: _errorMessage ?? 'حدث خطأ غير معروف',
          onRetry: _retry,
          onExit: _exitApp,
        );
    }
  }
}

/// ✅ Home UI جديد بالكامل + AppBar متوافق مع النوتش
class HomeScreen extends StatelessWidget {
  final VoidCallback onPlayDemo;
  final VoidCallback onExit;

  const HomeScreen({
    super.key,
    required this.onPlayDemo,
    required this.onExit,
  });

  Color _parseHex(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    try {
      final cleaned = hex.replaceAll('#', '');
      if (cleaned.length == 6) {
        return Color(int.parse('FF$cleaned', radix: 16));
      }
    } catch (_) {}
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final args = AppArgumentsService.instance.arguments;

    // نفس قيم Splash الافتراضية
    const defaultCreamColor = Color(0xFFFFF4E0);
    const lineColor = Color(0xFFEFE6D8);
    const brandColor = Color(0xFFFF5A1F);
    const accentColor = Color(0xFFFFB000);
    const inkColor = Color(0xFF1F1F1F);
    const mutedColor = Color(0xFF6A6A6A);

    final backgroundColor = _parseHex(args?.splashBgColor, defaultCreamColor);
    final titleTextColor = _parseHex(args?.textColor, inkColor);
    final subtitleTextColor = _parseHex(args?.subtitleColor, brandColor);
    final logoTintColor = _parseHex(args?.logoColor, Colors.black);

    final lineGradientColor =
        Color.lerp(backgroundColor, Colors.black, 0.05) ?? lineColor;

    final displayTitle =
        (args?.splashTitle != null && args!.splashTitle!.isNotEmpty)
            ? args.splashTitle!
            : 'مشغل إتقان التعليمي';

    final displaySubtitle =
        (args?.splashSubtitle != null && args!.splashSubtitle!.isNotEmpty)
            ? args.splashSubtitle!
            : 'افتح الدرس من المنصة وسيعمل هنا تلقائيًا.';

    // ✅ تقليل الخطوات (3 فقط + نصوص مختصرة)
    const steps = <_UiStep>[
      _UiStep(
        icon: Icons.menu_book_rounded,
        title: 'افتح الدرس',
        body: 'ادخل على الدرس من المنصة.',
      ),
      _UiStep(
        icon: Icons.play_circle_fill_rounded,
        title: 'اضغط تشغيل',
        body: 'اضغط زر تشغيل الفيديو من المنصة.',
      ),
      _UiStep(
        icon: Icons.open_in_new_rounded,
        title: 'سيعمل تلقائيًا',
        body: 'اترك المشغل مفتوحًا وسيتم تشغيل الفيديو هنا.',
      ),
    ];

    Widget glassCard({
      required Widget child,
      EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    }) {
      return Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.70),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: child,
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      // مهم: نخليه false عشان الـ AppBar يظهر صح مع النوتش
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        toolbarHeight: 72,
        automaticallyImplyLeading: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: brandColor, // ✅ نفس لون التطبيق (برتقالي)
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        centerTitle: false,
        title: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsetsDirectional.only(start: 14, end: 8),
                decoration: BoxDecoration(
                  // ✅ كارت داخلي برتقالي قريب من لون البراند
                  color: const Color(0xFFE94E16),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.16),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // الاسم على جنب
                    Expanded(
                      child: Text(
                        displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.start,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15.5,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // زرار تشغيل تجريبي سريع
                    FilledButton.icon(
                      onPressed: onPlayDemo,
                      icon: const Icon(
                        Icons.play_circle_filled_rounded,
                        size: 18,
                      ),
                      label: const Text('تجربة التشغيل'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: brandColor,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              backgroundColor,
              lineGradientColor.withValues(alpha: 0.65),
              backgroundColor,
            ],
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  children: [
                    // Hero / Intro
                    glassCard(
                      padding: const EdgeInsets.all(18),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isTight = constraints.maxWidth < 600;

                          final logoWidget = Container(
                            width: isTight ? 82 : 96,
                            height: isTight ? 82 : 96,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.black.withValues(alpha: 0.05),
                              ),
                            ),
                            child: Center(
                              child: Image.asset(
                                'assets/images/Logo.png',
                                width: isTight ? 52 : 62,
                                height: isTight ? 52 : 62,
                                color: logoTintColor,
                                fit: BoxFit.contain,
                              ),
                            ),
                          );

                          final textWidget = Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: brandColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(
                                          color: brandColor.withValues(alpha: 0.20),
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.ondemand_video_rounded,
                                            size: 16,
                                            color: brandColor,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'مشغل الدروس',
                                            style: TextStyle(
                                              color: brandColor,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.55),
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(
                                          color: Colors.black.withValues(alpha: 0.05),
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.flash_on_rounded,
                                            size: 16,
                                            color: Color(0xFFFFB000),
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'تشغيل تلقائي',
                                            style: TextStyle(
                                              color: inkColor,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  displayTitle,
                                  style: TextStyle(
                                    fontSize: isTight ? 20 : 24,
                                    fontWeight: FontWeight.w900,
                                    color: titleTextColor,
                                    height: 1.15,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  displaySubtitle,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.45,
                                    fontWeight: FontWeight.w700,
                                    color: subtitleTextColor,
                                  ),
                                ),
                              ],
                            ),
                          );

                          if (isTight) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    logoWidget,
                                    const SizedBox(width: 12),
                                    Expanded(child: textWidget),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                _QuickActionsRow(
                                  onPlayDemo: onPlayDemo,
                                ),
                              ],
                            );
                          }

                          return Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  logoWidget,
                                  const SizedBox(width: 14),
                                  textWidget,
                                ],
                              ),
                              const SizedBox(height: 14),
                              _QuickActionsRow(
                                onPlayDemo: onPlayDemo,
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 14),

                    // خطوات التشغيل (مختصرة)
                    glassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: accentColor.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.auto_awesome_rounded,
                                  color: Color(0xFFFFB000),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'خطوات التشغيل',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: titleTextColor,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${steps.length} خطوات',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: mutedColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          ...List.generate(steps.length, (i) {
                            final step = steps[i];
                            final isLast = i == steps.length - 1;

                            return Padding(
                              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Column(
                                    children: [
                                      Container(
                                        width: 34,
                                        height: 34,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: brandColor.withValues(alpha: 0.14),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: brandColor.withValues(alpha: 0.22),
                                          ),
                                        ),
                                        child: Text(
                                          '${i + 1}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            color: brandColor,
                                          ),
                                        ),
                                      ),
                                      if (!isLast)
                                        Container(
                                          width: 2,
                                          height: 28,
                                          margin: const EdgeInsets.symmetric(vertical: 6),
                                          decoration: BoxDecoration(
                                            color: brandColor.withValues(alpha: 0.18),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.55),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: Colors.black.withValues(alpha: 0.05),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 34,
                                            height: 34,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.75),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: Colors.black
                                                    .withValues(alpha: 0.05),
                                              ),
                                            ),
                                            child: Icon(
                                              step.icon,
                                              size: 19,
                                              color: brandColor,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  step.title,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w900,
                                                    color: titleTextColor,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  step.body,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    height: 1.35,
                                                    color: inkColor,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // كروت معلومات سريعة (مختصرة: 2 فقط)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 700;
                        final cards = [
                          _InfoTileData(
                            icon: Icons.lock_clock_rounded,
                            title: 'اترك المشغل مفتوحًا',
                            body: 'سيتم تشغيل الفيديو تلقائيًا عند الضغط من المنصة.',
                          ),
                          _InfoTileData(
                            icon: Icons.build_circle_rounded,
                            title: 'جرّب التشغيل التجريبي',
                            body: 'للتأكد أن المشغل يعمل بشكل طبيعي.',
                          ),
                        ];

                        if (isNarrow) {
                          return Column(
                            children: [
                              for (int i = 0; i < cards.length; i++) ...[
                                glassCard(
                                  child: _InfoTile(
                                    data: cards[i],
                                    iconColor: brandColor,
                                    titleColor: titleTextColor,
                                  ),
                                ),
                                if (i != cards.length - 1)
                                  const SizedBox(height: 12),
                              ],
                            ],
                          );
                        }

                        return Row(
                          children: [
                            for (int i = 0; i < cards.length; i++) ...[
                              Expanded(
                                child: glassCard(
                                  child: _InfoTile(
                                    data: cards[i],
                                    iconColor: brandColor,
                                    titleColor: titleTextColor,
                                  ),
                                ),
                              ),
                              if (i != cards.length - 1)
                                const SizedBox(width: 12),
                            ],
                          ],
                        );
                      },
                    ),



                    const SizedBox(height: 14),

                    Text(
                      'عند الضغط على تشغيل من المنصة، الفيديو سيفتح هنا تلقائيًا.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: titleTextColor.withValues(alpha: 0.65),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  final VoidCallback onPlayDemo;

  const _QuickActionsRow({
    required this.onPlayDemo,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton.icon(
          onPressed: onPlayDemo,
          icon: const Icon(Icons.play_circle_fill_rounded, size: 18),
          label: const Text('تشغيل تجريبي سريع'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFF5A1F),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoTileData {
  final IconData icon;
  final String title;
  final String body;

  const _InfoTileData({
    required this.icon,
    required this.title,
    required this.body,
  });
}

class _InfoTile extends StatelessWidget {
  final _InfoTileData data;
  final Color iconColor;
  final Color titleColor;

  const _InfoTile({
    required this.data,
    required this.iconColor,
    required this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: iconColor.withValues(alpha: 0.18)),
          ),
          child: Icon(data.icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.title,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data.body,
                style: const TextStyle(
                  color: Color(0xFF3A3A3A),
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UiStep {
  final IconData icon;
  final String title;
  final String body;

  const _UiStep({
    required this.icon,
    required this.title,
    required this.body,
  });
}