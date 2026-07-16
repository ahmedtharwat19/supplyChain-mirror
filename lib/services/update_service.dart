/* // lib/services/update_service.dart

import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:puresip_purchasing/services/version_checker.dart';

class UpdateService {
  static bool _isDownloading = false;

  static const String _pendingApkKey = 'pending_apk_path';
  static const String _pendingApkVersionKey = 'pending_apk_version';

  // ════════════════════════════════════════════════════════════
  // تحميل وتثبيت التحديث
  // ════════════════════════════════════════════════════════════
  static Future<void> downloadAndInstall({
    required BuildContext context,
    required String url,
    String? version,
  }) async {
    if (kIsWeb) return;
    if (_isDownloading) return;
    if (url.isEmpty) return;

    _isDownloading = true;

    final progressNotifier = ValueNotifier<double>(0.0);
    final speedNotifier = ValueNotifier<String>('');
    final remainingNotifier = ValueNotifier<String>('');

    // ── شريط التحميل ──
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.system_update,
                      size: 36,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'downloading_update'.tr(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<double>(
                    valueListenable: progressNotifier,
                    builder: (_, progress, __) => Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progress == 0 ? null : progress,
                            minHeight: 10,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ValueListenableBuilder<String>(
                              valueListenable: speedNotifier,
                              builder: (_, speed, __) => Text(
                                speed,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                            Text(
                              '${(progress * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ValueListenableBuilder<String>(
                          valueListenable: remainingNotifier,
                          builder: (_, remaining, __) => Text(
                            remaining,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    try {
      final filePath = await _downloadFileWithRetry(
        url: url,
        onProgress: (received, total, speed, remainingSec) {
          if (total > 0) {
            progressNotifier.value = (received / total).clamp(0.0, 1.0);
          }
          if (speed > 1024) {
            speedNotifier.value =
                '${'speed'.tr()}: ${(speed / 1024).toStringAsFixed(1)} MB/s';
          } else if (speed > 0) {
            speedNotifier.value =
                '${'speed'.tr()}: ${speed.toStringAsFixed(0)} KB/s';
          }
          if (remainingSec > 0) {
            remainingNotifier.value =
                '${'remaining'.tr()}: $remainingSec ${'seconds'.tr()}';
          }
        },
      );

      safeDebugPrint('✅ Download complete: $filePath');

      final fileSize = await File(filePath).length();
      safeDebugPrint('📦 File size: ${fileSize ~/ 1024} KB');

      if (fileSize < 500000) {
        throw Exception('invalid_update_file'.tr());
      }

      // ── إغلاق dialog التحميل ──
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      _isDownloading = false;

      // ── حفظ الـ path ──
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingApkKey, filePath);
      if (version != null && version.isNotEmpty) {
        await prefs.setString(_pendingApkVersionKey, version);
      }

      // ════════════════════════════════════════════════════════
      // ✅ فتح نافذة التثبيت + إغلاق التطبيق نهائياً
      // ════════════════════════════════════════════════════════

      safeDebugPrint('📱 Opening APK...');
      await OpenFile.open(filePath);
      safeDebugPrint('📱 OpenFile launched');

      await Future.delayed(const Duration(milliseconds: 800));

      safeDebugPrint('🚪 Closing app completely...');
      
      try {
        if (Platform.isAndroid) {
          SystemNavigator.pop();
        }
      } catch (e) {
        safeDebugPrint('⚠️ SystemNavigator.pop failed: $e');
      }

      await Future.delayed(const Duration(milliseconds: 200));
      exit(0);

    } catch (e) {
      safeDebugPrint('❌ Download/install error: $e');
      _isDownloading = false;

      if (context.mounted) {
        try {
          Navigator.of(context).pop();
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('update_error'.tr(args: [e.toString()])),
            backgroundColor: Colors.red,
          ),
        );
      }

      rethrow;
    }
  }

  // ════════════════════════════════════════════════════════════
  // تحميل الملف مع إعادة المحاولة
  // ════════════════════════════════════════════════════════════
  static Future<String> _downloadFileWithRetry({
    required String url,
    required void Function(int received, int total, double speedKBps, int remainingSec) onProgress,
    int maxRetries = 3,
  }) async {
    int attempt = 0;
    Exception? lastError;

    while (attempt < maxRetries) {
      attempt++;
      try {
        safeDebugPrint('📥 Download attempt $attempt of $maxRetries');
        return await _downloadFile(
          url: url,
          onProgress: onProgress,
        );
      } on http.ClientException catch (e) {
        lastError = e;
        safeDebugPrint('⚠️ Download attempt $attempt failed (network): $e');
        if (attempt < maxRetries) {
          final waitTime = attempt * 5;
          safeDebugPrint('⏳ Waiting $waitTime seconds before retry...');
          await Future.delayed(Duration(seconds: waitTime));
        }
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        safeDebugPrint('⚠️ Download attempt $attempt failed: $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 3));
        }
      }
    }

    throw lastError ?? Exception('download_failed'.tr());
  }

  // ════════════════════════════════════════════════════════════
  // هل يوجد APK محمّل ينتظر التثبيت؟
  // ════════════════════════════════════════════════════════════
  static Future<bool> hasPendingInstall() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString(_pendingApkKey);
      if (path == null || path.isEmpty) return false;

      final file = File(path);
      if (!await file.exists()) {
        safeDebugPrint('📁 APK file not found at: $path');
        await prefs.remove(_pendingApkKey);
        await prefs.remove(_pendingApkVersionKey);
        return false;
      }

      final fileSize = await file.length();
      safeDebugPrint('📦 APK file size: ${fileSize ~/ 1024} KB');
      
      if (fileSize < 500000) {
        safeDebugPrint('⚠️ APK file too small, deleting...');
        await file.delete();
        await prefs.remove(_pendingApkKey);
        await prefs.remove(_pendingApkVersionKey);
        return false;
      }

      final savedVersion = prefs.getString(_pendingApkVersionKey);
      if (savedVersion != null && savedVersion.isNotEmpty) {
        final currentVersion = await VersionChecker.getCurrentVersion();
        if (currentVersion == savedVersion) {
          safeDebugPrint('✅ Already updated — clearing pending flag');
          await clearPendingInstall();
          return false;
        }
      }

      safeDebugPrint('📦 Pending APK exists at: $path');
      return true;
    } catch (e) {
      safeDebugPrint('⚠️ hasPendingInstall error: $e');
      return false;
    }
  }

  // ════════════════════════════════════════════════════════════
  // تثبيت APK المنتظر
  // ════════════════════════════════════════════════════════════
  static Future<void> installPendingApk(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString(_pendingApkKey);
      if (path == null || path.isEmpty) return;

      final file = File(path);
      if (!await file.exists()) {
        await clearPendingInstall();
        return;
      }

      safeDebugPrint('📦 Installing pending APK: $path');

      await OpenFile.open(path);
      safeDebugPrint('📱 OpenFile launched for pending APK');

      await Future.delayed(const Duration(milliseconds: 800));
      
      try {
        if (Platform.isAndroid) {
          SystemNavigator.pop();
        }
      } catch (e) {
        safeDebugPrint('⚠️ SystemNavigator.pop failed: $e');
      }

      await Future.delayed(const Duration(milliseconds: 200));
      exit(0);

    } catch (e) {
      safeDebugPrint('❌ installPendingApk error: $e');
    }
  }

  // ════════════════════════════════════════════════════════════
  // مسح الـ pending flag والملف
  // ════════════════════════════════════════════════════════════
  static Future<void> clearPendingInstall() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString(_pendingApkKey);
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          safeDebugPrint('🗑️ Deleting APK: $path');
          await file.delete();
        }
      }
      await prefs.remove(_pendingApkKey);
      await prefs.remove(_pendingApkVersionKey);
      safeDebugPrint('✅ Pending install cleared');
    } catch (e) {
      safeDebugPrint('⚠️ clearPendingInstall error: $e');
    }
  }

  // ════════════════════════════════════════════════════════════
  // تحميل الملف مع تتبع السرعة والوقت المتبقي
  // ════════════════════════════════════════════════════════════
  static Future<String> _downloadFile({
    required String url,
    required void Function(
      int received,
      int total,
      double speedKBps,
      int remainingSec,
    ) onProgress,
  }) async {
    // ✅ زيادة الـ timeout إلى 5 دقائق
    final client = http.Client();
    final request = http.Request('GET', Uri.parse(url));
    
    try {
      final response = await client
          .send(request)
          .timeout(const Duration(minutes: 5));
  
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
  
      final total = response.contentLength ?? 0;
      var received = 0;
      var lastBytes = 0;
      var lastTick = DateTime.now().millisecondsSinceEpoch;
  
      // ✅ استخدام مجلد دائم
      String filePath;
      
      if (Platform.isAndroid) {
        try {
          final downloadsDir = await getExternalStorageDirectory();
          if (downloadsDir != null) {
            filePath = '${downloadsDir.path}/app-release.apk';
          } else {
            final appDir = await getApplicationDocumentsDirectory();
            filePath = '${appDir.path}/app-release.apk';
          }
        } catch (e) {
          final appDir = await getApplicationDocumentsDirectory();
          filePath = '${appDir.path}/app-release.apk';
        }
      } else {
        final appDir = await getApplicationDocumentsDirectory();
        filePath = '${appDir.path}/app-release.apk';
      }
      
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
  
      final sink = file.openWrite();
  
      await response.stream.listen((chunk) {
        received += chunk.length;
        sink.add(chunk);
  
        final now = DateTime.now().millisecondsSinceEpoch;
        final elapsed = now - lastTick;
  
        if (elapsed >= 1000) {
          final speedKBps = (received - lastBytes) / elapsed * 1000 / 1024;
          final remainingSec = (speedKBps > 0 && total > 0)
              ? ((total - received) / 1024 / speedKBps).round()
              : 0;
          lastBytes = received;
          lastTick = now;
          onProgress(received, total, speedKBps, remainingSec);
        } else {
          onProgress(received, total, 0, 0);
        }
      }).asFuture();
  
      await sink.close();
      
      final savedSize = await file.length();
      safeDebugPrint('📦 APK saved: $filePath (${savedSize ~/ 1024} KB)');
      return filePath;
      
    } finally {
      client.close();
    }
  }
} */

// lib/services/update_service.dart

import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:puresip_purchasing/services/version_checker.dart';

class UpdateService {
  static bool _isDownloading = false;

  static const String _pendingApkKey = 'pending_apk_path';
  static const String _pendingApkVersionKey = 'pending_apk_version';
  
  // ✅ اسم الملف الافتراضي كـ fallback
  static const String _defaultApkName = 'PureSip_Purchasing_v0.0.0-0.apk';

  // ════════════════════════════════════════════════════════════
  // استخراج اسم الملف من الرابط
  // ════════════════════════════════════════════════════════════
  static String _getFileNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final fileName = uri.pathSegments.last;
      if (fileName.isNotEmpty && fileName.endsWith('.apk')) {
        safeDebugPrint('✅ Extracted file name: $fileName');
        return fileName;
      }
    } catch (e) {
      safeDebugPrint('⚠️ Error extracting file name: $e');
    }
    return _defaultApkName;
  }

  // ════════════════════════════════════════════════════════════
  // تحميل وتثبيت التحديث
  // ════════════════════════════════════════════════════════════
  static Future<void> downloadAndInstall({
    required BuildContext context,
    required String url,
    String? version,
  }) async {
    if (kIsWeb) return;
    if (_isDownloading) return;
    if (url.isEmpty) return;

    _isDownloading = true;

    final progressNotifier = ValueNotifier<double>(0.0);
    final speedNotifier = ValueNotifier<String>('');
    final remainingNotifier = ValueNotifier<String>('');

    // ── شريط التحميل ──
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.system_update,
                      size: 36,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'downloading_update'.tr(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<double>(
                    valueListenable: progressNotifier,
                    builder: (_, progress, __) => Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progress == 0 ? null : progress,
                            minHeight: 10,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ValueListenableBuilder<String>(
                              valueListenable: speedNotifier,
                              builder: (_, speed, __) => Text(
                                speed,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                            Text(
                              '${(progress * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ValueListenableBuilder<String>(
                          valueListenable: remainingNotifier,
                          builder: (_, remaining, __) => Text(
                            remaining,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    try {
      final filePath = await _downloadFileWithRetry(
        url: url,
        onProgress: (received, total, speed, remainingSec) {
          if (total > 0) {
            progressNotifier.value = (received / total).clamp(0.0, 1.0);
          }
          if (speed > 1024) {
            speedNotifier.value =
                '${'speed'.tr()}: ${(speed / 1024).toStringAsFixed(1)} MB/s';
          } else if (speed > 0) {
            speedNotifier.value =
                '${'speed'.tr()}: ${speed.toStringAsFixed(0)} KB/s';
          }
          if (remainingSec > 0) {
            remainingNotifier.value =
                '${'remaining'.tr()}: $remainingSec ${'seconds'.tr()}';
          }
        },
      );

      safeDebugPrint('✅ Download complete: $filePath');

      final fileSize = await File(filePath).length();
      safeDebugPrint('📦 File size: ${fileSize ~/ 1024} KB');

      if (fileSize < 500000) {
        throw Exception('invalid_update_file'.tr());
      }

      // ── إغلاق dialog التحميل ──
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      _isDownloading = false;

      // ── حفظ الـ path ──
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingApkKey, filePath);
      if (version != null && version.isNotEmpty) {
        await prefs.setString(_pendingApkVersionKey, version);
      }

      // ════════════════════════════════════════════════════════
      // ✅ فتح نافذة التثبيت + إغلاق التطبيق نهائياً
      // ════════════════════════════════════════════════════════

      safeDebugPrint('📱 Opening APK...');
      await OpenFile.open(filePath);
      safeDebugPrint('📱 OpenFile launched');

      await Future.delayed(const Duration(milliseconds: 800));

      safeDebugPrint('🚪 Closing app completely...');

      try {
        if (Platform.isAndroid) {
          SystemNavigator.pop();
        }
      } catch (e) {
        safeDebugPrint('⚠️ SystemNavigator.pop failed: $e');
      }

      await Future.delayed(const Duration(milliseconds: 200));
      exit(0);

    } catch (e) {
      safeDebugPrint('❌ Download/install error: $e');
      _isDownloading = false;

      if (context.mounted) {
        try {
          Navigator.of(context).pop();
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('update_error'.tr(args: [e.toString()])),
            backgroundColor: Colors.red,
          ),
        );
      }

      rethrow;
    }
  }

  // ════════════════════════════════════════════════════════════
  // تحميل الملف مع إعادة المحاولة
  // ════════════════════════════════════════════════════════════
  static Future<String> _downloadFileWithRetry({
    required String url,
    required void Function(int received, int total, double speedKBps, int remainingSec) onProgress,
    int maxRetries = 3,
  }) async {
    int attempt = 0;
    Exception? lastError;

    while (attempt < maxRetries) {
      attempt++;
      try {
        safeDebugPrint('📥 Download attempt $attempt of $maxRetries');
        return await _downloadFile(
          url: url,
          onProgress: onProgress,
        );
      } on http.ClientException catch (e) {
        lastError = e;
        safeDebugPrint('⚠️ Download attempt $attempt failed (network): $e');
        if (attempt < maxRetries) {
          final waitTime = attempt * 5;
          safeDebugPrint('⏳ Waiting $waitTime seconds before retry...');
          await Future.delayed(Duration(seconds: waitTime));
        }
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        safeDebugPrint('⚠️ Download attempt $attempt failed: $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 3));
        }
      }
    }

    throw lastError ?? Exception('download_failed'.tr());
  }

  // ════════════════════════════════════════════════════════════
  // هل يوجد APK محمّل ينتظر التثبيت؟
  // ════════════════════════════════════════════════════════════
  static Future<bool> hasPendingInstall() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString(_pendingApkKey);
      if (path == null || path.isEmpty) return false;

      final file = File(path);
      if (!await file.exists()) {
        safeDebugPrint('📁 APK file not found at: $path');
        await prefs.remove(_pendingApkKey);
        await prefs.remove(_pendingApkVersionKey);
        return false;
      }

      final fileSize = await file.length();
      safeDebugPrint('📦 APK file size: ${fileSize ~/ 1024} KB');

      if (fileSize < 500000) {
        safeDebugPrint('⚠️ APK file too small, deleting...');
        await file.delete();
        await prefs.remove(_pendingApkKey);
        await prefs.remove(_pendingApkVersionKey);
        return false;
      }

      final savedVersion = prefs.getString(_pendingApkVersionKey);
      if (savedVersion != null && savedVersion.isNotEmpty) {
        final currentVersion = await VersionChecker.getCurrentVersion();
        if (currentVersion == savedVersion) {
          safeDebugPrint('✅ Already updated — clearing pending flag');
          await clearPendingInstall();
          return false;
        }
      }

      safeDebugPrint('📦 Pending APK exists at: $path');
      return true;
    } catch (e) {
      safeDebugPrint('⚠️ hasPendingInstall error: $e');
      return false;
    }
  }

  // ════════════════════════════════════════════════════════════
  // تثبيت APK المنتظر
  // ════════════════════════════════════════════════════════════
  static Future<void> installPendingApk(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString(_pendingApkKey);
      if (path == null || path.isEmpty) return;

      final file = File(path);
      if (!await file.exists()) {
        await clearPendingInstall();
        return;
      }

      safeDebugPrint('📦 Installing pending APK: $path');

      await OpenFile.open(path);
      safeDebugPrint('📱 OpenFile launched for pending APK');

      await Future.delayed(const Duration(milliseconds: 800));

      try {
        if (Platform.isAndroid) {
          SystemNavigator.pop();
        }
      } catch (e) {
        safeDebugPrint('⚠️ SystemNavigator.pop failed: $e');
      }

      await Future.delayed(const Duration(milliseconds: 200));
      exit(0);

    } catch (e) {
      safeDebugPrint('❌ installPendingApk error: $e');
    }
  }

  // ════════════════════════════════════════════════════════════
  // مسح الـ pending flag والملف
  // ════════════════════════════════════════════════════════════
  static Future<void> clearPendingInstall() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString(_pendingApkKey);
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          safeDebugPrint('🗑️ Deleting APK: $path');
          await file.delete();
        }
      }
      await prefs.remove(_pendingApkKey);
      await prefs.remove(_pendingApkVersionKey);
      safeDebugPrint('✅ Pending install cleared');
    } catch (e) {
      safeDebugPrint('⚠️ clearPendingInstall error: $e');
    }
  }

  // ════════════════════════════════════════════════════════════
  // تحميل الملف مع تتبع السرعة والوقت المتبقي
  // ════════════════════════════════════════════════════════════
  static Future<String> _downloadFile({
    required String url,
    required void Function(
      int received,
      int total,
      double speedKBps,
      int remainingSec,
    ) onProgress,
  }) async {
    // ✅ استخراج اسم الملف من الرابط
    final apkFileName = _getFileNameFromUrl(url);
    safeDebugPrint('📦 APK file name from URL: $apkFileName');

    final client = http.Client();
    final request = http.Request('GET', Uri.parse(url));

    try {
      final response = await client
          .send(request)
          .timeout(const Duration(minutes: 5));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final total = response.contentLength ?? 0;
      var received = 0;
      var lastBytes = 0;
      var lastTick = DateTime.now().millisecondsSinceEpoch;

      // ✅ استخدام مجلد دائم مع اسم الملف الديناميكي
      String filePath;

      if (Platform.isAndroid) {
        try {
          final downloadsDir = await getExternalStorageDirectory();
          if (downloadsDir != null) {
            filePath = '${downloadsDir.path}/$apkFileName';
          } else {
            final appDir = await getApplicationDocumentsDirectory();
            filePath = '${appDir.path}/$apkFileName';
          }
        } catch (e) {
          final appDir = await getApplicationDocumentsDirectory();
          filePath = '${appDir.path}/$apkFileName';
        }
      } else {
        final appDir = await getApplicationDocumentsDirectory();
        filePath = '${appDir.path}/$apkFileName';
      }

      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      final sink = file.openWrite();

      await response.stream.listen((chunk) {
        received += chunk.length;
        sink.add(chunk);

        final now = DateTime.now().millisecondsSinceEpoch;
        final elapsed = now - lastTick;

        if (elapsed >= 1000) {
          final speedKBps = (received - lastBytes) / elapsed * 1000 / 1024;
          final remainingSec = (speedKBps > 0 && total > 0)
              ? ((total - received) / 1024 / speedKBps).round()
              : 0;
          lastBytes = received;
          lastTick = now;
          onProgress(received, total, speedKBps, remainingSec);
        } else {
          onProgress(received, total, 0, 0);
        }
      }).asFuture();

      await sink.close();

      final savedSize = await file.length();
      safeDebugPrint('📦 APK saved: $filePath (${savedSize ~/ 1024} KB)');
      return filePath;

    } finally {
      client.close();
    }
  }
}