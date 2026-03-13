import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import '../models/stream_data.dart';
import 'players/youtube_player_widget.dart';
import 'players/desktop_youtube_player.dart';
import 'players/native_player_widget.dart';
import 'players/webview_player_widget.dart';

/// مشغل فيديو موحد يختار المشغل المناسب تلقائياً
class UniversalPlayer extends StatelessWidget {
  final StreamData streamData;
  final bool autoPlay;
  final VoidCallback? onReady;
  final VoidCallback? onEnded;
  final Function(String)? onError;

  const UniversalPlayer({
    super.key,
    required this.streamData,
    this.autoPlay = true,
    this.onReady,
    this.onEnded,
    this.onError,
  });

  @override
  Widget build(BuildContext context) {
    // التحقق من صحة البيانات
    if (!streamData.success) {
      return _buildErrorWidget(streamData.errorMessage ?? 'Unknown error');
    }

    // اختيار المشغل المناسب حسب نوع الفيديو
    switch (streamData.provider) {
      case VideoProvider.youtube:
        return _buildYouTubePlayer();

      case VideoProvider.vimeo:
      case VideoProvider.vdocipher:
        return _buildWebViewPlayer();

      case VideoProvider.hls:
      case VideoProvider.mp4:
        return _buildNativePlayer();

      case VideoProvider.unknown:
        // محاولة تحديد النوع من الـ URL
        if (streamData.streamUrl != null) {
          return _buildNativePlayer();
        }
        return _buildErrorWidget('نوع الفيديو غير معروف');
    }
  }

  Widget _buildYouTubePlayer() {
    final videoId = streamData.reconstructedVideoId;
    if (videoId == null || videoId.isEmpty) {
      return _buildErrorWidget('معرف فيديو YouTube غير صالح');
    }

    // على Desktop نستخدم media_kit مع youtube_explode_dart
    final bool isDesktop =
        !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    if (isDesktop) {
      return DesktopYouTubePlayer(
        videoId: videoId,
        autoPlay: autoPlay,
        onReady: onReady,
        onEnded: onEnded,
        onError: onError,
        // بيانات تتبع التقدم
        lessonId: streamData.lessonId,
        studentId: streamData.studentId,
        durationSec: streamData.durationSec,
      );
    }

    // على Mobile نستخدم youtube_player_flutter
    return YouTubePlayerWidget(
      videoId: videoId,
      autoPlay: autoPlay,
      onReady: onReady,
      onEnded: onEnded,
      onError: onError,
      // بيانات تتبع التقدم
      lessonId: streamData.lessonId,
      studentId: streamData.studentId,
      durationSec: streamData.durationSec,
    );
  }

  Widget _buildNativePlayer() {
    final url = streamData.streamUrl;
    if (url == null || url.isEmpty) {
      return _buildErrorWidget('رابط الفيديو غير صالح');
    }

    return NativePlayerWidget(
      videoUrl: url,
      autoPlay: autoPlay,
      onReady: onReady,
      onEnded: onEnded,
      onError: onError,
      // بيانات تتبع التقدم
      lessonId: streamData.lessonId,
      studentId: streamData.studentId,
      durationSec: streamData.durationSec,
    );
  }

  Widget _buildWebViewPlayer() {
    return WebViewPlayerWidget(
      streamData: streamData,
      onReady: onReady,
      onEnded: onEnded,
      onError: onError,
    );
  }

  Widget _buildErrorWidget(String message) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(
                'خطأ في تشغيل الفيديو',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  onError?.call(message);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget لعرض حالة التحميل
class PlayerLoadingWidget extends StatelessWidget {
  final String? message;

  const PlayerLoadingWidget({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
