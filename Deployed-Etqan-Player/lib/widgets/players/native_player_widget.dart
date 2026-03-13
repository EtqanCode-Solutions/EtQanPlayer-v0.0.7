import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:video_player/video_player.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' as media_kit_video;
import '../../services/window_service.dart';
import '../../services/progress_service.dart';
import '../../services/audio_control_service.dart';

/// مشغل الفيديو المحلي (HLS/MP4) يدعم جميع المنصات
class NativePlayerWidget extends StatefulWidget {
  final String videoUrl;
  final bool autoPlay;
  final VoidCallback? onReady;
  final VoidCallback? onEnded;
  final Function(String)? onError;
  
  // بيانات تتبع التقدم
  final int? lessonId;
  final int? studentId;
  final int? durationSec;

  const NativePlayerWidget({
    super.key,
    required this.videoUrl,
    this.autoPlay = true,
    this.onReady,
    this.onEnded,
    this.onError,
    this.lessonId,
    this.studentId,
    this.durationSec,
  });

  @override
  State<NativePlayerWidget> createState() => _NativePlayerWidgetState();
}

class _NativePlayerWidgetState extends State<NativePlayerWidget> {
  // للموبايل
  VideoPlayerController? _mobileController;

  // للديسكتوب
  Player? _desktopPlayer;
  media_kit_video.VideoController? _desktopController;

  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _showControls = true;
  bool _isFullScreen = false;
  Duration _currentPosition = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isBuffering = false;
  Timer? _hideControlsTimer;
  double _aspectRatio = 16 / 9;

  // Volume control
  double _volume = 1.0; // 0.0 to 1.0 for mobile, 0.0 to 100.0 for desktop
  bool _isMuted = false;
  double? _previousVolume;
  bool _showVolumeControl = false;
  double _playbackSpeed = 1.0;

  // متغيرات لإجبار إعادة بناء Video widget عند تغيير الحجم (Desktop فقط)
  final ValueNotifier<int> _rebuildVideo = ValueNotifier(0);
  Size? _lastSize;
  
  // تتبع التقدم
  int _savedPosition = 0;

  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

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
  
  /// تحميل الموقع المحفوظ
  Future<void> _loadSavedPosition() async {
    if (widget.lessonId != null && widget.studentId != null) {
      _savedPosition = await ProgressService.instance.getLastPosition(
        widget.lessonId!,
        widget.studentId!,
      );
      debugPrint('📊 [NativePlayer] Loaded saved position: $_savedPosition sec');
    }
  }

  Future<void> _initializePlayer() async {
    try {
      if (_isDesktop) {
        await _initializeDesktopPlayer();
      } else {
        await _initializeMobilePlayer();
      }
    } catch (e) {
      debugPrint('❌ Failed to initialize player: $e');
      widget.onError?.call('Failed to initialize video: $e');
    }
  }

  Future<void> _initializeMobilePlayer() async {
    _mobileController = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: false,
        allowBackgroundPlayback: false,
      ),
    );

    await _mobileController!.initialize();
    _mobileController!.addListener(_mobilePlayerListener);

    // تعيين مستوى الصوت الأولي (0.0 إلى 1.0 لـ video_player)
    await _mobileController!.setVolume(_volume);

    if (mounted) {
      setState(() {
        _isInitialized = true;
        _duration = _mobileController!.value.duration;
        _aspectRatio = _mobileController!.value.aspectRatio;
      });

      debugPrint('✅ Mobile player initialized');
      widget.onReady?.call();
      
      // استعادة الموقع المحفوظ
      if (_savedPosition > 0) {
        debugPrint('📊 [NativePlayer] Seeking to saved position: $_savedPosition sec');
        await _mobileController!.seekTo(Duration(seconds: _savedPosition));
      }
      
      // بدء تتبع التقدم
      _startProgressTracking();

      if (widget.autoPlay) {
        _mobileController!.play();
        // ⚠️ إصلاح: تحديث _isPlaying فوراً بعد play()
        // هذا يضمن أن الأيقونة تظهر بشكل صحيح عند autoPlay
        if (mounted) {
          setState(() {
            _isPlaying = true; // تحديث الحالة فوراً عند autoPlay
          });
        }
      }
      _startHideControlsTimer();
    }
  }

  Future<void> _initializeDesktopPlayer() async {
    _desktopPlayer = Player();
    _desktopController = media_kit_video.VideoController(_desktopPlayer!);

    // الاستماع للأحداث
    _desktopPlayer!.stream.playing.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });

    _desktopPlayer!.stream.position.listen((position) {
      if (mounted) {
        setState(() => _currentPosition = position);
        // تحديث التقدم للديسكتوب
        if (widget.lessonId != null && widget.studentId != null) {
          ProgressService.instance.updatePosition(position.inSeconds);
        }
      }
    });

    _desktopPlayer!.stream.duration.listen((duration) {
      if (mounted) setState(() => _duration = duration);
    });

    _desktopPlayer!.stream.buffering.listen((buffering) {
      if (mounted) setState(() => _isBuffering = buffering);
    });

    _desktopPlayer!.stream.completed.listen((completed) {
      if (completed) {
        debugPrint('✅ Video ended');
        widget.onEnded?.call();
      }
    });

    _desktopPlayer!.stream.error.listen((error) {
      // debugPrint('❌ Player error: $error');
      widget.onError?.call(error.toString());
    });

    // تشغيل الفيديو
    await _desktopPlayer!.open(Media(widget.videoUrl), play: widget.autoPlay);

    // تعيين مستوى الصوت الأولي (0.0 إلى 100.0 لـ media_kit)
    await _desktopPlayer!.setVolume(_volume * 100);

    if (mounted) {
      // ⚠️ إصلاح: تحديث _isPlaying بناءً على الحالة الفعلية للـ player
      // هذا يضمن أن الأيقونة تظهر بشكل صحيح عند autoPlay
      final currentPlaying = _desktopPlayer!.state.playing;
      setState(() {
        _isInitialized = true;
        _isPlaying = currentPlaying; // تحديث الحالة بناءً على الحالة الفعلية
      });
      // debugPrint('✅ Desktop player initialized, playing: $currentPlaying');
      widget.onReady?.call();
      
      // استعادة الموقع المحفوظ
      if (_savedPosition > 0) {
        // debugPrint('📊 [NativePlayer] Seeking to saved position: $_savedPosition sec');
        await _desktopPlayer!.seek(Duration(seconds: _savedPosition));
      }
      
      // بدء تتبع التقدم
      _startProgressTracking();
      
      _startHideControlsTimer();
    }
  }
  
  /// بدء تتبع التقدم
  void _startProgressTracking() {
    if (widget.lessonId != null && widget.studentId != null) {
      final duration = _duration.inSeconds;
      ProgressService.instance.startTracking(
        lessonId: widget.lessonId!,
        studentId: widget.studentId!,
        videoDurationSec: duration > 0 ? duration : (widget.durationSec ?? 0),
      );
    }
  }

  void _mobilePlayerListener() {
    if (!mounted || _mobileController == null) return;

    final value = _mobileController!.value;
    setState(() {
      _isPlaying = value.isPlaying;
      _currentPosition = value.position;
      _isBuffering = value.isBuffering;
    });
    
    // تحديث التقدم
    if (widget.lessonId != null && widget.studentId != null) {
      ProgressService.instance.updatePosition(value.position.inSeconds);
    }

    // التحقق من انتهاء الفيديو
    if (value.position >= value.duration && value.duration.inMilliseconds > 0) {
      widget.onEnded?.call();
    }

    // التحقق من الأخطاء
    if (value.hasError) {
      widget.onError?.call(value.errorDescription ?? 'Unknown error');
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  @override
  void dispose() {
    // إلغاء تسجيل callback الصوت
    AudioControlService().unregisterMuteCallback();
    // حفظ التقدم قبل الإغلاق
    ProgressService.instance.stopTracking();
    _hideControlsTimer?.cancel();
    _mobileController?.removeListener(_mobilePlayerListener);
    _mobileController?.dispose();
    _desktopPlayer?.dispose();
    // إعادة الاتجاهات الافتراضية
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  void _togglePlayPause() {
    if (_isDesktop) {
      _desktopPlayer?.playOrPause();
    } else {
      if (_isPlaying) {
        _mobileController?.pause();
      } else {
        _mobileController?.play();
      }
    }
    _startHideControlsTimer();
  }

  void _seekTo(Duration position) {
    if (_isDesktop) {
      _desktopPlayer?.seek(position);
    } else {
      _mobileController?.seekTo(position);
    }
    _startHideControlsTimer();
  }

  void _seekForward() {
    final newPosition = _currentPosition + const Duration(seconds: 10);
    _seekTo(newPosition > _duration ? _duration : newPosition);
  }

  void _seekBackward() {
    final newPosition = _currentPosition - const Duration(seconds: 10);
    _seekTo(newPosition < Duration.zero ? Duration.zero : newPosition);
  }

  Future<void> _toggleFullScreen() async {
    if (_isDesktop) {
      // للـ Desktop: استخدام WindowService لتغيير وضع النافذة فعلياً
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
          await SystemChrome.setEnabledSystemUIMode(
            SystemUiMode.immersiveSticky,
          );
        } else {
          await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        }
      } catch (e) {
        debugPrint('❌ Error toggling fullscreen: $e');
      }
    } else {
      // للـ Mobile: استخدام setState فقط
      setState(() => _isFullScreen = !_isFullScreen);

      if (_isFullScreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      }
    }
    _startHideControlsTimer();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _startHideControlsTimer();
    }
  }

  void _setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);

    if (_isDesktop) {
      // media_kit يستخدم 0.0 إلى 100.0
      await _desktopPlayer?.setVolume(_volume * 100);
    } else {
      // video_player يستخدم 0.0 إلى 1.0
      await _mobileController?.setVolume(_volume);
    }

    if (mounted) {
      setState(() {
        if (_volume > 0) {
          _isMuted = false;
        }
      });
    }
  }

  void _toggleMute() async {
    if (_isMuted) {
      // إلغاء كتم الصوت
      _volume = _previousVolume ?? 1.0;
      _isMuted = false;
    } else {
      // كتم الصوت
      _previousVolume = _volume;
      _volume = 0.0;
      _isMuted = true;
    }

    if (_isDesktop) {
      await _desktopPlayer?.setVolume(_volume * 100);
    } else {
      await _mobileController?.setVolume(_volume);
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed;
    if (_isDesktop) {
      await _desktopPlayer?.setRate(speed);
    } else {
      await _mobileController?.setPlaybackSpeed(speed);
    }
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
    if (!_isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'جاري تحميل الفيديو...',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _toggleControls,
      onDoubleTap: _toggleFullScreen,
      child: Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Video
            Center(
              child: _isDesktop
                  ? LayoutBuilder(
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
                                controller: _desktopController!,
                                controls: media_kit_video.NoVideoControls,
                                fill: Colors.black,
                              ),
                            );
                          },
                        );
                      },
                    )
                  : AspectRatio(
                      aspectRatio: _aspectRatio,
                      child: VideoPlayer(_mobileController!),
                    ),
            ),

            // Controls overlay
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Container(
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
                      // Top bar - فارغ للآن
                      const SizedBox(height: 48),

                      // Center controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Rewind 10s
                          IconButton(
                            onPressed: _seekBackward,
                            icon: const Icon(
                              Icons.replay_10_rounded,
                              size: 42,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 32),
                          // Play/Pause
                          IconButton(
                            onPressed: _togglePlayPause,
                            icon: Icon(
                              _isPlaying
                                  ? Icons.pause_circle_filled_rounded
                                  : Icons.play_circle_filled_rounded,
                              size: 72,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 32),
                          // Forward 10s
                          IconButton(
                            onPressed: _seekForward,
                            icon: const Icon(
                              Icons.forward_10_rounded,
                              size: 42,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),

                      // Bottom controls
                      Padding(
                        padding: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          bottom: MediaQuery.of(context).padding.bottom + 16,
                        ),
                        child: Column(
                          children: [
                            // Progress bar
                            SliderTheme(
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
                                value: _currentPosition.inMilliseconds
                                    .toDouble()
                                    .clamp(
                                      0,
                                      _duration.inMilliseconds.toDouble(),
                                    ),
                                min: 0,
                                max: _duration.inMilliseconds.toDouble().clamp(
                                  1,
                                  double.infinity,
                                ),
                                onChanged: (value) {
                                  _seekTo(
                                    Duration(milliseconds: value.toInt()),
                                  );
                                },
                              ),
                            ),

                            // Time and buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Time
                                Text(
                                  '${_formatDuration(_currentPosition)} / ${_formatDuration(_duration)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),

                                // Volume and Fullscreen buttons
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Volume control
                                    MouseRegion(
                                      onEnter: (_) {
                                        setState(
                                          () => _showVolumeControl = true,
                                        );
                                      },
                                      onExit: (_) {
                                        setState(
                                          () => _showVolumeControl = false,
                                        );
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Volume button
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
                                            tooltip: _isMuted
                                                ? 'إلغاء كتم الصوت'
                                                : 'كتم الصوت',
                                          ),
                                          // Volume slider (appears on hover)
                                          AnimatedContainer(
                                            width: _showVolumeControl ? 100 : 0,
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            curve: Curves.easeInOut,
                                            child: _showVolumeControl
                                                ? SliderTheme(
                                                    data: SliderTheme.of(context).copyWith(
                                                      activeTrackColor:
                                                          Colors.white,
                                                      inactiveTrackColor:
                                                          Colors.white30,
                                                      thumbColor: Colors.white,
                                                      thumbShape:
                                                          const RoundSliderThumbShape(
                                                            enabledThumbRadius:
                                                                6,
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
                                    // Fullscreen button
                                    if (!_isDesktop)
                                      IconButton(
                                        onPressed: _toggleFullScreen,
                                        icon: Icon(
                                          _isFullScreen
                                              ? Icons.fullscreen_exit_rounded
                                              : Icons.fullscreen_rounded,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                      ),
                                    
                                    // Speed control
                                    PopupMenuButton<double>(
                                      initialValue: _playbackSpeed,
                                      tooltip: 'سرعة التشغيل',
                                      onSelected: _setPlaybackSpeed,
                                      icon: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Buffering indicator
            if (_isBuffering)
              const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
