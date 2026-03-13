import 'package:flutter/material.dart';

/// Dialog لإدخال الكود السري
class QrCodeDialog extends StatefulWidget {
  const QrCodeDialog({super.key});

  @override
  State<QrCodeDialog> createState() => _QrCodeDialogState();
}

class _QrCodeDialogState extends State<QrCodeDialog> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitCode() {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      // يمكن إضافة رسالة خطأ هنا لاحقاً
      return;
    }

    // الكود وهمي حالياً - لا يتم ربطه بشيء
    debugPrint('📝 Code entered: $code');

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // ألوان من ثيم Frontend
    const brandColor = Color(0xFFFF5A1F);
    const creamColor = Color(0xFFFFF4E0);
    const charcoalColor = Color(0xFF1F1F1F);

    return Dialog(
      backgroundColor: creamColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: charcoalColor, width: 2),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // العنوان
            Text(
              'إدخال الكود السري',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: charcoalColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'أدخل الكود السري للوصول',
              style: TextStyle(
                fontSize: 14,
                color: charcoalColor.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // حقل الإدخال
            TextField(
              controller: _codeController,
              focusNode: _focusNode,
              autofocus: true,
              textInputAction: TextInputAction.done,
              keyboardType: TextInputType.text, // يدعم جميع الأحرف
              decoration: InputDecoration(
                hintText: 'أدخل الكود السري',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: charcoalColor, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: charcoalColor.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: brandColor, width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              style: TextStyle(
                fontSize: 16,
                color: charcoalColor,
                fontWeight: FontWeight.w500,
              ),
              onSubmitted: (_) => _submitCode(),
            ),
            const SizedBox(height: 24),

            // الأزرار
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: charcoalColor, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'إلغاء',
                      style: TextStyle(
                        color: charcoalColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submitCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: const Text(
                      'إدخال',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
