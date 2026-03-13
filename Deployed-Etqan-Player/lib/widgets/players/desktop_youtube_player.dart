import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' as media_kit_video;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../services/window_service.dart';
import '../../services/progress_service.dart';
import '../../services/audio_control_service.dart';

/// مشغل YouTube احترافي لـ Desktop
/// الحل النهائي لمشكلة تجمد الصورة عند تغيير حجم النافذة عن طريق LayoutBuilder + notifyListeners
class DesktopYouTubePlayer extends StatefulWidget {
  final String videoId;
  final bool autoPlay;
  final VoidCallback? onReady;
  final VoidCallback? onEnded;
  final Function(String)? onError;
  
  // بيانات تتبع التقدم
  final int? lessonId;
  final int? studentId;
  final int? durationSec;

  const DesktopYouTubePlayer({
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
  State<DesktopYouTubePlayer> createState() => _DesktopYouTubePlayerState();
}

class _DesktopYouTubePlayerState extends State<DesktopYouTubePlayer> {
  late final Player _player;
  late final media_kit_video.VideoController _videoController;
  final YoutubeExplode _yt = YoutubeExplode();

  bool _isLoading = true;
  bool _isInitialized = false;
  String? _errorMessage;
  String? _videoTitle;

  bool _showControls = true;
  bool _isFullScreen = false;
  Timer? _hideControlsTimer;
  final FocusNode _focusNode = FocusNode();

  // Volume control
  double _volume = 1.0;
  bool _isMuted = false;
  double? _previousVolume;
  double _playbackSpeed = 1.0;
  bool _showVolumeControl = false;

  // متغيرات لإجبار إعادة بناء Video widget عند تغيير الحجم
  final ValueNotifier<int> _rebuildVideo = ValueNotifier(0);
  Size? _lastSize;
  
  // تتبع التقدم
  StreamSubscription<Duration>? _positionSubscription;
  int _savedPosition = 0;

  String get _cleanVideoId {
    String id = widget.videoId.trim();

    if (id.contains('youtube.com/watch?v=')) {
      final uri = Uri.tryParse(id);
      if (uri != null) {
        id = uri.queryParameters['v'] ?? id;
      }
    } else if (id.contains('youtu.be/')) {
      final uri = Uri.tryParse(id);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        id = uri.pathSegments.last;
      }
    }

    if (id.contains('&')) id = id.split('&').first;
    if (id.contains('?')) id = id.split('?').first;

    return id;
  }

  @override
  void initState() {
    super.initState();
    _initPlayer();
    _loadSavedPosition();
    _registerAudioControl();
  }

  /// تسجيل callback للتحكم في الصوت
  void _registerAudioControl() {
    AudioControlService().registerMuteCallback((shouldMute) {
      if (shouldMute) {
        // حفظ مستوى الصوت الحالي
        _previousVolume = _volume;
        // كتم الصوت
        _setVolume(0.0);
        _isMuted = true;
      } else {
        // إلغاء كتم الصوت واستعادة المستوى السابق
        if (_previousVolume != null) {
          _volume = _previousVolume!;
          _previousVolume = null;
        }
        _setVolume(_volume);
        _isMuted = false;
      }
    });
  }
  
  /// تحميل الموقع المحفوظ من الباك اند أو التخزين المحلي
  Future<void> _loadSavedPosition() async {
    if (widget.lessonId != null && widget.studentId != null) {
      _savedPosition = await ProgressService.instance.getLastPosition(
        widget.lessonId!,
        widget.studentId!,
      );
      // debugPrint('📊 [DesktopPlayer] Loaded saved position: $_savedPosition sec');
    }
  }

  Future<void> _initPlayer() async {
    try {
//       debugPrint(
//         '🎬 Desktop YouTube Player initializing with ID: $_cleanVideoId',
//       );

      _player = Player();
      _videoController = media_kit_video.VideoController(_player);

      _player.stream.completed.listen((completed) {
        if (completed && mounted) {
          // debugPrint('✅ Video ended');
          widget.onEnded?.call();
        }
      });

      _player.stream.error.listen((error) {
        // debugPrint('❌ Player error: $error');
        if (mounted) widget.onError?.call(error.toString());
      });
      
      // الاستماع لتغييرات موقع التشغيل وتحديث التقدم
      _positionSubscription = _player.stream.position.listen((position) {
        if (mounted && widget.lessonId != null && widget.studentId != null) {
          ProgressService.instance.updatePosition(position.inSeconds);
        }
      });

      await _loadYouTubeVideo();
    } catch (e) {
      debugPrint('❌ Failed to initialize player: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'فشل في تهيئة المشغل: $e';
          _isLoading = false;
        });
        widget.onError?.call('Player initialization failed: $e');
      }
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _player.state.playing) {
        setState(() => _showControls = false);
      }
    });
  }

  Future<void> _loadYouTubeVideo() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

//       debugPrint('🔍 Fetching video info for: $_cleanVideoId');

      final video = await _yt.videos.get(_cleanVideoId);
      _videoTitle = video.title;

      final manifest = await _yt.videos.streamsClient.getManifest(
        _cleanVideoId,
      );
      StreamInfo? selectedStream;

      if (manifest.muxed.isNotEmpty) {
        selectedStream = manifest.muxed.withHighestBitrate();
      }

      if (selectedStream == null) {
        throw Exception('لا توجد بثوث متاحة');
      }

      final streamUrl = selectedStream.url.toString();
      await _player.open(Media(streamUrl), play: widget.autoPlay);
      await _player.setVolume(_volume * 100);

      if (mounted) {
        // ⚠️ إصلاح: التحقق من الحالة الفعلية للـ player بعد open()
        // هذا يضمن أن الحالة متزامنة مع الواقع
        final currentPlaying = _player.state.playing;
        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });
        // debugPrint('✅ Desktop YouTube Player Ready, playing: $currentPlaying');
        
        // استعادة الموقع المحفوظ
        if (_savedPosition > 0) {
          // debugPrint('📊 [DesktopPlayer] Seeking to saved position: $_savedPosition sec');
          await _player.seek(Duration(seconds: _savedPosition));
        }
        
        // بدء تتبع التقدم
        if (widget.lessonId != null && widget.studentId != null) {
          final duration = _player.state.duration.inSeconds;
          ProgressService.instance.startTracking(
            lessonId: widget.lessonId!,
            studentId: widget.studentId!,
            videoDurationSec: duration > 0 ? duration : (widget.durationSec ?? 0),
          );
        }
        
        widget.onReady?.call();
        _startHideControlsTimer();
      }
    } catch (e) {
      debugPrint('❌ Failed to load YouTube video: $e');
      if (mounted) {
        setState(() {
          _errorMessage = _getErrorMessage(e);
          _isLoading = false;
        });
        widget.onError?.call('Failed to load video: $e');
      }
    }
  }

  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('video unavailable')) return 'الفيديو غير متاح';
    if (errorStr.contains('private')) return 'فيديو خاص';
    if (errorStr.contains('network')) return 'خطأ في الاتصال';
    return 'فشل التحميل';
  }

  @override
  void dispose() {
    // إلغاء تسجيل callback الصوت
    AudioControlService().unregisterMuteCallback();
    // حفظ التقدم قبل الإغلاق
    ProgressService.instance.stopTracking();
    _positionSubscription?.cancel();
    _hideControlsTimer?.cancel();
    _focusNode.dispose();
    _rebuildVideo.dispose();
    _exitFullScreen();
    _player.dispose();
    _yt.close();
    super.dispose();
  }

  @override
  void didUpdateWidget(DesktopYouTubePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      _loadYouTubeVideo();
    }
  }

  void _togglePlayPause() {
    _player.playOrPause();
    _startHideControlsTimer();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.escape:
        if (_isFullScreen) _exitFullScreen();
        break;
      case LogicalKeyboardKey.space:
        _togglePlayPause();
        break;
      case LogicalKeyboardKey.keyF:
        _toggleFullScreen();
        break;
      case LogicalKeyboardKey.arrowLeft:
        _seekTo(_player.state.position - const Duration(seconds: 10));
        break;
      case LogicalKeyboardKey.arrowRight:
        _seekTo(_player.state.position + const Duration(seconds: 10));
        break;
      default:
        break;
    }
    _startHideControlsTimer();
  }

  void _seekTo(Duration position) {
    final duration = _player.state.duration;
    final clampedPosition = position < Duration.zero
        ? Duration.zero
        : (position > duration ? duration : position);
    _player.seek(clampedPosition);
    _startHideControlsTimer();
  }

  Future<void> _toggleFullScreen() async {
    try {
      await WindowService.instance.toggleFullScreen();
      final isFs = await WindowService.instance.isFullScreen();

      if (mounted) {
        setState(() => _isFullScreen = isFs);

        // إجبار إعادة بناء Video widget بعد تغيير fullscreen
        // هذا ضروري لأن media_kit يحتاج إلى إعادة بناء texture
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          _rebuildVideo.value++;
          // إعادة تعيين _lastSize لإجبار إعادة البناء
          _lastSize = null;
        }
      }

      if (isFs) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
      _startHideControlsTimer();
    } catch (e) {
      // debugPrint('❌ Error toggling fullscreen: $e');
    }
  }

  Future<void> _exitFullScreen() async {
    if (_isFullScreen) {
      await WindowService.instance.setFullScreen(false);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      if (mounted) setState(() => _isFullScreen = false);
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideControlsTimer();
  }

  void _setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _player.setVolume(_volume * 100);
    if (mounted) {
      setState(() {
        if (_volume > 0) _isMuted = false;
      });
    }
  }

  void _toggleMute() async {
    if (_isMuted) {
      _volume = _previousVolume ?? 1.0;
      _isMuted = false;
    } else {
      _previousVolume = _volume;
      _volume = 0.0;
      _isMuted = true;
    }
    await _player.setVolume(_volume * 100);
    if (mounted) setState(() {});
  }
  
  void _setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed;
    await _player.setRate(speed);
    if (mounted) setState(() {});
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) return _buildErrorWidget();
    if (_isLoading || !_isInitialized) return _buildLoadingWidget();

    return KeyboardListener(
      focusNode: _focusNode..requestFocus(),
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: MouseRegion(
        onEnter: (_) {
          setState(() => _showControls = true);
          _startHideControlsTimer();
        },
        onHover: (_) {
          if (!_showControls) {
            setState(() => _showControls = true);
          }
          _startHideControlsTimer();
        },
        child: GestureDetector(
          onTap: _toggleControls,
          onDoubleTap: _toggleFullScreen,
          child: Container(
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // الفيديو مع الحل الجذري لتجميد الصورة
                LayoutBuilder(
                  builder: (context, constraints) {
                    final size = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );

                    if (_lastSize == null || _lastSize != size) {
                      _lastSize = size;

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          // إجبار إعادة بناء Video widget فقط بدون تدمير Player
                          _rebuildVideo.value++;
                        }
                      });
                    }

                    return ValueListenableBuilder<int>(
                      valueListenable: _rebuildVideo,
                      builder: (_, value, child) {
                        return SizedBox.expand(
                          child: media_kit_video.Video(
                            controller: _videoController,
                            controls: media_kit_video.NoVideoControls,
                            fill: Colors.black,
                          ),
                        );
                      },
                    );
                  },
                ),

                // عناصر التحكم
                AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: _buildCustomControls(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomControls() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.7),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.7),
          ],
          stops: const [0.0, 0.25, 0.75, 1.0],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // العنوان
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _videoTitle ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // أزرار المنتصف
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 42,
                icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
                onPressed: () => _seekTo(
                  _player.state.position - const Duration(seconds: 10),
                ),
              ),
              const SizedBox(width: 32),
              StreamBuilder<bool>(
                stream: _player.stream.playing,
                builder: (context, snapshot) {
                  // ⚠️ إصلاح: استخدام _player.state.playing كقيمة افتراضية
                  // هذا يضمن أن الأيقونة تظهر بشكل صحيح عند autoPlay
                  final bool isPlaying = snapshot.data ?? _player.state.playing;
                  return IconButton(
                    iconSize: 72,
                    icon: Icon(
                      isPlaying
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_filled_rounded,
                      color: Colors.white,
                    ),
                    onPressed: _togglePlayPause,
                  );
                },
              ),
              const SizedBox(width: 32),
              IconButton(
                iconSize: 42,
                icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
                onPressed: () => _seekTo(
                  _player.state.position + const Duration(seconds: 10),
                ),
              ),
            ],
          ),

          // شريط التحكم السفلي
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                StreamBuilder(
                  stream: _player.stream.position,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final duration = _player.state.duration;
                    return SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Colors.red,
                        inactiveTrackColor: Colors.white30,
                        thumbColor: Colors.red,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 14,
                        ),
                        trackHeight: 3,
                      ),
                      child: Slider(
                        value: position.inMilliseconds.toDouble().clamp(
                          0,
                          duration.inMilliseconds.toDouble().clamp(
                            1,
                            double.maxFinite,
                          ),
                        ),
                        min: 0,
                        max: duration.inMilliseconds.toDouble().clamp(
                          1,
                          double.maxFinite,
                        ),
                        onChanged: (value) {
                          _seekTo(Duration(milliseconds: value.toInt()));
                        },
                      ),
                    );
                  },
                ),

                StreamBuilder(
                  stream: _player.stream.position,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final duration = _player.state.duration;

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_formatDuration(position)} / ${_formatDuration(duration)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            MouseRegion(
                              onEnter: (_) =>
                                  setState(() => _showVolumeControl = true),
                              onExit: (_) =>
                                  setState(() => _showVolumeControl = false),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: _toggleMute,
                                    icon: Icon(
                                      _isMuted || _volume == 0
                                          ? Icons.volume_off_rounded
                                          : _volume < 0.5
                                          ? Icons.volume_down_rounded
                                          : Icons.volume_up_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    tooltip: _isMuted ? 'إلغاء كتم' : 'كتم',
                                  ),
                                  AnimatedContainer(
                                    width: _showVolumeControl ? 100 : 0,
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeInOut,
                                    child: _showVolumeControl
                                        ? SliderTheme(
                                            data: SliderTheme.of(context).copyWith(
                                              activeTrackColor: Colors.white,
                                              inactiveTrackColor:
                                                  Colors.white30,
                                              thumbColor: Colors.white,
                                              thumbShape:
                                                  const RoundSliderThumbShape(
                                                    enabledThumbRadius: 6,
                                                  ),
                                              overlayShape:
                                                  const RoundSliderOverlayShape(
                                                    overlayRadius: 12,
                                                  ),
                                              trackHeight: 2,
                                            ),
                                            child: Slider(
                                              value: _volume,
                                              min: 0.0,
                                              max: 1.0,
                                              onChanged: _setVolume,
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Speed control
                            PopupMenuButton<double>(
                              initialValue: _playbackSpeed,
                              tooltip: 'سرعة التشغيل',
                              onSelected: _setPlaybackSpeed,
                              icon: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white70, width: 1.5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${_playbackSpeed}x',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              itemBuilder: (context) => [
                                0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0
                              ].map((speed) => PopupMenuItem(
                                value: speed,
                                child: Text('${speed}x'),
                              )).toList(),
                            ),

                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
            ),
            const SizedBox(height: 16),
            Text(
              _videoTitle != null
                  ? 'جاري تحميل: $_videoTitle'
                  : 'جاري تحميل الفيديو...',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage ?? 'حدث خطأ',
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadYouTubeVideo,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
