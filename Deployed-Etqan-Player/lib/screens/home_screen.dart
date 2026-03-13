import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/stream_data.dart';
import '../services/api_service.dart';
import '../services/app_arguments_service.dart';
import '../services/window_service.dart';
import 'player_screen.dart';

enum HomeStatus { waiting, loading, error, ready }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _uriSub;
  StreamSubscription<String>? _customSub;

  HomeStatus _status = HomeStatus.waiting;
  String _statusMessage = 'جاهز لاستقبال الفيديو من المنصة.';
  String? _error; // ✅ هنستخدمه للرسالة فقط (بدون تفاصيل داتا تانية)

  int _launchSeq = 0; // لمنع نتائج قديمة لو وصل links ورا بعض بسرعة

  @override
  void initState() {
    super.initState();
    _initDeepLinks();

    // لو الـ args اتجهزت في main() (CLI أو initial link) شغّل تلقائي
    Future.delayed(const Duration(milliseconds: 200), () {
      _tryAutoStartFromExistingArgs();
    });
  }

  void _initDeepLinks() {
    debugPrint('🔗 [Home] Initializing deep link listeners...');

    // app_links stream (موبايل + قد يعمل على desktop أحياناً)
    try {
      _uriSub = _appLinks.uriLinkStream.listen((uri) {
        final link = uri.toString();
        if (link.isEmpty) return;
        debugPrint('🔗 [Home] Deep link via uriLinkStream: $link');
        _handleDeepLink(link);
      }, onError: (e) {
        debugPrint('❌ [Home] uriLinkStream error: $e');
      });
    } catch (e) {
      debugPrint('⚠️ [Home] uriLinkStream not available: $e');
    }

    // custom stream (IPC/MethodChannel) اللي عندك في AppArgumentsService
    _customSub = AppArgumentsService.instance.onDeepLinkReceived.listen((link) {
      debugPrint('🔗 [Home] Deep link via custom stream: $link');
      _handleDeepLink(link);
    });

    // initial link (موبايل)
    _appLinks.getInitialLink().then((uri) {
      if (uri == null) return;
      final link = uri.toString();
      if (link.isEmpty) return;
      debugPrint('🔗 [Home] Initial deep link found: $link');
      _handleDeepLink(link);
    }).catchError((e) {
      debugPrint('⚠️ [Home] getInitialLink error: $e');
    });
  }

  Future<void> _tryAutoStartFromExistingArgs() async {
    final args = AppArgumentsService.instance.arguments;
    if (args == null || !args.isValid || args.token == null) {
      if (!mounted) return;
      setState(() {
        _status = HomeStatus.waiting;
        _error = null;
        _statusMessage = 'افتح الفيديو من المنصة وسيتم تشغيله تلقائياً هنا.';
      });
      return;
    }
    await _loadAndOpenPlayer();
  }

  void _handleDeepLink(String link) {
    setState(() {
      _error = null;
      _status = HomeStatus.loading;
      _statusMessage = 'تم استلام الطلب… جاري تجهيز الفيديو.';
    });

    // تهيئة args من الرابط
    AppArgumentsService.instance.initializeFromDeepLink(link);

    // حمل البيانات وافتح المشغل
    _loadAndOpenPlayer();
  }

  Future<void> _loadAndOpenPlayer() async {
    final seq = ++_launchSeq;

    try {
      final args = AppArgumentsService.instance.arguments;

      if (args == null || !args.isValid || args.token == null) {
        if (!mounted || seq != _launchSeq) return;
        setState(() {
          _status = HomeStatus.waiting;
          _error = null;
          _statusMessage = 'لا يوجد فيديو حالياً. افتحه من المنصة وسيظهر هنا.';
        });
        return;
      }

      if (!mounted || seq != _launchSeq) return;
      setState(() {
        _status = HomeStatus.loading;
        _error = null;
        _statusMessage = 'جاري تحميل بيانات الفيديو…';
      });

      final api = ApiService.instance;
      api.initialize(baseUrl: args.apiBase, token: args.token!);

      final streamData = await api.getStreamDataWithToken(args.token!);

      if (!mounted || seq != _launchSeq) return;

      if (streamData.success != true) {
        setState(() {
          _status = HomeStatus.error;
          _error = streamData.errorMessage ?? 'تعذر تحميل بيانات الفيديو.';
          _statusMessage = 'تعذر تشغيل الفيديو.';
        });
        return;
      }

      setState(() {
        _status = HomeStatus.ready;
        _error = null;
        _statusMessage = 'تم تجهيز الفيديو. جاري فتح المشغل…';
      });

      // لو Player مفتوح بالفعل ووصلك فيديو جديد—ارجع للـ Home ثم افتح Player من جديد
      Navigator.of(context).popUntil((r) => r.isFirst);

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            streamData: streamData,
            title: args.splashTitle,
            onExit: _exitApp,
          ),
        ),
      );
    } catch (_) {
      if (!mounted || seq != _launchSeq) return;
      setState(() {
        _status = HomeStatus.error;
        _error = 'حدث خطأ غير متوقع أثناء تحميل الفيديو.';
        _statusMessage = 'تعذر تشغيل الفيديو.';
      });
    }
  }

  /// ✅ زر/لينك التيست (بدون أي داتا إضافية على الصفحة)
  Future<void> _openTestVideo() async {
    // YouTube Test Video
    const videoId = 'Ub0tNnwlQb0';

    final testStream = StreamData.youtube(videoId, lessonTitle: 'فيديو تجريبي');

    Navigator.of(context).popUntil((r) => r.isFirst);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          streamData: testStream,
          title: 'فيديو تجريبي',
          onExit: _exitApp,
        ),
      ),
    );
  }

  void _copyDeepLinkTemplate() {
    const template = 'etqanplayer://play?token=YOUR_TOKEN_HERE';
    Clipboard.setData(const ClipboardData(text: template));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ Deep Link template')),
    );
  }

  void _exitApp() {
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      WindowService.instance.close();
    } else {
      SystemNavigator.pop();
    }
  }

  @override
  void dispose() {
    _uriSub?.cancel();
    _customSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('مشغل إتقان التعليمي'),
        actions: [
          // ✅ لينك/زر Test داخل الـ AppBar
          TextButton.icon(
            onPressed: _status == HomeStatus.loading ? null : _openTestVideo,
            icon: const Icon(Icons.play_circle_filled_rounded, size: 18),
            label: const Text('Test'),
          ),
          IconButton(
            tooltip: 'Copy Deep Link Template',
            onPressed: _copyDeepLinkTemplate,
            icon: const Icon(Icons.link_rounded),
          ),
          IconButton(
            tooltip: 'Exit',
            onPressed: _exitApp,
            icon: const Icon(Icons.exit_to_app_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusCard(
            status: _status,
            message: _statusMessage,
            error: _error,
          ),
          const SizedBox(height: 12),
          const _StepsCard(),
          const SizedBox(height: 12),

          // ✅ أزرار بسيطة بدون أي داتا تفنيه
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _status == HomeStatus.loading ? null : _openTestVideo,
                      icon: const Icon(Icons.play_circle_filled_rounded),
                      label: const Text('تشغيل فيديو Test'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _status == HomeStatus.loading ? null : _tryAutoStartFromExistingArgs,
                      icon: Icon(Icons.refresh_rounded, color: cs.onSurface.withValues(alpha: 0.8)),
                      label: const Text('إعادة المحاولة / فحص الرابط'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final HomeStatus status;
  final String message;
  final String? error;

  const _StatusCard({
    required this.status,
    required this.message,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Color chipColor;
    String chipText;

    switch (status) {
      case HomeStatus.waiting:
        chipColor = cs.secondary;
        chipText = 'WAITING';
        break;
      case HomeStatus.loading:
        chipColor = cs.primary;
        chipText = 'LOADING';
        break;
      case HomeStatus.error:
        chipColor = cs.error;
        chipText = 'ERROR';
        break;
      case HomeStatus.ready:
        chipColor = Colors.green;
        chipText = 'READY';
        break;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  label: Text(chipText, style: const TextStyle(fontWeight: FontWeight.bold)),
                  backgroundColor: chipColor.withValues(alpha: 0.2),
                  side: BorderSide(color: chipColor.withValues(alpha: 0.4)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontSize: 14,
                      color: cs.onSurface.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ),
            if (status == HomeStatus.loading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(minHeight: 3),
            ],
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error!,
                style: TextStyle(color: cs.error.withValues(alpha: 0.9)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepsCard extends StatelessWidget {
  const _StepsCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final steps = <String>[
      'سجّل دخولك على المنصة وافتح الكورس/الدرس.',
      'اضغط زر “تشغيل الفيديو” داخل المنصة.',
      'المنصة تبعت Deep Link للمشغل يحتوي Token آمن.',
      'المشغل يستقبل الطلب، يطلب بيانات التشغيل من الـ API، ثم يفتح صفحة التشغيل.',
      'لو حصل خطأ (Token منتهي/غير مصرح) هتظهر رسالة واضحة هنا.',
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'إزاي تشغيل الفيديو من المنصة؟',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(steps.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        steps[i],
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: cs.onSurface.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 6),
            Text(
              'ملاحظة: على Windows غالباً الـ deep link يوصل عبر command line أو IPC (MethodChannel) — وإحنا سامعين للاتنين.',
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.55),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}