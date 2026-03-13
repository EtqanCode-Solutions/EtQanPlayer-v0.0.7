import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/stream_data.dart';

/// خدمة الاتصال بـ Backend API
class ApiService {
  static ApiService? _instance;
  late Dio _dio;
  String? _token;
  String _baseUrl = 'http://31.97.154.182:65000/api';

  ApiService._() {
    _dio = Dio();
    _setupInterceptors();
  }

  static ApiService get instance {
    _instance ??= ApiService._();
    return _instance!;
  }

  /// تهيئة الخدمة
  void initialize({required String baseUrl, required String token}) {
    _baseUrl = baseUrl;
    _token = token;
    // debugPrint('🌐 API Service initialized: $_baseUrl');
  }

  /// إعداد Interceptors
  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // إضافة Token للطلبات
          if (_token != null) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          options.headers['Content-Type'] = 'application/json';

          // 🛡️ SECURITY HEADERS (Mandatory for Protocol 2+)
          options.headers['x-app-version'] = '7'; // Current Build Version
          options.headers['x-player-protocol'] = '2'; // Current Playback Protocol
          
          // Determine Platform
          String platformStr = 'unknown';
          if (kIsWeb) {
            platformStr = 'web';
          } else {
            switch (defaultTargetPlatform) {
              case TargetPlatform.android:
                platformStr = 'android';
                break;
              case TargetPlatform.iOS:
                platformStr = 'ios';
                break;
              case TargetPlatform.windows:
                platformStr = 'windows';
                break;
              case TargetPlatform.macOS:
                platformStr = 'macos';
                break;
              case TargetPlatform.linux:
                platformStr = 'linux';
                break;
              default:
                platformStr = 'unknown';
            }
          }
          options.headers['x-platform'] = platformStr;

          debugPrint('📤 Request: ${options.method} [SENSITIVE_URI]'); // Redacted for security
          debugPrint('📤 Headers: x-app-version: 7, x-platform: $platformStr, x-player-protocol: 2');
          
          return handler.next(options);
        },
        onResponse: (response, handler) {
          debugPrint(
            '📥 Response: ${response.statusCode} [SENSITIVE_URI]', // Redacted for security
          );
          return handler.next(response);
        },
        onError: (error, handler) {
          // debugPrint('❌ API Error: ${error.message}');
          return handler.next(error);
        },
      ),
    );
  }

  /// الحصول على بيانات تشغيل الفيديو باستخدام Token
  Future<StreamData> getStreamDataWithToken(String token) async {
    try {
      debugPrint('📤 [ApiService] Requesting stream data...');
      // debugPrint('📤 [ApiService] URL: $_baseUrl/playback/stream/$token');

      final response = await _dio.get('$_baseUrl/playback/stream/$token');

      debugPrint('📥 [ApiService] Response status: ${response.statusCode}');
      debugPrint(
        '📥 [ApiService] Response data type: ${response.data.runtimeType}',
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        debugPrint('📥 [ApiService] Response data keys: ${data.keys.toList()}');
        debugPrint(
          '📥 [ApiService] success: ${data['success']}, has data: ${data.containsKey('data')}',
        );

        if (data['success'] == true && data['data'] != null) {
          final streamDataJson = data['data'] as Map<String, dynamic>;
          /*
          debugPrint(
            '📥 [ApiService] Stream data: streamType=${streamDataJson['streamType']}, provider=${streamDataJson['provider']}',
          );
          debugPrint('📥 [ApiService] Stream data keys: ${streamDataJson.keys.toList()}');
          debugPrint('📥 [ApiService] Has streamUrl: ${streamDataJson.containsKey('streamUrl')}, value: ${streamDataJson['streamUrl'] != null}');
          */
          if (streamDataJson['streamUrl'] != null) {
            final url = streamDataJson['streamUrl'] as String;
            // final preview = url.length > 50 ? '${url.substring(0, 50)}...' : url;
            // debugPrint('📥 [ApiService] streamUrl preview: $preview');
          }
          final result = StreamData.fromJson(streamDataJson);
          // debugPrint('📥 [ApiService] Parsed StreamData: success=${result.success}, streamType=${result.streamType}, provider=${result.provider}, hasStreamUrl=${result.streamUrl != null}');
          return result;
        } else {
          final errorMsg = data['message'] ?? 'Invalid response from server';
          debugPrint('❌ [ApiService] Invalid response: $errorMsg');
          return StreamData.error(errorMsg);
        }
      } else {
        debugPrint('❌ [ApiService] Invalid status code or null data');
        return StreamData.error('Invalid response from server');
      }
    } on DioException catch (e) {
      debugPrint('❌ [ApiService] DioException: ${e.type}');
      debugPrint('❌ [ApiService] Error message: ${e.message}');
      String errorMessage = 'Network error';

      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        final data = e.response!.data;

        debugPrint('❌ [ApiService] Response status: $statusCode');
        debugPrint('❌ [ApiService] Response data: $data');

        if (statusCode == 401) {
          final message = data is Map ? data['message'] : null;
          errorMessage = message ?? 'Token غير صالح أو منتهي الصلاحية';
        } else if (statusCode == 403) {
          final message = data is Map ? data['message'] : null;
          errorMessage = message ?? 'لا تملك صلاحية الوصول لهذا المحتوى';
        } else if (statusCode == 404) {
          errorMessage = 'الفيديو غير موجود';
        } else {
          final message = data is Map ? data['message'] : null;
          errorMessage = message ?? 'خطأ في الخادم ($statusCode)';
        }
      } else if (e.type == DioExceptionType.connectionTimeout) {
        errorMessage = 'انتهت مهلة الاتصال';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = 'فشل الاتصال بالخادم';
      }

      debugPrint('❌ [ApiService] Stream data error: $errorMessage');
      return StreamData.error(errorMessage);
    } catch (e, stackTrace) {
      debugPrint('❌ [ApiService] Unexpected error: $e');
      debugPrint('❌ [ApiService] Stack trace: $stackTrace');
      return StreamData.error('حدث خطأ غير متوقع: ${e.toString()}');
    }
  }

  /// الحصول على بيانات تشغيل الفيديو (الطريقة القديمة - للتوافق)
  Future<StreamData> getStreamData({
    required int courseId,
    required int lessonId,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/courses/$courseId/lessons/$lessonId/stream',
      );

      if (response.statusCode == 200 && response.data != null) {
        return StreamData.fromJson(response.data as Map<String, dynamic>);
      } else {
        return StreamData.error('Invalid response from server');
      }
    } on DioException catch (e) {
      String errorMessage = 'Network error';

      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        final data = e.response!.data;

        if (statusCode == 401) {
          errorMessage = 'غير مصرح - يرجى تسجيل الدخول مرة أخرى';
        } else if (statusCode == 403) {
          final message = data is Map ? data['message'] : null;
          errorMessage = message ?? 'لا تملك صلاحية الوصول لهذا المحتوى';
        } else if (statusCode == 404) {
          errorMessage = 'الفيديو غير موجود';
        } else {
          final message = data is Map ? data['message'] : null;
          errorMessage = message ?? 'خطأ في الخادم ($statusCode)';
        }
      } else if (e.type == DioExceptionType.connectionTimeout) {
        errorMessage = 'انتهت مهلة الاتصال';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = 'فشل الاتصال بالخادم';
      }

      debugPrint('❌ Stream data error: $errorMessage');
      return StreamData.error(errorMessage);
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      return StreamData.error('حدث خطأ غير متوقع');
    }
  }

  /// التحقق من النسخة
  Future<Map<String, dynamic>?> checkVersion() async {
    try {
      final response = await _dio.get('$_baseUrl/app/version');
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Check version failed: $e');
      return null;
    }
  }

  /// التحقق من صحة Token
  Future<bool> validateToken() async {
    try {
      final response = await _dio.get('$_baseUrl/auth/me');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Token validation failed: $e');
      return false;
    }
  }

  /// الحصول على بيانات الدرس
  Future<LessonData?> getLessonData({
    required int courseId,
    required int lessonId,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/courses/$courseId/lessons/$lessonId',
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          if (data.containsKey('data')) {
            return LessonData.fromJson(data['data'] as Map<String, dynamic>);
          }
          return LessonData.fromJson(data);
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Failed to get lesson data: $e');
      return null;
    }
  }

  /// تحديث Token
  void updateToken(String token) {
    _token = token;
  }

  /// تحديث Base URL
  void updateBaseUrl(String baseUrl) {
    _baseUrl = baseUrl;
  }

  /// إرسال تقدم المشاهدة للباك اند
  Future<void> updateProgress({
    required int lessonId,
    required int studentId,
    required int currentPositionSec,
    required int videoDurationSec,
    String? deviceSessionId,
    bool? isHomework,
  }) async {
    try {
      debugPrint('📤 [ApiService] Sending progress: lesson=$lessonId, pos=$currentPositionSec');
      
      final response = await _dio.post(
        '$_baseUrl/progress/lessons/$lessonId/progress',
        data: {
          'currentPositionSec': currentPositionSec,
          'videoDurationSec': videoDurationSec,
          'studentId': studentId,
          if (deviceSessionId != null) 'deviceSessionId': deviceSessionId,
          if (isHomework != null) 'isHomework': isHomework,
        },
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        if (responseData != null && responseData is Map) {
          final success = responseData['success'] ?? false;
          /*
          if (success) {
            debugPrint('✅ [ApiService] Progress updated successfully: lesson=$lessonId, pos=$currentPositionSec, max=$videoDurationSec');
          }
          */
        }
      }
    } on DioException catch (e) {
      debugPrint('❌ [ApiService] Failed to update progress: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('❌ [ApiService] Unexpected error updating progress: $e');
      rethrow;
    }
  }

  /// جلب تقدم المشاهدة من الباك اند
  Future<Map<String, dynamic>?> getProgress({
    required int lessonId,
    required int studentId,
  }) async {
    try {
      debugPrint('📤 [ApiService] Getting progress: lesson=$lessonId, student=$studentId');
      
      final response = await _dio.get(
        '$_baseUrl/progress/lessons/$lessonId/progress',
        queryParameters: {'studentId': studentId},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          debugPrint('✅ [ApiService] Got progress: ${data['data']}');
          return data['data'] as Map<String, dynamic>;
        }
      }
      return null;
    } on DioException catch (e) {
      debugPrint('❌ [ApiService] Failed to get progress: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('❌ [ApiService] Unexpected error getting progress: $e');
      return null;
    }
  }
}
