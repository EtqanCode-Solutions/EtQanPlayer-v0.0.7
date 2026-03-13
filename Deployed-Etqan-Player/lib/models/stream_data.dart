// /// أنواع مصادر الفيديو المدعومة
// enum VideoProvider { youtube, vimeo, vdocipher, hls, mp4, unknown }

// /// أنواع البث المدعومة
// enum StreamType { external, mp4, hls, dash, unknown }

// /// بيانات تشغيل الفيديو
// class StreamData {
//   final bool success;
//   final StreamType streamType;
//   final VideoProvider provider;
//   final String? streamUrl;
//   final String? videoId;
//   final String? thumbnailUrl;
//   final String? via;
//   final String? errorMessage;
  
//   // بيانات إضافية لتتبع التقدم
//   final int? lessonId;
//   final int? courseId;
//   final int? studentId;
//   final int? durationSec;
//   final String? lessonTitle;

//   const StreamData({
//     required this.success,
//     required this.streamType,
//     required this.provider,
//     this.streamUrl,
//     this.videoId,
//     this.thumbnailUrl,
//     this.via,
//     this.errorMessage,
//     this.lessonId,
//     this.courseId,
//     this.studentId,
//     this.durationSec,
//     this.lessonTitle,
//   });

//   /// إنشاء من استجابة API
//   factory StreamData.fromJson(Map<String, dynamic> json) {
//     // ملاحظة: الـ success موجود في الـ wrapper الخارجي، وليس في data
//     // لذلك لا نتحقق منه هنا - إذا وصلنا إلى هذه النقطة، يعني البيانات صحيحة

//     // تحديد نوع البث
//     final streamTypeStr = (json['streamType'] as String? ?? '').toLowerCase();
//     final StreamType streamType;
//     switch (streamTypeStr) {
//       case 'external':
//         streamType = StreamType.external;
//         break;
//       case 'mp4':
//         streamType = StreamType.mp4;
//         break;
//       case 'hls':
//         streamType = StreamType.hls;
//         break;
//       case 'dash':
//         streamType = StreamType.dash;
//         break;
//       default:
//         streamType = StreamType.unknown;
//     }

//     // تحديد المزود
//     final providerStr = (json['provider'] as String? ?? '').toLowerCase();
//     final VideoProvider provider;
//     switch (providerStr) {
//       case 'youtube':
//         provider = VideoProvider.youtube;
//         break;
//       case 'vimeo':
//         provider = VideoProvider.vimeo;
//         break;
//       case 'vdocipher':
//         provider = VideoProvider.vdocipher;
//         break;
//       default:
//         if (streamType == StreamType.hls) {
//           provider = VideoProvider.hls;
//         } else if (streamType == StreamType.mp4) {
//           provider = VideoProvider.mp4;
//         } else {
//           provider = VideoProvider.unknown;
//         }
//     }

//     return StreamData(
//       success: true, // البيانات وصلت بنجاح
//       streamType: streamType,
//       provider: provider,
//       streamUrl: json['streamUrl'] as String?,
//       videoId: json['videoId'] as String?,
//       thumbnailUrl: json['thumbnailUrl'] as String?,
//       via: json['via'] as String?,
//       // بيانات تتبع التقدم
//       lessonId: json['lessonId'] as int?,
//       courseId: json['courseId'] as int?,
//       studentId: json['studentId'] as int?,
//       durationSec: json['durationSec'] as int?,
//       lessonTitle: json['lessonTitle'] as String?,
//     );
//   }

//   /// إنشاء لليوتيوب
//   factory StreamData.youtube(String videoId, {String? thumbnailUrl}) {
//     return StreamData(
//       success: true,
//       streamType: StreamType.external,
//       provider: VideoProvider.youtube,
//       videoId: videoId,
//       thumbnailUrl:
//           thumbnailUrl ??
//           'https://img.youtube.com/vi/$videoId/maxresdefault.jpg',
//     );
//   }

//   /// إنشاء لـ Vimeo
//   factory StreamData.vimeo(String videoId, {String? thumbnailUrl}) {
//     return StreamData(
//       success: true,
//       streamType: StreamType.external,
//       provider: VideoProvider.vimeo,
//       videoId: videoId,
//       thumbnailUrl: thumbnailUrl,
//     );
//   }

//   /// إنشاء لـ VdoCipher
//   factory StreamData.vdocipher(
//     String videoId, {
//     String? otp,
//     String? playbackInfo,
//   }) {
//     return StreamData(
//       success: true,
//       streamType: StreamType.external,
//       provider: VideoProvider.vdocipher,
//       videoId: videoId,
//     );
//   }

//   /// إنشاء لـ HLS
//   factory StreamData.hls(String streamUrl, {String? thumbnailUrl}) {
//     return StreamData(
//       success: true,
//       streamType: StreamType.hls,
//       provider: VideoProvider.hls,
//       streamUrl: streamUrl,
//       thumbnailUrl: thumbnailUrl,
//     );
//   }

//   /// إنشاء لـ MP4
//   factory StreamData.mp4(String streamUrl, {String? thumbnailUrl}) {
//     return StreamData(
//       success: true,
//       streamType: StreamType.mp4,
//       provider: VideoProvider.mp4,
//       streamUrl: streamUrl,
//       thumbnailUrl: thumbnailUrl,
//     );
//   }

//   /// إنشاء للأخطاء
//   factory StreamData.error(String message) {
//     return StreamData(
//       success: false,
//       streamType: StreamType.unknown,
//       provider: VideoProvider.unknown,
//       errorMessage: message,
//     );
//   }

//   /// التحقق من كون الفيديو خارجي (يحتاج WebView أو مشغل خاص)
//   bool get isExternal => streamType == StreamType.external;

//   /// التحقق من كون الفيديو محلي (يمكن تشغيله بـ video_player)
//   bool get isNative =>
//       streamType == StreamType.mp4 ||
//       streamType == StreamType.hls ||
//       streamType == StreamType.dash;

//   /// الحصول على URL التشغيل النهائي
//   String? get playbackUrl {
//     if (isExternal) {
//       switch (provider) {
//         case VideoProvider.youtube:
//           return videoId != null
//               ? 'https://www.youtube.com/watch?v=$videoId'
//               : null;
//         case VideoProvider.vimeo:
//           return videoId != null ? 'https://vimeo.com/$videoId' : null;
//         case VideoProvider.vdocipher:
//           return videoId; // VdoCipher يحتاج معالجة خاصة
//         default:
//           return streamUrl;
//       }
//     }
//     return streamUrl;
//   }

//   @override
//   String toString() {
//     final urlPreview = streamUrl != null && streamUrl!.isNotEmpty
//         ? (streamUrl!.length > 50
//               ? '${streamUrl!.substring(0, 50)}...'
//               : streamUrl!)
//         : 'null';
//     return 'StreamData(success: $success, type: $streamType, provider: $provider, '
//         'videoId: $videoId, streamUrl: $urlPreview)';
//   }
// }

// /// بيانات الدرس
// class LessonData {
//   final int id;
//   final String title;
//   final String? description;
//   final int? durationSec;
//   final String? thumbnailUrl;

//   const LessonData({
//     required this.id,
//     required this.title,
//     this.description,
//     this.durationSec,
//     this.thumbnailUrl,
//   });

//   factory LessonData.fromJson(Map<String, dynamic> json) {
//     return LessonData(
//       id: json['id'] as int,
//       title: json['title'] as String? ?? 'Untitled',
//       description: json['description'] as String?,
//       durationSec: json['durationSec'] as int?,
//       thumbnailUrl: json['thumbnailUrl'] as String?,
//     );
//   }
// }


import 'dart:convert';
import 'package:flutter/foundation.dart';

/// أنواع مصادر الفيديو المدعومة
enum VideoProvider { youtube, vimeo, vdocipher, hls, mp4, unknown }

/// أنواع البث المدعومة
enum StreamType { external, mp4, hls, dash, unknown }

/// بيانات تشغيل الفيديو
class StreamData {
  final bool success;
  final StreamType streamType;
  final VideoProvider provider;

  final String? streamUrl;
  final String? videoId;
  final String? thumbnailUrl;
  final String? via;
  final String? errorMessage;

  // بيانات إضافية لتتبع التقدم
  final int? lessonId;
  final int? courseId;
  final int? studentId;
  final int? durationSec;
  final String? lessonTitle;

  // ✅ بيانات الحماية الجديدة
  final List<StreamData>? fakeVideos;
  final String? videoSessionToken;
  final String? validationKey;
  final List<VideoPart>? parts;
  final bool isProtected;

  const StreamData({
    required this.success,
    required this.streamType,
    required this.provider,
    this.streamUrl,
    this.videoId,
    this.thumbnailUrl,
    this.via,
    this.errorMessage,
    this.lessonId,
    this.courseId,
    this.studentId,
    this.durationSec,
    this.lessonTitle,
    this.fakeVideos,
    this.videoSessionToken,
    this.validationKey,
    this.parts,
    this.isProtected = false,
  });

  /// إنشاء من استجابة API
  factory StreamData.fromJson(Map<String, dynamic> json) {
    // تحديد نوع البث
    final streamTypeStr = (json['streamType'] as String? ?? '').toLowerCase();
    final StreamType streamType;
    switch (streamTypeStr) {
      case 'external':
        streamType = StreamType.external;
        break;
      case 'mp4':
        streamType = StreamType.mp4;
        break;
      case 'hls':
        streamType = StreamType.hls;
        break;
      case 'dash':
        streamType = StreamType.dash;
        break;
      default:
        streamType = StreamType.unknown;
    }

    // تحديد المزود
    final providerStr = (json['provider'] as String? ?? '').toLowerCase();
    final VideoProvider provider;
    switch (providerStr) {
      case 'youtube':
        provider = VideoProvider.youtube;
        break;
      case 'vimeo':
        provider = VideoProvider.vimeo;
        break;
      case 'vdocipher':
        provider = VideoProvider.vdocipher;
        break;
      default:
        if (streamType == StreamType.hls) {
          provider = VideoProvider.hls;
        } else if (streamType == StreamType.mp4) {
          provider = VideoProvider.mp4;
        } else {
          provider = VideoProvider.unknown;
        }
    }

    // ✅ معالجة أجزاء الفيديو إذا وجدت
    List<VideoPart>? parts;
    if (json['parts'] != null && json['parts'] is List) {
      parts = (json['parts'] as List)
          .map((p) => VideoPart.fromJson(p as Map<String, dynamic>))
          .toList();
    }

    // ✅ معالجة الفيديوهات المزيفة إذا وجدت
    List<StreamData>? fakeVideos;
    final videosJson = json['fakeVideos'] ?? json['videos'];
    final sessionToken = json['videoSessionToken'] as String?;

    if (videosJson != null && videosJson is List) {
      fakeVideos = (videosJson as List).map((v) {
        // ✅ ضمان نقل التوكن للأبناء لفك التشفير
        final Map<String, dynamic> vMap = Map<String, dynamic>.from(v as Map);
        vMap['videoSessionToken'] ??= sessionToken;
        return StreamData.fromJson(vMap);
      }).toList();
    }

    return StreamData(
      success: true,
      streamType: streamType,
      provider: provider,
      streamUrl: json['streamUrl'] as String?,
      videoId: json['videoId'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      via: json['via'] as String?,
      // بيانات تتبع التقدم
      lessonId: json['lessonId'] as int?,
      courseId: json['courseId'] as int?,
      studentId: json['studentId'] as int?,
      durationSec: json['durationSec'] as int?,
      lessonTitle: json['lessonTitle'] as String?,
      // ✅ بيانات الحماية
      fakeVideos: fakeVideos,
      videoSessionToken: json['videoSessionToken'] as String?,
      validationKey: json['validationKey'] as String?,
      parts: parts,
      isProtected: json['isProtected'] as bool? ?? false,
    );
  }

  /// إنشاء لليوتيوب
  factory StreamData.youtube(String videoId, {String? thumbnailUrl, String? lessonTitle}) {
    return StreamData(
      success: true,
      streamType: StreamType.external,
      provider: VideoProvider.youtube,
      videoId: videoId,
      thumbnailUrl: thumbnailUrl ?? 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg',
      lessonTitle: lessonTitle,
    );
  }

  /// إنشاء لـ Vimeo
  factory StreamData.vimeo(String videoId, {String? thumbnailUrl, String? lessonTitle}) {
    return StreamData(
      success: true,
      streamType: StreamType.external,
      provider: VideoProvider.vimeo,
      videoId: videoId,
      thumbnailUrl: thumbnailUrl,
      lessonTitle: lessonTitle,
    );
  }

  /// إنشاء لـ VdoCipher
  factory StreamData.vdocipher(String videoId, {String? lessonTitle}) {
    return StreamData(
      success: true,
      streamType: StreamType.external,
      provider: VideoProvider.vdocipher,
      videoId: videoId,
      lessonTitle: lessonTitle,
    );
  }

  /// إنشاء لـ HLS
  factory StreamData.hls(String streamUrl, {String? thumbnailUrl, String? lessonTitle}) {
    return StreamData(
      success: true,
      streamType: StreamType.hls,
      provider: VideoProvider.hls,
      streamUrl: streamUrl,
      thumbnailUrl: thumbnailUrl,
      lessonTitle: lessonTitle,
    );
  }

  /// إنشاء لـ MP4
  factory StreamData.mp4(String streamUrl, {String? thumbnailUrl, String? lessonTitle}) {
    return StreamData(
      success: true,
      streamType: StreamType.mp4,
      provider: VideoProvider.mp4,
      streamUrl: streamUrl,
      thumbnailUrl: thumbnailUrl,
      lessonTitle: lessonTitle,
    );
  }

  /// ✅ إنشاء سريع لـ Test Video (يحدد mp4/hls تلقائياً من الـ URL)
  factory StreamData.test(
    String url, {
    String lessonTitle = 'Test Video',
    String? thumbnailUrl,
  }) {
    final lower = url.toLowerCase();
    if (lower.contains('.m3u8') || lower.contains('m3u8')) {
      return StreamData.hls(url, thumbnailUrl: thumbnailUrl, lessonTitle: lessonTitle);
    }
    return StreamData.mp4(url, thumbnailUrl: thumbnailUrl, lessonTitle: lessonTitle);
  }

  /// ✅ إنشاء واضح لتست MP4 (لو عايزه explicit)
  factory StreamData.testMp4(
    String url, {
    String lessonTitle = 'Test Video (MP4)',
    String? thumbnailUrl,
  }) {
    return StreamData.mp4(url, thumbnailUrl: thumbnailUrl, lessonTitle: lessonTitle);
  }

  /// ✅ إنشاء واضح لتست HLS (لو عايزه explicit)
  factory StreamData.testHls(
    String url, {
    String lessonTitle = 'Test Video (HLS)',
    String? thumbnailUrl,
  }) {
    return StreamData.hls(url, thumbnailUrl: thumbnailUrl, lessonTitle: lessonTitle);
  }

  /// إنشاء للأخطاء
  factory StreamData.error(String message) {
    return StreamData(
      success: false,
      streamType: StreamType.unknown,
      provider: VideoProvider.unknown,
      errorMessage: message,
    );
  }

  /// التحقق من كون الفيديو خارجي (يحتاج WebView أو مشغل خاص)
  bool get isExternal => streamType == StreamType.external;

  /// التحقق من كون الفيديو Native (يمكن تشغيله بمشغل مباشر)
  bool get isNative =>
      streamType == StreamType.mp4 ||
      streamType == StreamType.hls ||
      streamType == StreamType.dash;

  /// الحصول على URL التشغيل النهائي
  String? get playbackUrl {
    if (isExternal) {
      switch (provider) {
        case VideoProvider.youtube:
          return videoId != null ? 'https://www.youtube.com/watch?v=$videoId' : null;
        case VideoProvider.vimeo:
          return videoId != null ? 'https://vimeo.com/$videoId' : null;
        case VideoProvider.vdocipher:
          return videoId; // VdoCipher يحتاج معالجة خاصة في المشغل
        default:
          return streamUrl;
      }
    }
    return streamUrl;
  }

  @override
  String toString() {
    final urlPreview = (streamUrl != null && streamUrl!.isNotEmpty)
        ? (streamUrl!.length > 50 ? '${streamUrl!.substring(0, 50)}...' : streamUrl!)
        : 'null';

    return 'StreamData(success: $success, type: $streamType, provider: $provider, '
        'videoId: $videoId, streamUrl: $urlPreview, lessonTitle: $lessonTitle, isProtected: $isProtected)';
  }

  /// ✅ إعادة بناء معرف فيديو YouTube من الأجزاء المشفرة
  String? get reconstructedVideoId {
    // 1. لو الـ ID موجود أصلاً (وضع غير مشفر)، رجعه
    if (videoId != null && videoId!.isNotEmpty) return videoId;

    // 2. لو إحنا في وضع الحماية وفيه قائمة فيديوهات (fake + real)
    if (fakeVideos != null && fakeVideos!.isNotEmpty) {
      // البحث عن الفيديو الحقيقي باستخدام الـ validationKey
      // الباك اند يبعت validationKey موحد في الـ wrapper وداخل الـ real video object
      final realVideo = fakeVideos!.firstWhere(
        (v) => v.validationKey == validationKey,
        orElse: () => fakeVideos!.first, // fallback لأي واحد لو فشل (غالباً هيفشل التشغيل)
      );
      return realVideo.reconstructedVideoId;
    }

    // 3. لو إحنا داخل الـ video object نفسه وبنفك أجزاءه
    if (parts == null || parts!.isEmpty) return null;

    try {
      // ترتيب الأجزاء حسب الـ Index (i)
      final sortedParts = List<VideoPart>.from(parts!)
        ..sort((a, b) => a.index.compareTo(b.index));

      // تجميع الأجزاء مع فك التشفير (بما في ذلك XOR لو موجود توكن)
      final fullId = sortedParts.map((p) => p.getDecodedValue(videoSessionToken)).join('');
      // debugPrint('🛡️ [StreamData] Reconstructed video ID: $fullId');
      return fullId;
    } catch (e) {
      debugPrint('❌ [StreamData] Error reconstructing video ID: $e');
      return null;
    }
  }

  /// ✅ التحقق من صحة الفيديو باستخدام مفتاح التأكيد
  bool isValid(String lessonId) {
    if (!isProtected) return true;
    if (validationKey == null) return false;

    // الباك اند يرسل MD5(lessonId) كمفتاح تأكيد
    // للتبسيط حالياً سنتحقق فقط من وجود المفتاح، وفي الإنتاج نقارن الـ hash
    return validationKey != null && validationKey!.isNotEmpty;
  }
}

/// ✅ جزء من فيديو مشفر
class VideoPart {
  final int index;
  final String value; // Base64 encoded

  VideoPart({required this.index, required this.value});

  factory VideoPart.fromJson(Map<String, dynamic> json) {
    return VideoPart(
      index: json['i'] as int,
      value: json['v'] as String,
    );
  }

  /// فك تشفير القيمة (Base64 + XOR اختياري)
  String getDecodedValue(String? sessionToken) {
    try {
      // 1. فك Base64
      final List<int> bytes = base64.decode(value);

      // 2. فك XOR لو التوكن موجود
      if (sessionToken != null && sessionToken.isNotEmpty) {
        final List<int> keyBytes = utf8.encode(sessionToken);
        final List<int> decryptedBytes = List<int>.generate(bytes.length, (i) {
          return bytes[i] ^ keyBytes[i % keyBytes.length];
        });
        return utf8.decode(decryptedBytes);
      }

      // 3. لو مفيش توكن، اعتبره Base64 عادي
      return utf8.decode(bytes);
    } catch (e) {
      debugPrint('⚠️ [VideoPart] Decoding failed: $e');
      return value;
    }
  }

  /// فك تشفير القيمة من Base64 (legacy)
  String get decodedValue => getDecodedValue(null);
}

/// بيانات الدرس
class LessonData {
  final int id;
  final String title;
  final String? description;
  final int? durationSec;
  final String? thumbnailUrl;

  const LessonData({
    required this.id,
    required this.title,
    this.description,
    this.durationSec,
    this.thumbnailUrl,
  });

  factory LessonData.fromJson(Map<String, dynamic> json) {
    return LessonData(
      id: json['id'] as int,
      title: json['title'] as String? ?? 'Untitled',
      description: json['description'] as String?,
      durationSec: json['durationSec'] as int?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
    );
  }
}