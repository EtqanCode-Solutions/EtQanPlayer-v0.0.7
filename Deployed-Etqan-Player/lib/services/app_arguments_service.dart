import 'package:args/args.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';

/// بيانات الفيديو المستلمة من command line arguments
class VideoArguments {
  final String? token;
  final int? lessonId;
  final int? courseId;
  final String apiBase;
  final bool isValid;
  final String? errorMessage;
  
  // بيانات السبلاش - تُرسل من Frontend
  final String? splashTitle;
  final String? splashSubtitle;
  final String? splashBgColor;
  final String? logoColor;
  final String? textColor;
  final String? subtitleColor;

  const VideoArguments({
    this.token,
    this.lessonId,
    this.courseId,
    this.apiBase = 'http://31.97.154.182:65000/api',
    this.isValid = false,
    this.errorMessage,
    this.splashTitle,
    this.splashSubtitle,
    this.splashBgColor,
    this.logoColor,
    this.textColor,
    this.subtitleColor,
  });

  factory VideoArguments.fromArgs(List<String> args) {
    final parser = ArgParser()
      ..addOption(
        'token',
        abbr: 't',
        help: 'Authentication token for API access',
      )
      ..addOption('lesson-id', abbr: 'l', help: 'Lesson ID to play')
      ..addOption(
        'course-id',
        abbr: 'c',
        help: 'Course ID containing the lesson',
      )
      ..addOption(
        'api-base',
        abbr: 'a',
        help: 'Base URL for the API',
        defaultsTo: 'http://31.97.154.182:65000/api',
      )
      ..addFlag(
        'help',
        abbr: 'h',
        help: 'Show usage information',
        negatable: false,
      );

    try {
      final results = parser.parse(args);

      if (results['help'] as bool) {
        debugPrint('Usage: samy_player [options]');
        debugPrint(parser.usage);
        return const VideoArguments(
          isValid: false,
          errorMessage: 'Help requested',
        );
      }

      final token = results['token'] as String?;
      final lessonIdStr = results['lesson-id'] as String?;
      final courseIdStr = results['course-id'] as String?;
      final apiBase = results['api-base'] as String;

      // التحقق من الحقول المطلوبة
      if (token == null || token.isEmpty) {
        return const VideoArguments(
          isValid: false,
          errorMessage: 'Token is required (--token or -t)',
        );
      }

      // Token فقط كافٍ - courseId و lessonId سيتم استخراجهما من Token في Backend
      // لكن للتوافق مع الكود القديم، يمكن تمريرها اختيارياً
      int? lessonId;
      int? courseId;

      if (lessonIdStr != null && lessonIdStr.isNotEmpty) {
        lessonId = int.tryParse(lessonIdStr);
      }

      if (courseIdStr != null && courseIdStr.isNotEmpty) {
        courseId = int.tryParse(courseIdStr);
      }

      return VideoArguments(
        token: token,
        lessonId: lessonId,
        courseId: courseId,
        apiBase: apiBase,
        isValid: true,
        splashTitle: null,
        splashSubtitle: null,
        splashBgColor: null,
      );
    } catch (e) {
      debugPrint('Error parsing arguments: $e');
      return VideoArguments(
        isValid: false,
        errorMessage: 'Error parsing arguments: $e',
      );
    }
  }

  /// إنشاء arguments للتطوير/الاختبار
  factory VideoArguments.development({
    String token = 'dev-token',
    int lessonId = 1,
    int courseId = 1,
    String apiBase = 'https://testapi.etqan-code.com/api/v1',
    String? splashTitle,
    String? splashSubtitle,
    String? splashBgColor,
  }) {
    return VideoArguments(
      token: token,
      lessonId: lessonId,
      courseId: courseId,
      apiBase: apiBase,
      isValid: true,
      splashTitle: splashTitle,
      splashSubtitle: splashSubtitle,
      splashBgColor: splashBgColor,
    );
  }

  @override
  String toString() {
    return 'VideoArguments(token: ${token != null ? "***" : null}, '
        'lessonId: $lessonId, courseId: $courseId, '
        'apiBase: $apiBase, isValid: $isValid)';
  }
}

/// خدمة إدارة arguments التطبيق
class AppArgumentsService {
  static AppArgumentsService? _instance;
  VideoArguments? _arguments;

  static const MethodChannel _channel = MethodChannel('com.etqan.player/deep_link');
  final _deepLinkController = StreamController<String>.broadcast();
  
  Stream<String> get onDeepLinkReceived => _deepLinkController.stream;

  AppArgumentsService._() {
    // الاستماع للروابط القادمة من الكود الأصلي (خاص بويندوز)
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        final String? link = call.arguments as String?;
        if (link != null && link.isNotEmpty) {
          debugPrint('📥 Received deep link from native: $link');
          initializeFromDeepLink(link);
          _deepLinkController.add(link);
        }
      }
    });
  }

  static AppArgumentsService get instance {
    _instance ??= AppArgumentsService._();
    return _instance!;
  }

  /// تهيئة الخدمة مع arguments
  void initialize(List<String> args) {
    _arguments = VideoArguments.fromArgs(args);
    // debugPrint('📋 Parsed arguments: $_arguments');
  }

  /// تهيئة من Deep Link URL
  /// مثال: samyplayer://play?token=ENCRYPTED_TOKEN
  void initializeFromDeepLink(String url) {
    try {
      // debugPrint('🔗 Initializing from deep link: $url');

      // إذا كان هذا سطراً برمجياً كاملاً (Command Line)، نحاول استخراج الرابط منه
      if (url.contains('etqanplayer://')) {
        final match = RegExp(r'(etqanplayer://[^\s"]+)').firstMatch(url);
        if (match != null) {
          url = match.group(0)!;
          // debugPrint('🔗 Extracted deep link from command line: $url');
        }
      } else if (url.contains('token=')) {
        // حالة قد لا تحتوي على البروتوكول ولكن تحتوي على token
        final match = RegExp(r'([^\s"]*token=[^\s"]+)').firstMatch(url);
        if (match != null) {
          url = match.group(0)!;
          // debugPrint('🔗 Extracted token link from command line: $url');
        }
      }

      // تنظيف URL - إزالة أي مسافات أو أحرف غير ضرورية
      url = url.trim();
      if (url.startsWith('"') && url.endsWith('"')) {
        url = url.substring(1, url.length - 1);
      }

      Uri uri;
      try {
        uri = Uri.parse(url);
      } catch (e) {
        debugPrint('❌ Error parsing URI: $e');
        // محاولة إصلاح URL يدوياً
        final fixedUrl = url.replaceAll(' ', '');
        uri = Uri.parse(fixedUrl);
        debugPrint('🔗 Retrying with fixed URL: $fixedUrl');
      }

      /*
      debugPrint(
        '🔗 URI scheme: ${uri.scheme}, host: ${uri.host}, path: ${uri.path}',
      );
      debugPrint('🔗 Query parameters: ${uri.queryParameters}');
      debugPrint('🔗 Full query string: ${uri.query}');
      debugPrint('🔗 Full URL: ${uri.toString()}');
      */

      // محاولة استخراج token من query parameters
      String? token = uri.queryParameters['token'];
      /*
      debugPrint(
        '🔗 Token from queryParameters: ${token != null ? "found (${token.length} chars)" : "not found"}',
      );
      */

      // إذا لم نجد token في queryParameters، نحاول استخراجه من query string مباشرة
      if (token == null || token.isEmpty) {
        final queryString = uri.query;
        // debugPrint('🔗 Query string: $queryString');

        if (queryString.contains('token=')) {
          // محاولة عدة أنماط
          final patterns = [
            RegExp(r'token=([^&]+)'),
            RegExp(r'token=([^&]*?)(?:&|$)'),
            RegExp(r'token=([^"]+)'),
            RegExp(r'token=(.+)'),
          ];

          for (final pattern in patterns) {
            final tokenMatch = pattern.firstMatch(queryString);
            if (tokenMatch != null && tokenMatch.groupCount > 0) {
              token = Uri.decodeComponent(tokenMatch.group(1)!);
              debugPrint(
                '🔗 Token extracted from query string using pattern: ${token.length} chars',
              );
              break;
            }
          }
        }

        // إذا لم نجد token في query، نحاول البحث في كامل URL
        if (token == null || token.isEmpty) {
          final fullUrl = url;
          if (fullUrl.contains('token=')) {
            final tokenMatch = RegExp(r'token=([^&"]+)').firstMatch(fullUrl);
            if (tokenMatch != null) {
              token = Uri.decodeComponent(tokenMatch.group(1)!);
              debugPrint(
                '🔗 Token extracted from full URL: ${token.length} chars',
              );
            }
          }
        }
      }

      if (token == null || token.isEmpty) {
        debugPrint('❌ Token is missing from deep link');
        _arguments = const VideoArguments(
          isValid: false,
          errorMessage: 'Token is missing from deep link',
        );
        return;
      }

      debugPrint(
        '✅ Token extracted: ${token.length > 20 ? '${token.substring(0, 20)}...' : token}',
      );

      // Token يحتوي على courseId و lessonId و userId
      // لكننا نحتاج فقط Token للوصول إلى stream endpoint
      // سنستخدم Token مباشرة بدون courseId و lessonId
      // محاولة استخراج apiBase من deep link إذا كان موجوداً
      String apiBase = 'http://31.97.154.182:65000/api'; // القيمة الافتراضية
      final apiBaseParam = uri.queryParameters['apiBase'];
      if (apiBaseParam != null && apiBaseParam.isNotEmpty) {
        apiBase = Uri.decodeComponent(apiBaseParam);
        debugPrint('🔗 API Base from deep link: $apiBase');
      }
      
      // استخراج بيانات السبلاش من deep link
      String? splashTitle;
      String? splashSubtitle;
      String? splashBgColor;
      String? logoColor;
      String? textColor;
      String? subtitleColor;
      
      final splashTitleParam = uri.queryParameters['splashTitle'];
      if (splashTitleParam != null && splashTitleParam.isNotEmpty) {
        splashTitle = Uri.decodeComponent(splashTitleParam);
        debugPrint('🔗 Splash Title from deep link: $splashTitle');
      }
      
      final splashSubtitleParam = uri.queryParameters['splashSubtitle'];
      if (splashSubtitleParam != null && splashSubtitleParam.isNotEmpty) {
        splashSubtitle = Uri.decodeComponent(splashSubtitleParam);
        debugPrint('🔗 Splash Subtitle from deep link: $splashSubtitle');
      }
      
      final splashBgColorParam = uri.queryParameters['splashBgColor'];
      if (splashBgColorParam != null && splashBgColorParam.isNotEmpty) {
        splashBgColor = Uri.decodeComponent(splashBgColorParam);
        debugPrint('🔗 Splash BgColor from deep link: $splashBgColor');
      }
      final logoColorParam = uri.queryParameters['logoColor'];
      if (logoColorParam != null && logoColorParam.isNotEmpty) {
        logoColor = Uri.decodeComponent(logoColorParam);
        debugPrint('🔗 Logo Color from deep link: $logoColor');
      }
      final textColorParam = uri.queryParameters['textColor'];
      if (textColorParam != null && textColorParam.isNotEmpty) {
        textColor = Uri.decodeComponent(textColorParam);
        debugPrint('🔗 Text Color from deep link: $textColor');
      }
      
      final subtitleColorParam = uri.queryParameters['subtitleColor'];
      if (subtitleColorParam != null && subtitleColorParam.isNotEmpty) {
        subtitleColor = Uri.decodeComponent(subtitleColorParam);
        debugPrint('🔗 Subtitle Color from deep link: $subtitleColor');
      }
      
      _arguments = VideoArguments(
        token: token,
        lessonId: null, // سيتم استخراجه من Token في Backend
        courseId: null, // سيتم استخراجه من Token في Backend
        apiBase: apiBase,
        isValid: true,
        splashTitle: splashTitle,
        splashSubtitle: splashSubtitle,
        splashBgColor: splashBgColor,
        logoColor: logoColor,
        textColor: textColor,
        subtitleColor: subtitleColor,
      );

      // debugPrint('📋 Initialized from deep link successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Error parsing deep link: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      _arguments = VideoArguments(
        isValid: false,
        errorMessage: 'Error parsing deep link: $e',
      );
    }
  }

  /// تهيئة للتطوير بدون arguments حقيقية
  void initializeDevelopment({
    String token = 'dev-token',
    int lessonId = 1,
    int courseId = 1,
    String apiBase = 'https://testapi.etqan-code.com/api/v1',
  }) {
    _arguments = VideoArguments.development(
      token: token,
      lessonId: lessonId,
      courseId: courseId,
      apiBase: apiBase,
    );
    debugPrint('📋 Development arguments: $_arguments');
  }

  /// الحصول على arguments المحللة
  VideoArguments? get arguments => _arguments;

  /// التحقق من صحة arguments
  bool get isValid {
    if (_arguments == null) return false;
    return _arguments!.isValid;
  }

  /// رسالة الخطأ إن وجدت
  String? get errorMessage => _arguments?.errorMessage;
}
