import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// بيانات التقدم
class ProgressData {
  final int lessonId;
  final int? studentId;
  final int lastPositionSec;
  final int? maxWatchedSec;
  final int? durationSec;
  final bool fullyWatched;

  const ProgressData({
    required this.lessonId,
    this.studentId,
    required this.lastPositionSec,
    this.maxWatchedSec,
    this.durationSec,
    this.fullyWatched = false,
  });

  factory ProgressData.fromJson(Map<String, dynamic> json) {
    return ProgressData(
      lessonId: json['lessonId'] as int? ?? 0,
      studentId: json['studentId'] as int?,
      lastPositionSec: json['lastPositionSec'] as int? ?? 0,
      maxWatchedSec: json['maxWatchedSec'] as int?,
      durationSec: json['durationSecCached'] as int?,
      fullyWatched: json['fullyWatched'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'lessonId': lessonId,
    'studentId': studentId,
    'lastPositionSec': lastPositionSec,
    'maxWatchedSec': maxWatchedSec,
    'durationSec': durationSec,
    'fullyWatched': fullyWatched,
  };
}

/// خدمة تتبع تقدم المشاهدة
class ProgressService {
  static ProgressService? _instance;
  
  Timer? _progressTimer;
  int? _currentLessonId;
  int? _currentStudentId;
  int _currentPositionSec = 0;
  int _videoDurationSec = 0;
  bool _isActive = false;

  // مفتاح التخزين المحلي
  static const String _localProgressKey = 'video_progress_';

  ProgressService._();

  static ProgressService get instance {
    _instance ??= ProgressService._();
    return _instance!;
  }

  /// بدء تتبع التقدم لفيديو معين
  void startTracking({
    required int lessonId,
    required int studentId,
    required int videoDurationSec,
  }) {
    _currentLessonId = lessonId;
    _currentStudentId = studentId;
    _videoDurationSec = videoDurationSec;
    _isActive = true;

    // debugPrint('📊 [ProgressService] Started tracking [PRIVATE_LESSON] for [PRIVATE_STUDENT]');

    // بدء Timer لإرسال التقدم كل 10 ثوانٍ
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _sendProgressToBackend();
    });
  }

  /// تحديث الموقع الحالي
  void updatePosition(int positionSec) {
    _currentPositionSec = positionSec;
  }

  /// حفظ التقدم الحالي (يُستدعى عند الإيقاف المؤقت أو الإغلاق)
  Future<void> saveCurrentProgress() async {
    if (!_isActive || _currentLessonId == null) return;

    await _saveProgressLocally();
    await _sendProgressToBackend();
  }

  /// الحصول على آخر موقع مسجل للفيديو
  Future<int> getLastPosition(int lessonId, int studentId) async {
    // أولاً: محاولة جلب من الباك اند
    try {
      final backendPosition = await _getProgressFromBackend(lessonId, studentId);
      if (backendPosition > 0) {
        // debugPrint('📊 [ProgressService] Got position from backend: ${backendPosition}s');
        return backendPosition;
      }
    } catch (e) {
      // debugPrint('⚠️ [ProgressService] Failed to get progress from backend: $e');
    }

    // ثانياً: محاولة جلب من التخزين المحلي
    try {
      final localPosition = await _getLocalProgress(lessonId);
      if (localPosition > 0) {
        // debugPrint('📊 [ProgressService] Got position from local: ${localPosition}s');
        return localPosition;
      }
    } catch (e) {
      // debugPrint('⚠️ [ProgressService] Failed to get local progress: $e');
    }

    return 0;
  }

  /// إيقاف التتبع
  Future<void> stopTracking() async {
    if (_isActive) {
      await saveCurrentProgress();
    }
    
    _progressTimer?.cancel();
    _progressTimer = null;
    _isActive = false;
    _currentLessonId = null;
    _currentStudentId = null;
    _currentPositionSec = 0;
    _videoDurationSec = 0;

    // debugPrint('📊 [ProgressService] Stopped tracking');
  }

  /// حفظ التقدم محلياً
  Future<void> _saveProgressLocally() async {
    if (_currentLessonId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_localProgressKey$_currentLessonId';
      await prefs.setInt(key, _currentPositionSec);
      // debugPrint('💾 [ProgressService] Saved locally: $_currentPositionSec sec');
    } catch (e) {
      // debugPrint('❌ [ProgressService] Failed to save locally: $e');
    }
  }

  /// جلب التقدم المحلي
  Future<int> _getLocalProgress(int lessonId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_localProgressKey$lessonId';
      return prefs.getInt(key) ?? 0;
    } catch (e) {
      debugPrint('❌ [ProgressService] Failed to get local progress: $e');
      return 0;
    }
  }

  /// إرسال التقدم للباك اند
  Future<void> _sendProgressToBackend() async {
    if (_currentLessonId == null || _currentStudentId == null) return;
    if (_currentPositionSec <= 0) return;

    try {
      await ApiService.instance.updateProgress(
        lessonId: _currentLessonId!,
        studentId: _currentStudentId!,
        currentPositionSec: _currentPositionSec,
        videoDurationSec: _videoDurationSec,
      );
      // debugPrint('📤 [ProgressService] Sent to backend: $_currentPositionSec sec');
    } catch (e) {
      // debugPrint('❌ [ProgressService] Failed to send to backend: $e');
      // حفظ محلياً في حالة فشل الإرسال
      await _saveProgressLocally();
    }
  }

  /// جلب التقدم من الباك اند
  Future<int> _getProgressFromBackend(int lessonId, int studentId) async {
    try {
      final data = await ApiService.instance.getProgress(
        lessonId: lessonId,
        studentId: studentId,
      );
      if (data != null) {
        return data['lastPositionSec'] as int? ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('❌ [ProgressService] Failed to get from backend: $e');
      return 0;
    }
  }

  /// الحصول على الموقع الحالي
  int get currentPosition => _currentPositionSec;

  /// هل التتبع نشط؟
  bool get isActive => _isActive;

  /// تنظيف الموارد
  void dispose() {
    _progressTimer?.cancel();
    _progressTimer = null;
    _isActive = false;
  }
}
