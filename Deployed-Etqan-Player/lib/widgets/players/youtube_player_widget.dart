import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../services/progress_service.dart';
import '../../services/audio_control_service.dart';

/// مشغل YouTube آمن للهواتف (Android/iOS)
class YouTubePlayerWidget extends StatefulWidget {
  final String videoId;
  final bool autoPlay;
  final VoidCallback? onReady;
  final VoidCallback? onEnded;
  final Function(String)? onError;
  
  // بيانات تتبع التقدم
  final int? lessonId;
  final int? studentId;
  final int? durationSec;

  const YouTubePlayerWidget({
    super.key,
    required this.videoId,
    this.autoPlay = true,
    this.onReady,
    this.onEnded,
    this.onError,
    this.lessonId,
    this.studentId,
    this.durationSec,
  });

  @override
  State<YouTubePlayerWidget> createState() => _YouTubePlayerWidgetState();
}

class _YouTubePlayerWidgetState extends State<YouTubePlayerWidget> {
  late YoutubePlayerController _controller;
  bool _isPlayerReady = false;
  
  // تتبع التقدم
  Timer? _positionTimer;
  int _savedPosition = 0;

  @override
  void initState() {
    super.initState();
    _loadSavedPosition();
    _initializePlayer();
    _registerAudioControl();
  }

  /// تسجيل callback للتحكم في الصوت
  void _registerAudioControl() {
    AudioControlService().registerMuteCallback((shouldMute) {
      if (shouldMute) {
        // كتم الصوت
        _controller.setVolume(0);
      } else {
        // إلغاء كتم الصوت (استعادة مستوى الصوت الافتراضي)
        _controller.setVolume(100);
      }
    });
  }
  
  /// تحميل الموقع المحفوظ
  Future<void> _loadSavedPosition() async {
    if (widget.lessonId != null && widget.studentId != null) {
      _savedPosition = await ProgressService.instance.getLastPosition(
        widget.lessonId!,
        widget.studentId!,
      );
      // debugPrint('📊 [YouTubePlayer] Loaded saved position: $_savedPosition sec');
    }
  }

  void _initializePlayer() {
    // تنظيف video ID (إزالة أي أحرف إضافية)
    final cleanVideoId = _cleanVideoId(widget.videoId);

    if (cleanVideoId.isEmpty) {
      widget.onError?.call('Invalid YouTube video ID');
      return;
    }

    // debugPrint('🎬 Initializing YouTube Player with video ID: $cleanVideoId');

    _controller = YoutubePlayerController(
      initialVideoId: cleanVideoId,
      flags: YoutubePlayerFlags(
        autoPlay: widget.autoPlay,
        mute: false,
        enableCaption: true,
        hideControls: false,
        controlsVisibleAtStart: true,
        forceHD: false, // تعطيل forceHD لتجنب خطأ 153
        disableDragSeek: false,
        loop: false,
        showLiveFullscreenButton: true,
        useHybridComposition: true, // لتحسين الأداء على Android
      ),
    )..addListener(_playerListener);
  }

  /// تنظيف video ID من أي أحرف غير صالحة
  String _cleanVideoId(String videoId) {
    // إزالة المسافات والأحرف غير المرغوبة
    String cleaned = videoId.trim();

    // إذا كان رابط كامل، استخرج ID
    if (cleaned.contains('youtube.com/watch?v=')) {
      final uri = Uri.tryParse(cleaned);
      if (uri != null) {
        cleaned = uri.queryParameters['v'] ?? cleaned;
      }
    } else if (cleaned.contains('youtu.be/')) {
      final uri = Uri.tryParse(cleaned);
      if (uri != null) {
        cleaned = uri.pathSegments.last;
      }
    }

    // إزالة أي معاملات إضافية
    if (cleaned.contains('&')) {
      cleaned = cleaned.split('&').first;
    }
    if (cleaned.contains('?')) {
      cleaned = cleaned.split('?').first;
    }

    return cleaned;
  }

  void _playerListener() {
    if (!mounted) return;

    // التحقق من الأخطاء
    if (_controller.value.hasError) {
      final errorCode = _controller.value.errorCode;
      final errorMessage =
          'YouTube Error $errorCode: ${_getErrorMessage(errorCode)}';
      // debugPrint('❌ YouTube Player Error: $errorMessage');
      widget.onError?.call(errorMessage);
      return;
    }

    if (_isPlayerReady) {
      final playerState = _controller.value.playerState;
      if (playerState == PlayerState.ended) {
        widget.onEnded?.call();
      }
    }
  }

  String _getErrorMessage(int errorCode) {
    switch (errorCode) {
      case 2:
        return 'Invalid video ID';
      case 5:
        return 'HTML5 player error';
      case 100:
        return 'Video not found or unavailable';
      case 101:
        return 'Video not allowed to be played in embedded players';
      case 150:
        return 'Video not allowed to be played in embedded players';
      case 153:
        return 'Video format not available or network error';
      default:
        return 'Unknown error (Code: $errorCode)';
    }
  }

  @override
  void dispose() {
    // إلغاء تسجيل callback الصوت
    AudioControlService().unregisterMuteCallback();
    // حفظ التقدم قبل الإغلاق
    ProgressService.instance.stopTracking();
    _positionTimer?.cancel();
    _controller.removeListener(_playerListener);
    _controller.dispose();
    // إعادة الاتجاهات الافتراضية
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  void didUpdateWidget(YouTubePlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      final cleanVideoId = _cleanVideoId(widget.videoId);
      if (cleanVideoId.isNotEmpty) {
        _controller.load(cleanVideoId);
      } else {
        widget.onError?.call('Invalid YouTube video ID');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerBuilder(
      onEnterFullScreen: () {
        // تفعيل وضع ملء الشاشة
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        // debugPrint('🖥️ Entered fullscreen mode');
      },
      onExitFullScreen: () {
        // الخروج من وضع ملء الشاشة
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        SystemChrome.setPreferredOrientations(DeviceOrientation.values);
        // debugPrint('🖥️ Exited fullscreen mode');
      },
      player: YoutubePlayer(
        controller: _controller,
        showVideoProgressIndicator: true,
        progressIndicatorColor: Colors.red,
        progressColors: const ProgressBarColors(
          playedColor: Colors.red,
          handleColor: Colors.redAccent,
          bufferedColor: Colors.white38,
          backgroundColor: Colors.white24,
        ),
        onReady: () {
          _isPlayerReady = true;
          // debugPrint('✅ YouTube Player Ready');
          
          // استعادة الموقع المحفوظ
          if (_savedPosition > 0) {
            // debugPrint('📊 [YouTubePlayer] Seeking to saved position: $_savedPosition sec');
            _controller.seekTo(Duration(seconds: _savedPosition));
          }
          
          // بدء تتبع التقدم
          if (widget.lessonId != null && widget.studentId != null) {
            final duration = _controller.metadata.duration.inSeconds;
            ProgressService.instance.startTracking(
              lessonId: widget.lessonId!,
              studentId: widget.studentId!,
              videoDurationSec: duration > 0 ? duration : (widget.durationSec ?? 0),
            );
            
            // Timer لتحديث الموقع كل ثانية
            _positionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
              if (_isPlayerReady && mounted) {
                ProgressService.instance.updatePosition(
                  _controller.value.position.inSeconds,
                );
              }
            });
          }
          
          widget.onReady?.call();
        },
        onEnded: (metaData) {
          // debugPrint('✅ Video ended');
          widget.onEnded?.call();
        },
        topActions: [
          const SizedBox(width: 8.0),
          Expanded(
            child: Text(
              _controller.metadata.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16.0,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
        bottomActions: [
          CurrentPosition(),
          const SizedBox(width: 8.0),
          ProgressBar(
            isExpanded: true,
            colors: const ProgressBarColors(
              playedColor: Colors.red,
              handleColor: Colors.redAccent,
              bufferedColor: Colors.white38,
              backgroundColor: Colors.white24,
            ),
          ),
          const SizedBox(width: 8.0),
          RemainingDuration(),
          const SizedBox(width: 8.0),
          PlaybackSpeedButton(),
          const SizedBox(width: 4.0),
          FullScreenButton(),
        ],
      ),
      builder: (context, player) {
        // في وضع ملء الشاشة، المشغل يأخذ كامل المساحة
        return Container(
          color: Colors.black,
          child: Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: player,
            ),
          ),
        );
      },
    );
  }
}
