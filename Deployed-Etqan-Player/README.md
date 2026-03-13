# مشغل إتقان التعليمي (Etqan Player)

مشغل فيديو آمن للمنصة التعليمية مع حماية شاملة من التصوير والتسجيل.

## الميزات

- **حماية من التصوير**: منع التقاط الشاشة على Android/iOS/Windows/macOS
- **مراقبة البرامج**: اكتشاف وحجب برامج تسجيل الشاشة
- **دعم مصادر متعددة**: YouTube, Vimeo, VdoCipher, HLS, MP4
- **واجهة احترافية**: تصميم عصري مع تحكم كامل في التشغيل

## متطلبات التشغيل

### Desktop (Windows/macOS/Linux)

```bash
samy_player.exe --token=YOUR_AUTH_TOKEN --lesson-id=123 --course-id=456 --api-base=https://api.example.com/api/v1
```

### المعاملات (Arguments)

| المعامل             | الوصف                            | مطلوب                        |
| ------------------- | -------------------------------- | ---------------------------- |
| `--token`, `-t`     | رمز المصادقة للوصول إلى API      | نعم                          |
| `--lesson-id`, `-l` | معرف الدرس المراد تشغيله         | نعم                          |
| `--course-id`, `-c` | معرف الكورس الذي يحتوي على الدرس | نعم                          |
| `--api-base`, `-a`  | عنوان API الأساسي                | لا (افتراضي: localhost:3000) |

## البناء

### Windows

```bash
flutter build windows --release
```

### macOS

```bash
flutter build macos --release
```

### Linux

```bash
flutter build linux --release
```

### Android

```bash
flutter build apk --release
```

### iOS

```bash
flutter build ios --release
```

## البنية

```
lib/
├── main.dart                    # نقطة الدخول الرئيسية
├── models/
│   └── stream_data.dart         # نماذج البيانات
├── screens/
│   ├── splash_screen.dart       # شاشة البداية
│   ├── player_screen.dart       # شاشة المشغل
│   └── error_screen.dart        # شاشة الأخطاء
├── services/
│   ├── api_service.dart         # خدمة الاتصال بـ API
│   ├── app_arguments_service.dart  # خدمة معالجة الـ arguments
│   ├── process_monitor_service.dart # مراقبة برامج التصوير
│   ├── screenshot_protection_service.dart # حماية من التصوير
│   └── window_service.dart      # إدارة نافذة Desktop
└── widgets/
    ├── secure_app_wrapper.dart  # غلاف الحماية
    ├── universal_player.dart    # المشغل الموحد
    └── players/
        ├── youtube_player_widget.dart   # مشغل YouTube
        ├── native_player_widget.dart    # مشغل HLS/MP4
        └── webview_player_widget.dart   # مشغل WebView
```

## الحماية

### Android & iOS

- استخدام `FLAG_SECURE` لمنع التصوير
- حزمة `no_screenshot` للحماية المتقدمة
- حزمة `secure_application` لإخفاء المحتوى عند الخروج من التطبيق

### Windows

- استخدام `SetWindowDisplayAffinity` مع `WDA_EXCLUDEFROMCAPTURE`
- مراقبة العمليات الجارية واكتشاف برامج التصوير

### macOS & Linux

- مراقبة العمليات واكتشاف برامج التصوير
- حزمة `secure_application` للحماية

## API المتوقع

يجب أن يوفر الـ Backend endpoint التالي:

```
GET /api/v1/courses/:courseId/lessons/:lessonId/stream
Authorization: Bearer {token}

Response:
{
  "success": true,
  "streamType": "external" | "mp4" | "hls" | "dash",
  "provider": "youtube" | "vimeo" | "vdocipher" | null,
  "videoId": "dQw4w9WgXcQ",
  "streamUrl": "https://...",
  "thumbnailUrl": "https://...",
  "via": "enrollment" | "subscription" | "free"
}
```

## الترخيص

هذا المشروع خاص ولا يجوز توزيعه أو استخدامه دون إذن.
"# Deployed-Etqan-Player" 
