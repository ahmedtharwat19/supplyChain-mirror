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
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';

class UpdateService {
  static bool _isDownloading = false;

  static const String _pendingApkKey = 'pending_apk_path';
  static const String _pendingApkVersionKey = 'pending_apk_version';

  // ════════════════════════════════════════════════════════════
  // تحميل وتثبيت التحديث - حل متكامل لجميع الإصدارات
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
      final filePath = await _downloadFile(
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

      // ── حفظ الـ path لو أغلق المستخدم التطبيق قبل التثبيت ──
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingApkKey, filePath);
      if (version != null && version.isNotEmpty) {
        await prefs.setString(_pendingApkVersionKey, version);
      }

      // ════════════════════════════════════════════════════════
      // ✅ فتح نافذة التثبيت - حل متكامل لجميع الإصدارات
      // ════════════════════════════════════════════════════════
      
      // 🔹 الطريقة 1: استخدام Intent (Android 8+)
      bool installOpened = false;
      
      try {
        safeDebugPrint('📱 Method 1: Trying Android Intent...');
        final intent = AndroidIntent(
          action: 'android.intent.action.VIEW',
          data: filePath,
          type: 'application/vnd.android.package-archive',
          flags: [
            Flag.FLAG_GRANT_READ_URI_PERMISSION,
            Flag.FLAG_ACTIVITY_NEW_TASK,
          ],
        );
        await intent.launch();
        installOpened = true;
        safeDebugPrint('✅ Intent launched successfully');
      } catch (e) {
        safeDebugPrint('⚠️ Intent failed: $e');
      }

      // 🔹 الطريقة 2: استخدام OpenFile (Android 5+)
      if (!installOpened) {
        try {
          safeDebugPrint('📱 Method 2: Trying OpenFile...');
          final result = await OpenFile.open(filePath);
          if (result.type == ResultType.done) {
            installOpened = true;
            safeDebugPrint('✅ OpenFile launched successfully');
          } else {
            safeDebugPrint('⚠️ OpenFile result: ${result.type} - ${result.message}');
          }
        } catch (e) {
          safeDebugPrint('⚠️ OpenFile failed: $e');
        }
      }

      // 🔹 الطريقة 3: استخدام Process (Android 5+)
      if (!installOpened) {
        try {
          safeDebugPrint('📱 Method 3: Trying Process...');
          await Process.run('am', [
            'start',
            '-a',
            'android.intent.action.VIEW',
            '-d',
            filePath,
            '-t',
            'application/vnd.android.package-archive',
          ]);
          installOpened = true;
          safeDebugPrint('✅ Process launched successfully');
        } catch (e) {
          safeDebugPrint('⚠️ Process failed: $e');
        }
      }

      // 🔹 الطريقة 4: فتح مجلد التحميلات (آخر حل)
      if (!installOpened) {
        try {
          safeDebugPrint('📱 Method 4: Trying to open downloads folder...');
          final downloadsDir = await getExternalStorageDirectory();
          if (downloadsDir != null) {
            final intent = AndroidIntent(
              action: 'android.intent.action.VIEW',
              data: downloadsDir.path,
              type: 'resource/folder',
            );
            await intent.launch();
            installOpened = true;
            safeDebugPrint('✅ Downloads folder opened');
          }
        } catch (e) {
          safeDebugPrint('⚠️ Downloads folder failed: $e');
        }
      }

      // ════════════════════════════════════════════════════════
      // ✅ إغلاق التطبيق - حل متكامل لجميع الإصدارات
      // ════════════════════════════════════════════════════════

      safeDebugPrint('🚪 Closing app after opening installer...');

      // تأخير كافٍ لظهور شاشة التثبيت
      await Future.delayed(const Duration(milliseconds: 800));

      // 🔹 طريقة الإغلاق 1: SystemNavigator (Android 5+)
      try {
        safeDebugPrint('📱 Closing method 1: SystemNavigator.pop()');
        SystemNavigator.pop();
        safeDebugPrint('✅ SystemNavigator.pop() executed');
      } catch (e) {
        safeDebugPrint('⚠️ SystemNavigator.pop() failed: $e');
      }

      // 🔹 طريقة الإغلاق 2: exit(0) (جميع الإصدارات)
      try {
        safeDebugPrint('📱 Closing method 2: exit(0)');
        await Future.delayed(const Duration(milliseconds: 200));
        exit(0);
      } catch (e) {
        safeDebugPrint('⚠️ exit(0) failed: $e');
      }

      // 🔹 طريقة الإغلاق 3: إعادة تشغيل التطبيق (Android 5+)
      try {
        safeDebugPrint('📱 Closing method 3: Restart app');
        await Future.delayed(const Duration(milliseconds: 300));
        if (Platform.isAndroid) {
          await Process.run('am', [
            'start',
            '-n',
            'com.puresip.purchasing/.MainActivity',
            '--activity-clear-top',
          ]);
          safeDebugPrint('✅ Restart command executed');
        }
        await Future.delayed(const Duration(milliseconds: 300));
        exit(0);
      } catch (e) {
        safeDebugPrint('⚠️ Restart failed: $e');
        exit(0);
      }

      // 🔹 طريقة الإغلاق 4: تأكيد الإغلاق بعد 3 ثواني
      Future.delayed(const Duration(seconds: 3), () {
        try {
          safeDebugPrint('📱 Closing method 4: Final exit');
          exit(0);
        } catch (_) {}
      });

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
  // هل يوجد APK محمّل ينتظر التثبيت؟
  // ════════════════════════════════════════════════════════════
  static Future<bool> hasPendingInstall() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString(_pendingApkKey);
      if (path == null || path.isEmpty) return false;

      // لو الإصدار الحالي == الهدف → تم التثبيت → امسح
      final savedVersion = prefs.getString(_pendingApkVersionKey);
      if (savedVersion != null && savedVersion.isNotEmpty) {
        final currentVersion = await VersionChecker.getCurrentVersion();
        if (currentVersion == savedVersion) {
          safeDebugPrint('✅ Already updated — clearing pending flag');
          await clearPendingInstall();
          return false;
        }
      }

      final file = File(path);
      if (!await file.exists()) {
        await prefs.remove(_pendingApkKey);
        await prefs.remove(_pendingApkVersionKey);
        return false;
      }

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

      // ✅ محاولة فتح الملف للتثبيت
      try {
        final intent = AndroidIntent(
          action: 'android.intent.action.VIEW',
          data: path,
          type: 'application/vnd.android.package-archive',
          flags: [
            Flag.FLAG_GRANT_READ_URI_PERMISSION,
            Flag.FLAG_ACTIVITY_NEW_TASK,
          ],
        );
        await intent.launch();
        safeDebugPrint('✅ Intent launched for pending APK');
      } catch (e) {
        safeDebugPrint('⚠️ Intent failed for pending APK, trying OpenFile: $e');
        await OpenFile.open(path);
      }

      // ✅ إغلاق التطبيق بعد فتح شاشة التثبيت
      await Future.delayed(const Duration(milliseconds: 500));
      SystemNavigator.pop();
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
        if (await file.exists()) await file.delete();
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
    final request = http.Request('GET', Uri.parse(url));
    final response = await http.Client().send(request);

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final total = response.contentLength ?? 0;
    var received = 0;
    var lastBytes = 0;
    var lastTick = DateTime.now().millisecondsSinceEpoch;

    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}${Platform.pathSeparator}app-release.apk';
    final file = File(filePath);
    if (await file.exists()) await file.delete();

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
    return filePath;
  }
}