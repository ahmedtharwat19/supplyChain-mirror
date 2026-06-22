/* // lib/services/update_service.dart
//
// خدمة تحميل وتثبيت التحديثات تلقائيًا (Windows & Android فقط).
// تحتاج الباكدچات التالية في pubspec.yaml:
//   http: ^1.2.0
//   path_provider: ^2.1.0
//   open_file: ^3.3.2           (لفتح/تثبيت الملف على أندرويد)
//
// ولأندرويد: لازم صلاحية REQUEST_INSTALL_PACKAGES في AndroidManifest.xml:
//   <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />
// وتفعيل FileProvider (نفس الطريقة المعتادة لمشاركة الملفات على أندرويد).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

class UpdateService {
  /// يحمّل الملف من [url] مع عرض تقدّم التحميل، ثم يشغّله/يثبّته تلقائيًا
  /// حسب نظام التشغيل الحالي (Windows أو Android فقط).
  static Future<void> downloadAndInstall({
    required BuildContext context,
    required String url,
  }) async {
    if (url.isEmpty) return;

    // متغيّر تقدّم قابل للتحديث في الـ dialog
    final progressNotifier = ValueNotifier<double>(0.0);

    // عرض Dialog تقدّم التحميل (غير قابل للإغلاق اليدوي)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ValueListenableBuilder<double>(
        valueListenable: progressNotifier,
        builder: (context, progress, _) {
          return AlertDialog(
            title: const Text('جاري تحميل التحديث...'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: progress == 0 ? null : progress),
                const SizedBox(height: 12),
                Text('${(progress * 100).toStringAsFixed(0)}%'),
              ],
            ),
          );
        },
      ),
    );

    try {
      final filePath = await _downloadFile(
        url: url,
        onProgress: (received, total) {
          if (total > 0) {
            progressNotifier.value = received / total;
          }
        },
      );

      if (context.mounted) {
        Navigator.of(context).pop(); // إقفال dialog التحميل
      }

      await _installFile(filePath);
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('فشل التحديث'),
            content: Text('حدث خطأ أثناء تحميل التحديث: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('حسنًا'),
              ),
            ],
          ),
        );
      }
    }
  }

  /// تحميل الملف من الرابط وحفظه في مجلد مؤقت، مع تتبّع نسبة التقدّم.
  static Future<String> _downloadFile({
    required String url,
    required void Function(int received, int total) onProgress,
  }) async {
    final request = http.Request('GET', Uri.parse(url));
    final response = await http.Client().send(request);

    if (response.statusCode != 200) {
      throw Exception('فشل التحميل: HTTP ${response.statusCode}');
    }

    final total = response.contentLength ?? 0;
    var received = 0;

    final tempDir = await getTemporaryDirectory();
    final fileName = _fileNameForPlatform();
    final filePath = '${tempDir.path}${Platform.pathSeparator}$fileName';
    final file = File(filePath);
    final sink = file.openWrite();

    await response.stream.listen((chunk) {
      received += chunk.length;
      sink.add(chunk);
      onProgress(received, total);
    }).asFuture();

    await sink.close();
    return filePath;
  }

  static String _fileNameForPlatform() {
    if (Platform.isWindows) return 'app_update_installer.exe';
    if (Platform.isAndroid) return 'app_update.apk';
    throw UnsupportedError('التحديث التلقائي غير مدعوم على هذه المنصة');
  }

  /// تشغيل ملف التثبيت/التحديث حسب المنصة.
  static Future<void> _installFile(String filePath) async {
    if (Platform.isWindows) {
      // تشغيل ملف الـ installer مباشرة، ثم إغلاق التطبيق الحالي
      await Process.start(filePath, [], runInShell: true);
      exit(0);
    } else if (Platform.isAndroid) {
      // فتح ملف الـ APK، وهيظهر للمستخدم شاشة "تثبيت" تلقائيًا من النظام
      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done) {
        throw Exception('تعذّر فتح ملف التثبيت: ${result.message}');
      }
    } else {
      throw UnsupportedError('التحديث التلقائي غير مدعوم على هذه المنصة');
    }
  }
}
 */

/* 

// lib/services/update_service.dart
//
// خدمة تحميل وتثبيت التحديثات تلقائيًا (Windows & Android فقط).
// تحتاج الباكدچات التالية في pubspec.yaml:
//   http: ^1.2.0
//   path_provider: ^2.1.0
//   open_file: ^3.3.2
//   permission_handler: ^11.0.1
// lib/services/update_service.dart
//
// خدمة تحميل وتثبيت التحديثات تلقائيًا (Windows & Android فقط).
// تحتاج الباكدچات التالية في pubspec.yaml:
//   http: ^1.2.0
//   path_provider: ^2.1.0
//   open_file: ^3.3.2
//   permission_handler: ^11.0.1

import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class UpdateService {
  /// تحميل وتثبيت التحديث مع عرض نسبة التقدم
  static Future<void> downloadAndInstall({
    required BuildContext context,
    required String url,
  }) async {
    if (url.isEmpty) {
      safeDebugPrint('⚠️ Update URL is empty');
      return;
    }

    // ✅ تخزين مرجع للـ context
    final BuildContext currentContext = context;

    // ✅ متغير نسبة التقدم
    final progressNotifier = ValueNotifier<double>(0.0);

    try {
      // ✅ طلب الإذن للتخزين (Android)
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          if (currentContext.mounted) {
            ScaffoldMessenger.of(currentContext).showSnackBar(
              SnackBar(content: Text('storage_permission_required'.tr())),
            );
          }
          return;
        }
      }

      // ✅ التحقق من mounted قبل إظهار Dialog
      if (!currentContext.mounted) return;

      // ✅ إظهار Dialog التحميل مع نسبة التقدم
      showDialog(
        context: currentContext,
        barrierDismissible: false,
        builder: (dialogContext) => ValueListenableBuilder<double>(
          valueListenable: progressNotifier,
          builder: (context, progress, _) {
            final isComplete = progress >= 1.0;
            final displayProgress = isComplete ? 1.0 : progress.clamp(0.0, 0.99);

            return AlertDialog(
              title: Text(
                isComplete ? 'download_complete'.tr() : 'downloading_update'.tr(),
                style: TextStyle(
                  color: isComplete ? Colors.green : Colors.black,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isComplete) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                  ] else ...[
                    const Icon(Icons.check_circle, size: 48, color: Colors.green),
                    const SizedBox(height: 16),
                  ],
                  LinearProgressIndicator(
                    value: displayProgress,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isComplete ? Colors.green : Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isComplete
                        ? '${'download_complete'.tr()}!'
                        : '${(progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isComplete ? Colors.green : Colors.blue.shade700,
                    ),
                  ),
                  if (!isComplete) ...[
                    const SizedBox(height: 8),
                    Text(
                      'please_wait_downloading'.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                if (isComplete)
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text('ok'.tr()),
                  ),
              ],
            );
          },
        ),
      );

      // ✅ تحديد مسار التحميل حسب المنصة
      final directory = await _getDownloadDirectory();
      final fileName = _getFileNameForPlatform();
      final filePath = '${directory.path}${Platform.pathSeparator}$fileName';

      safeDebugPrint('📥 Downloading update to: $filePath');

      // ✅ تحميل الملف مع تتبع التقدم
      final response = await _downloadFile(
        url: url,
        filePath: filePath,
        onProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            progressNotifier.value = progress.clamp(0.0, 1.0);
          }
        },
      );

      // ✅ تحديث التقدم إلى 100%
      progressNotifier.value = 1.0;

      if (response) {
        safeDebugPrint('✅ Download complete: $filePath');

        // ✅ تأخير بسيط لإظهار اكتمال التحميل
        await Future.delayed(const Duration(milliseconds: 500));

        // ✅ التحقق من mounted قبل التعامل مع النتيجة
        if (!currentContext.mounted) return;

        // ✅ إغلاق Dialog التحميل
        Navigator.pop(currentContext);

        // ✅ تثبيت الملف (بدون تمرير context لتجنب التحذير)
        await _installFile(filePath);
      } else {
        safeDebugPrint('❌ Download failed');
        
        // ✅ التحقق من mounted قبل عرض رسالة الخطأ
        if (currentContext.mounted) {
          Navigator.pop(currentContext);
          ScaffoldMessenger.of(currentContext).showSnackBar(
            SnackBar(content: Text('download_failed'.tr())),
          );
        }
      }
    } catch (e) {
      safeDebugPrint('❌ Error downloading update: $e');

      // ✅ التحقق من mounted قبل عرض رسالة الخطأ
      if (currentContext.mounted) {
        try {
          Navigator.pop(currentContext);
        } catch (_) {
          // تجاهل إذا لم يكن هناك Dialog
        }

        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(content: Text('${'download_error'.tr()}: $e')),
        );
      }
    }
  }

  /// تحميل الملف مع تتبع التقدم
  static Future<bool> _downloadFile({
    required String url,
    required String filePath,
    required void Function(int received, int total) onProgress,
  }) async {
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        safeDebugPrint('❌ HTTP error: ${response.statusCode}');
        return false;
      }

      final total = response.contentLength ?? 0;
      var received = 0;

      final file = File(filePath);
      final sink = file.openWrite();

      await response.stream.listen((chunk) {
        received += chunk.length;
        sink.add(chunk);
        onProgress(received, total);
      }).asFuture();

      await sink.close();

      // ✅ التحقق من اكتمال التحميل
      final fileSize = await file.length();
      return fileSize > 0;
    } catch (e) {
      safeDebugPrint('❌ Download error: $e');
      return false;
    }
  }

  /// الحصول على مسار التحميل المناسب للمنصة
  static Future<Directory> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      // ✅ استخدام التخزين الخارجي للأندرويد
      final dir = await getExternalStorageDirectory();
      if (dir != null) return dir;
    }

    // ✅ استخدام التخزين المؤقت كبديل
    return await getTemporaryDirectory();
  }

  /// اسم الملف المناسب للمنصة
  static String _getFileNameForPlatform() {
    if (Platform.isWindows) return 'app_update_installer.exe';
    if (Platform.isAndroid) return 'app_update.apk';
    throw UnsupportedError('التحديث التلقائي غير مدعوم على هذه المنصة');
  }

  /// ✅ تثبيت/تشغيل الملف حسب المنصة (بدون BuildContext)
  static Future<void> _installFile(String filePath) async {
    if (Platform.isWindows) {
      // ✅ تشغيل ملف الـ installer
      try {
        await Process.start(filePath, [], runInShell: true);
        // ✅ إغلاق التطبيق الحالي بعد بدء التثبيت
        exit(0);
      } catch (e) {
        safeDebugPrint('❌ Failed to run installer: $e');
        // ✅ لا يمكن عرض SnackBar هنا لأننا لا نملك context
        // سيتم عرض الخطأ في الدالة الرئيسية
        rethrow;
      }
    } else if (Platform.isAndroid) {
      // ✅ فتح ملف الـ APK للتثبيت
      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done) {
        safeDebugPrint('❌ Failed to open APK: ${result.message}');
        throw Exception('Failed to open APK: ${result.message}');
      }
    } else {
      // ✅ منصات أخرى
      throw UnsupportedError('platform_not_supported'.tr());
    }
  }
} */

// lib/services/update_service.dart
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class UpdateService {
  static Future<void> downloadAndInstall({
    required BuildContext context,
    required String url,
  }) async {
    if (url.isEmpty) {
      safeDebugPrint('⚠️ Update URL is empty');
      if (context.mounted) {
        _showErrorDialog(context, 'download_error'.tr());
      }
      return;
    }

    safeDebugPrint('🚀 Starting download from: $url');

    final BuildContext currentContext = context;
    final progressNotifier = ValueNotifier<double>(0.0);

    try {
      // ✅ طلب الإذن للتخزين (Android)
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          if (currentContext.mounted) {
            _showErrorDialog(currentContext, 'storage_permission_required'.tr());
          }
          return;
        }
      }

      if (!currentContext.mounted) return;

      // ✅ إظهار Dialog التحميل
      showDialog(
        context: currentContext,
        barrierDismissible: false,
        builder: (dialogContext) => ValueListenableBuilder<double>(
          valueListenable: progressNotifier,
          builder: (context, progress, _) {
            final isComplete = progress >= 1.0;
            final displayProgress = isComplete ? 1.0 : progress.clamp(0.0, 0.99);

            return AlertDialog(
              title: Text(
                isComplete ? 'download_complete'.tr() : 'downloading_update'.tr(),
                style: TextStyle(
                  color: isComplete ? Colors.green : Colors.black,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isComplete) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                  ] else ...[
                    const Icon(Icons.check_circle, size: 48, color: Colors.green),
                    const SizedBox(height: 16),
                  ],
                  LinearProgressIndicator(
                    value: displayProgress,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isComplete ? Colors.green : Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isComplete
                        ? '${'download_complete'.tr()}!'
                        : '${(progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isComplete ? Colors.green : Colors.blue.shade700,
                    ),
                  ),
                  if (!isComplete) ...[
                    const SizedBox(height: 8),
                    Text(
                      'please_wait_downloading'.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                if (isComplete)
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text('ok'.tr()),
                  ),
              ],
            );
          },
        ),
      );

      // ✅ تحديد مسار التحميل
      final directory = await _getDownloadDirectory();
      final fileName = 'app-release.apk';
      final filePath = '${directory.path}${Platform.pathSeparator}$fileName';

      safeDebugPrint('📥 Downloading to: $filePath');

      // ✅ تحميل الملف
      final success = await _downloadFile(
        url: url,
        filePath: filePath,
        onProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            progressNotifier.value = progress.clamp(0.0, 1.0);
          }
        },
      );

      progressNotifier.value = 1.0;

      if (!currentContext.mounted) return;

      if (success) {
        safeDebugPrint('✅ Download complete: $filePath');

        await Future.delayed(const Duration(milliseconds: 500));

        // ✅ إغلاق Dialog
        if (currentContext.mounted) {
          Navigator.pop(currentContext);
        }

        // ✅ فتح الملف للتثبيت
        safeDebugPrint('📱 Opening file: $filePath');
        final result = await OpenFile.open(filePath);
        safeDebugPrint('📱 OpenFile result: ${result.type} - ${result.message}');
      } else {
        safeDebugPrint('❌ Download failed');
        if (currentContext.mounted) {
          Navigator.pop(currentContext);
          _showErrorDialog(currentContext, 'download_failed'.tr());
        }
      }
    } catch (e) {
      safeDebugPrint('❌ Error downloading update: $e');

      if (currentContext.mounted) {
        try {
          Navigator.pop(currentContext);
        } catch (_) {}

        _showErrorDialog(currentContext, '${'download_error'.tr()}: $e');
      }
    }
  }

  static Future<bool> _downloadFile({
    required String url,
    required String filePath,
    required void Function(int received, int total) onProgress,
  }) async {
    try {
      safeDebugPrint('📥 Downloading from: $url');

      final request = http.Request('GET', Uri.parse(url));
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        safeDebugPrint('❌ HTTP error: ${response.statusCode}');
        return false;
      }

      final total = response.contentLength ?? 0;
      var received = 0;

      final file = File(filePath);
      final sink = file.openWrite();

      await response.stream.listen((chunk) {
        received += chunk.length;
        sink.add(chunk);
        onProgress(received, total);
      }).asFuture();

      await sink.close();

      final fileSize = await file.length();
      safeDebugPrint('📦 File size: $fileSize bytes');
      return fileSize > 0;
    } catch (e) {
      safeDebugPrint('❌ Download error: $e');
      return false;
    }
  }

  static Future<Directory> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      final dir = await getExternalStorageDirectory();
      if (dir != null) return dir;
    }
    return await getTemporaryDirectory();
  }

  static void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('error'.tr()),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('ok'.tr()),
          ),
        ],
      ),
    );
  }
}