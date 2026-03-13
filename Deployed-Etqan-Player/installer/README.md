# دليل إنشاء ملف التثبيت - مشغل منصة المبدع (Samy Player)

## المتطلبات

1. **Inno Setup** - تحميل من: https://jrsoftware.org/isdl.php
2. ملفات التطبيق المبنية في: `build\windows\x64\runner\Release`

## خطوات الإنشاء

### 1. تثبيت Inno Setup
- حمّل وثبّت Inno Setup من: **https://jrsoftware.org/isdl.php**
- تأكد من تثبيت **Inno Setup Compiler** (يأتي مع التثبيت)
- بعد التثبيت، يجب أن يكون موجوداً في:
  - `C:\Program Files (x86)\Inno Setup 6\` أو
  - `C:\Program Files\Inno Setup 6\`

### 2. الأيقونة
- الأيقونة موجودة تلقائياً في `windows/runner/resources/app_icon.ico`
- لا حاجة لإعداد إضافي

### 3. بناء التطبيق
```bash
flutter build windows --release
```

### 4. إنشاء ملف التثبيت

**الطريقة السريعة (موصى بها):**
```bash
cd installer
build_installer.bat
```

**الطريقة اليدوية (إذا فشلت الطريقة السريعة):**
1. افتح **Inno Setup Compiler** (من قائمة Start)
2. افتح ملف `installer/etqan_player_setup.iss`
3. اضغط **F9** أو **Build > Compile**
4. سيتم إنشاء `etqan_player_installer.exe` في مجلد `installer/output/`

**ملاحظة:** إذا كان Inno Setup مثبتاً في مسار مختلف، يمكنك:
- تعديل `build_installer.bat` وإضافة مسارك الخاص
- أو استخدام الطريقة اليدوية أعلاه

## الملفات المطلوبة

- `etqan_player_setup.iss` - ملف الإعدادات
- `build_installer.bat` - سكريبت البناء التلقائي
- ملفات التطبيق في `build\windows\x64\runner\Release` (يتم إنشاؤها بعد `flutter build windows --release`)

## المميزات

✅ واجهة تثبيت عادية (Next/Install/Finish)
✅ تسجيل URL Scheme تلقائياً (`samyplayer://`)
✅ إنشاء اختصارات على Desktop و Start Menu
✅ إلغاء التثبيت كامل
✅ دعم اللغة العربية (إذا أضفت ملف اللغة)

## ملاحظات

- تأكد من أن مسار `BuildPath` صحيح
- يمكن تعديل `AppVersion` و `AppName` حسب الحاجة
- ملف التثبيت النهائي سيكون في `installer/output/etqan_player_installer.exe`
