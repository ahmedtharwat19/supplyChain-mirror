/* import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

Future<void> showForceUpdateDialog(BuildContext context,
    {required String message}) async {
  return showDialog(
    context: context,
    barrierDismissible: false, // المستخدم مش هايقد يخرج منها
    builder: (BuildContext context) {
      return PopScope(
        canPop:
            false, // يمنع تماماً سحب الشاشة أو الضغط على زر الرجوع في أندرويد
        onPopInvokedWithResult: (didPop, result) {
          // لا نفعل شيئاً هنا لأننا نريد قفل الشاشة وإجبار المستخدم على التحديث
        },
        child: AlertDialog(
          title: Text('update_required'.tr()),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () async {
                final url = Platform.isAndroid
                    ? 'https://play.google.com/store/apps/details?id=com.puresip.purchasing'
                    : 'https://apps.apple.com/app/1:80836764748:ios:9b72a97f887d353649c0e9'; // غيّر الرابط
                if (await canLaunchUrlString(url)) {
                  await launchUrlString(url);
                }
              },
              child: Text('update_now'.tr()),
            ),
          ],
        ),
      );
    },
  );
}
 */



/* 
// lib/widgets/force_update_dialog.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:puresip_purchasing/services/version_checker.dart';
import 'package:puresip_purchasing/services/update_service.dart';
import 'dart:io' show Platform;

/// عرض حوار التحديث الإجباري مع رقم الإصدار الجديد
Future<void> showForceUpdateDialog(
  BuildContext context, {
  String? message,
  String? version,
}) async {
  final latestVersion = version ?? VersionChecker.getLatestVersion();
  final downloadUrl = Platform.isAndroid
      ? VersionChecker.getDownloadUrlAndroid()
      : VersionChecker.getDownloadUrl();

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.system_update, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'force_update_required'.tr(),
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message ?? 'force_update_message'.tr(),
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${'new_version_available'.tr()}: v$latestVersion',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'update_now_to_continue'.tr(),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
      actions: [
        ElevatedButton.icon(
          onPressed: () async {
            // إغلاق الـ Dialog
            Navigator.of(context).pop();

            // ✅ Windows أو Android: تحميل وتثبيت تلقائي
            if (Platform.isWindows || Platform.isAndroid) {
              await UpdateService.downloadAndInstall(
                context: context,
                url: downloadUrl,
              );
              return;
            }

            // fallback: فتح الرابط في المتصفح
            if (await canLaunchUrlString(downloadUrl)) {
              await launchUrlString(downloadUrl);
            }
          },
          icon: const Icon(Icons.download),
          label: Text('update_now'.tr()),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    ),
  );
} */


/* 
// lib/widgets/force_update_dialog.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:puresip_purchasing/services/version_checker.dart';
import 'package:puresip_purchasing/services/update_service.dart';
import 'dart:io' show Platform;

/// عرض حوار التحديث الإجباري مع رقم الإصدار الجديد
Future<void> showForceUpdateDialog(
  BuildContext context, {
  String? message,
  String? version,
}) async {
  final latestVersion = version ?? VersionChecker.getLatestVersion();
  final downloadUrl = Platform.isAndroid
      ? VersionChecker.getDownloadUrlAndroid()
      : VersionChecker.getDownloadUrl();

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.system_update, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'force_update_required'.tr(),
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message ?? 'force_update_message'.tr(),
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${'new_version_available'.tr()}: v$latestVersion',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'update_now_to_continue'.tr(),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
      actions: [
        ElevatedButton.icon(
          onPressed: () async {
            // إغلاق الـ Dialog
            Navigator.of(context).pop();

            // ✅ تحميل وتثبيت التحديث
            await UpdateService.downloadAndInstall(
              context: context,
              url: downloadUrl,
            );
          },
          icon: const Icon(Icons.download),
          label: Text('update_now'.tr()),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    ),
  );
} */

// lib/widgets/force_update_dialog.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:puresip_purchasing/services/version_checker.dart';
import 'package:puresip_purchasing/services/update_service.dart';
import 'dart:io' show Platform;

/// عرض حوار التحديث الإجباري مع رقم الإصدار الجديد
Future<void> showForceUpdateDialog(
  BuildContext context, {
  String? message,
  String? version,
}) async {
  final latestVersion = version ?? VersionChecker.getLatestVersion();
  final downloadUrl = Platform.isAndroid
      ? VersionChecker.getDownloadUrlAndroid()
      : VersionChecker.getDownloadUrlWindows();

  // 🟢 نحتفظ بـ context الشاشة الأصلية (الأب) لاستخدامه بعد إقفال الـ Dialog،
  // لأن context الخاص بالـ Dialog نفسه بيصبح "غير صالح" (unmounted) بعد popping
  final rootContext = context;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.system_update, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'force_update_required'.tr(),
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message ?? 'force_update_message'.tr(),
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${'new_version_available'.tr()}: v$latestVersion',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'update_now_to_continue'.tr(),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          // ❌ تمت إزالة عرض اللينك الكامل للمستخدم (لأسباب أمنية)
        ],
      ),
      actions: [
        ElevatedButton.icon(
          onPressed: () async {
            // إغلاق الـ Dialog باستخدام context الخاص بيه فقط
            Navigator.of(dialogContext).pop();

            if (downloadUrl.isEmpty) {
              if (rootContext.mounted) {
                ScaffoldMessenger.of(rootContext).showSnackBar(
                  const SnackBar(
                    content: Text('لا يوجد رابط تحديث متاح حاليًا.'),
                  ),
                );
              }
              return;
            }

            // ✅ نستخدم rootContext (السليم) لفتح dialog التحميل بعد إقفال هذا الـ Dialog
            if (rootContext.mounted) {
              await UpdateService.downloadAndInstall(
                context: rootContext,
                url: downloadUrl,
              );
            }
          },
          icon: const Icon(Icons.download),
          label: Text('update_now'.tr()),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    ),
  );
}