import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/app_arguments_service.dart';
import '../models/stream_data.dart';
import '../widgets/qr_code_dialog.dart';
import '../services/security_check_service.dart';

/// شاشة البداية - تحميل البيانات والتحقق من الصلاحيات
class SplashScreen extends StatefulWidget {
  final Function(StreamData) onVideoDataLoaded;
  final Function(String) onError;

  /// ✅ جديد: لو مفيش Token بعد وقت بسيط، نروح Home
  final VoidCallback? onGoHome;

  const SplashScreen({
    super.key,
    required this.onVideoDataLoaded,
    required this.onError,
    this.onGoHome, // ✅
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  String _statusMessage = 'جاري التحميل...';
  bool _hasError = false;
  bool _isWaitingForPlatform = false;

  /// ✅ جديد: يمنع تكرار الانتقال لـ Home
  bool _homeRedirectScheduled = false;
  bool _isLoadingData = false;
  bool _dataLoaded = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();

    // تأخير بسيط للتأكد من أن arguments service تم تهيئته
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _loadVideoData();
      }
    });

    // فحص دوري للـ arguments (كل ثانية) إذا لم تكن صالحة
    Future.delayed(const Duration(seconds: 1), () {
      _periodicCheck();
    });
  }

  void _periodicCheck() {
    if (!mounted) return;

    /*
    debugPrint('🔄 [SplashScreen] Periodic check running...');
    final argsService = AppArgumentsService.instance;
    final args = argsService.arguments;

    debugPrint(
        '🔄 [SplashScreen] Current args: ${args != null ? "exists" : "null"}');
    debugPrint(
        '🔄 [SplashScreen] isValid: ${args?.isValid}, hasToken: ${args?.token != null}');
    */
    final args = AppArgumentsService.instance.arguments;

    // إذا لم تكن هناك arguments صالحة، نستمر في الفحص
    if (args == null || !args.isValid || args.token == null) {
      if (_isWaitingForPlatform) {
        debugPrint(
            '🔄 [SplashScreen] Still waiting, will check again in 1 second...');
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) _periodicCheck();
        });
      }
    } else {
      // وجدنا arguments صالحة! إعادة تحميل البيانات
      debugPrint('✅ [SplashScreen] Valid arguments found in periodic check!');
      debugPrint('✅ [SplashScreen] Token length: ${args.token?.length ?? 0}');
      debugPrint('✅ [SplashScreen] Reloading data...');

      setState(() {
        _isWaitingForPlatform = false;
        _hasError = false;
        _statusMessage = 'جاري التحميل...';
      });

      // ✅ لو كان فيه redirect للـ Home متبرمج، خلاص token وصل: سيبه يكمّل تحميل
      _loadVideoData();
    }
  }

  @override
  void didUpdateWidget(SplashScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    debugPrint('🔄 [SplashScreen] Widget updated, checking for new arguments...');
    final argsService = AppArgumentsService.instance;
    final args = argsService.arguments;

    if (args != null && args.isValid && args.token != null) {
      debugPrint('🔄 [SplashScreen] Valid arguments found, reloading data...');
      setState(() {
        _isWaitingForPlatform = false;
        _hasError = false;
        _statusMessage = 'جاري التحميل...';
      });
      _loadVideoData();
    } else {
      debugPrint('⚠️ [SplashScreen] No valid arguments yet, waiting...');
    }
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// ✅ جديد: لو مفيش Token، اعرض Waiting شوية وبعدها روح Home
  void _scheduleGoHomeIfStillNoToken() {
    if (_homeRedirectScheduled) return;
    if (widget.onGoHome == null) return;

    _homeRedirectScheduled = true;

    // زيادة الوقت لـ 2 ثانية ليعطي فرصة للـ startup arguments
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (!mounted) return;

      final args = AppArgumentsService.instance.arguments;
      final hasToken = args != null && args.isValid && args.token != null;

      // لو token وصل في الوقت ده، ما تروحش Home
      if (hasToken) return;

      widget.onGoHome?.call();
    });
  }

  Future<void> _loadVideoData() async {
    if (_isLoadingData || _dataLoaded) {
      debugPrint('⏳ [SplashScreen] _loadVideoData() ignored: loading=$_isLoadingData, loaded=$_dataLoaded');
      return;
    }
    
    _isLoadingData = true;
    try {
      // debugPrint('📥 [SplashScreen] Starting _loadVideoData()...');

      final argsService = AppArgumentsService.instance;
      final args = argsService.arguments;

      /*
      debugPrint(
          '📥 [SplashScreen] Arguments: ${args != null ? "exists" : "null"}');
      debugPrint('📥 [SplashScreen] isValid: ${args?.isValid}');
      debugPrint(
          '📥 [SplashScreen] token: ${args?.token != null ? "exists (${args!.token!.length} chars)" : "null"}');
      */

      // ✅ لو مفيش arguments صالحة: اعرض waiting ثم روح Home (مع استمرار periodic check)
      if (args == null || !args.isValid || args.token == null) {
        debugPrint(
            '⏳ [SplashScreen] No valid arguments, showing waiting screen...');
        setState(() {
          _isWaitingForPlatform = true;
          _statusMessage = 'جاري انتظار فتح الفيديو من المنصة...';
        });

        // ✅ بعد وقت بسيط حوّل للهوم (بدون إيقاف الاستماع/الفحص)
        _scheduleGoHomeIfStillNoToken();

        return;
      }

      debugPrint(
          '✅ [SplashScreen] Valid arguments found, proceeding to load video data...');

      setState(() {
        _isWaitingForPlatform = false;
      });

      setState(() => _statusMessage = 'جاري التحقق من أمان النظام...');
      
      // 🛡️ التحقق من أمان بيئة التشغيل (وضع المطور، Debugger، إلخ)
      final securityService = SecurityCheckService();
      final securityResult = await securityService.checkSecurity();
      
      if (!securityResult.isSafe) {
        _setError(securityResult.message ?? 'تم اكتشاف تهديد أمني. لا يمكن تشغيل التطبيق في هذه البيئة.');
        return;
      }

      // تهيئة API
      final apiService = ApiService.instance;
      apiService.initialize(baseUrl: args.apiBase, token: args.token!);

      // 🛡️ التحقق من النسخة والبروتوكول (Force Update Check)
      setState(() => _statusMessage = 'جاري التحقق من تحديثات التطبيق...');
      final versionInfo = await apiService.checkVersion();
      if (versionInfo != null) {
        final minVersion = versionInfo['minVersion'] ?? 0;
        const currentVersion = 7; // Current Build Version
        
        if (currentVersion < minVersion) {
            _setError('يوجد تحديث إجباري للتطبيق. يرجى تحميل النسخة الجديدة للاستمرار.');
            return;
        }
      }

      setState(() => _statusMessage = 'جاري تحميل بيانات الفيديو...');

      // تسجيل وقت البدء لضمان بقاء السبلاش لمدة 6 ثوانٍ على الأقل
      final startTime = DateTime.now();

      StreamData streamData;

      if (args.token != null) {
        // debugPrint('📥 [SplashScreen] Fetching stream data with token...');
        streamData = await apiService.getStreamDataWithToken(args.token!);
        /*
        debugPrint(
            '📥 [SplashScreen] Stream data received: success=${streamData.success}');
        debugPrint('📥 [SplashScreen] Stream type: ${streamData.streamType}');
        debugPrint('📥 [SplashScreen] Provider: ${streamData.provider}');
        debugPrint('📥 [SplashScreen] Has videoId: ${streamData.videoId != null}');
        debugPrint(
            '📥 [SplashScreen] Has streamUrl: ${streamData.streamUrl != null}');
        */
        if (!streamData.success) {
          debugPrint(
              '❌ [SplashScreen] Error message: ${streamData.errorMessage}');
        }
      } else if (args.courseId != null && args.lessonId != null) {
        streamData = await apiService.getStreamData(
          courseId: args.courseId!,
          lessonId: args.lessonId!,
        );
      } else {
        _setError('تعذر تحميل بيانات الفيديو. يرجى التأكد من الاتصال بالإنترنت.');
        return;
      }

      if (!streamData.success) {
        _setError(streamData.errorMessage ?? 'فشل في تحميل الفيديو');
        return;
      }

      // ضمان مدة السبلاش 6 ثواني
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed.inSeconds < 6) {
        final remaining = Duration(seconds: 6) - elapsed;
        debugPrint(
            '⏳ [SplashScreen] Waiting for remaining ${remaining.inSeconds} seconds of splash...');
        await Future.delayed(remaining);
      }

      _dataLoaded = true;
      widget.onVideoDataLoaded(streamData);
    } catch (e) {
      _setError('حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى');
    }
  }

  void _setError(String message) {
    if (mounted) {
      setState(() {
        _hasError = true;
        _statusMessage = message;
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          widget.onError(message);
        }
      });
    }
  }

  /// إعادة تحميل البيانات (يتم استدعاؤها عند وصول Deep Link جديد)
  void reloadData() {
    if (mounted) {
      setState(() {
        _hasError = false;
        _statusMessage = 'جاري التحميل...';
      });
      _loadVideoData();
    }
  }

  void _showQrCodeDialog() {
    showDialog(
      context: context,
      builder: (context) => const QrCodeDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final argsService = AppArgumentsService.instance;
    final args = argsService.arguments;

    // القيم الافتراضية للألوان
    const defaultCreamColor = Color(0xFFFFF4E0);
    const lineColor = Color(0xFFEFE6D8);
    const brandColor = Color(0xFFFF5A1F);
    const inkColor = Color(0xFF1F1F1F);
    const mutedColor = Color(0xFF6A6A6A);

    // لون الخلفية
    Color backgroundColor = defaultCreamColor;
    if (args?.splashBgColor != null && args!.splashBgColor!.isNotEmpty) {
      try {
        String hexColor = args.splashBgColor!.replaceAll('#', '');
        if (hexColor.length == 6) {
          backgroundColor = Color(int.parse('FF$hexColor', radix: 16));
        }
      } catch (e) {
        debugPrint('⚠️ Error parsing background color: $e');
      }
    }

    // لون النص الأساسي
    Color titleTextColor = inkColor;
    if (args?.textColor != null && args!.textColor!.isNotEmpty) {
      try {
        String hexColor = args.textColor!.replaceAll('#', '');
        if (hexColor.length == 6) {
          titleTextColor = Color(int.parse('FF$hexColor', radix: 16));
        }
      } catch (e) {
        debugPrint('⚠️ Error parsing text color: $e');
      }
    }

    // لون النص الفرعي
    Color subtitleTextColor = _isWaitingForPlatform ? mutedColor : brandColor;
    if (args?.subtitleColor != null && args!.subtitleColor!.isNotEmpty) {
      try {
        String hexColor = args.subtitleColor!.replaceAll('#', '');
        if (hexColor.length == 6) {
          subtitleTextColor = Color(int.parse('FF$hexColor', radix: 16));
        }
      } catch (e) {
        debugPrint('⚠️ Error parsing subtitle color: $e');
      }
    }

    // العناوين
    String displayTitle;
    String displaySubtitle;

    if (args?.splashTitle != null && args!.splashTitle!.isNotEmpty) {
      displayTitle = args.splashTitle!;
      displaySubtitle = args.splashSubtitle ?? '';
    } else if (_isWaitingForPlatform) {
      displayTitle = 'مشغل إتقان التعليمي';
      displaySubtitle = 'برجاء الضغط على الفيديو من المنصة';
    } else {
      displayTitle = 'مشغل إتقان التعليمي';
      displaySubtitle = 'جاري تحضير المحتوى...';
    }

    final lineGradientColor =
        Color.lerp(backgroundColor, Colors.black, 0.05) ?? lineColor;

    // لون اللوجو
    Color logoTintColor = Colors.black;
    if (args?.logoColor != null && args!.logoColor!.isNotEmpty) {
      try {
        String hexColor = args.logoColor!.replaceAll('#', '');
        if (hexColor.length == 6) {
          logoTintColor = Color(int.parse('FF$hexColor', radix: 16));
        }
      } catch (e) {
        debugPrint('⚠️ Error parsing logo color: $e');
      }
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  backgroundColor,
                  lineGradientColor.withValues(alpha: 0.5),
                  backgroundColor,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: Image.asset(
                          'assets/images/Logo.png',
                          width: 180,
                          height: 180,
                          color: logoTintColor,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Title
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Text(
                        displayTitle,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: titleTextColor,
                          letterSpacing: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Subtitle
                    if (displaySubtitle.isNotEmpty)
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Text(
                          displaySubtitle,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: subtitleTextColor,
                            letterSpacing: 1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    const SizedBox(height: 48),

                    // Loading / Waiting / Error
                    if (!_hasError) ...[
                      if (_isWaitingForPlatform) ...[
                        SizedBox(
                          width: 56,
                          height: 56,
                          child: CircularProgressIndicator(
                            strokeWidth: 4,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                subtitleTextColor),
                            backgroundColor:
                                subtitleTextColor.withValues(alpha: 0.2),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _statusMessage,
                          style: const TextStyle(
                            fontSize: 16,
                            color: mutedColor,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        // (اختياري) زر كود سري (مخفي)
                        /*
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: ElevatedButton.icon(
                            onPressed: _showQrCodeDialog,
                            icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                            label: const Text(
                              'كود سري',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        */
                        const SizedBox.shrink(),
                      ] else ...[
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            strokeWidth: 4,
                            valueColor:
                                const AlwaysStoppedAnimation<Color>(brandColor),
                            backgroundColor: brandColor.withValues(alpha: 0.2),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _statusMessage,
                          style: const TextStyle(
                            fontSize: 16,
                            color: mutedColor,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ] else ...[
                      Icon(
                        Icons.error_outline,
                        size: 56,
                        color: Colors.red.shade400,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _statusMessage,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.red.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}