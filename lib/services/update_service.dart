// lib/services/update_service.dart
import 'dart:async';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/services/apk_installer.dart';

class UpdateService {
  static bool _isDownloading = false;

  static Future<void> downloadAndInstall({
    required BuildContext context,
    required String url,
  }) async {
    if (kIsWeb) return;
    if (_isDownloading) return;
    if (url.isEmpty) return;

    _isDownloading = true;

    try {
      final filePath = await _showDownloadDialog(context, url);

      if (!context.mounted) return;
      if (filePath == null) return;

      safeDebugPrint('✅ Download complete: $filePath');
      await ApkInstaller.install(filePath, context);
    } catch (e) {
      safeDebugPrint('❌ Error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('update_failed'.tr(args: ['$e'])),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      _isDownloading = false;
    }
  }

  static Future<String?> _showDownloadDialog(
      BuildContext context, String url) async {
    final progressNotifier = ValueNotifier<double>(0.0);
    final speedNotifier = ValueNotifier<String>('');
    final remainingNotifier = ValueNotifier<String>('');

    // ✅ Completer يضمن إننا ننتظر لحد ما التحميل يخلص فعلاً
    final completer = Completer<String?>();

    // ✅ نشغل التحميل قبل الـ dialog
    _downloadInBackground(
      url: url,
      progressNotifier: progressNotifier,
      speedNotifier: speedNotifier,
      remainingNotifier: remainingNotifier,
      onComplete: (path) {
        if (!completer.isCompleted) completer.complete(path);
      },
      onError: (e) {
        safeDebugPrint('❌ Download error: $e');
        if (!completer.isCompleted) completer.complete(null);
      },
    );

    // ✅ نعرض الـ dialog وننتظله يتقفل
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          // ✅ نراقب الـ completer ونقفل الـ dialog لما التحميل يخلص
          completer.future.then((_) {
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
          });

          return PopScope(
            canPop: false,
            child: Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ValueListenableBuilder<double>(
                  valueListenable: progressNotifier,
                  builder: (_, progress, __) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ✅ أيقونة التحديث
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.system_update,
                              size: 36, color: Colors.green.shade700),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'downloading_update'.tr(),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),

                        // ✅ السرعة
                        ValueListenableBuilder<String>(
                          valueListenable: speedNotifier,
                          builder: (_, speed, __) => Text(
                            speed,
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade600),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ✅ Progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progress == 0 ? null : progress,
                            minHeight: 10,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.green.shade600),
                          ),
                        ),
                        const SizedBox(height: 8),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // ✅ الوقت المتبقي
                            ValueListenableBuilder<String>(
                              valueListenable: remainingNotifier,
                              builder: (_, remaining, __) => Text(
                                remaining,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500),
                              ),
                            ),
                            // ✅ النسبة المئوية
                            Text(
                              '${(progress * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      );
    }

    // ✅ ننتظر الـ completer (التحميل الفعلي)
    return completer.future;
  }

  static Future<void> _downloadInBackground({
    required String url,
    required ValueNotifier<double> progressNotifier,
    required ValueNotifier<String> speedNotifier,
    required ValueNotifier<String> remainingNotifier,
    required Function(String) onComplete,
    required Function(dynamic) onError,
  }) async {
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final total = response.contentLength ?? 0;
      var received = 0;
      final stopwatch = Stopwatch()..start();
      var lastReceived = 0;
      var lastTime = 0;

      final tempDir = await getTemporaryDirectory();
      final filePath =
          '${tempDir.path}${Platform.pathSeparator}app-release.apk';
      final file = File(filePath);
      final sink = file.openWrite();

      await response.stream.listen((chunk) {
        received += chunk.length;
        sink.add(chunk);

        if (total > 0) {
          progressNotifier.value = received / total;
        }

        final now = stopwatch.elapsedMilliseconds;
        if (now - lastTime >= 1000) {
          final speed = (received - lastReceived) / 1024;
          lastReceived = received;
          lastTime = now;

          speedNotifier.value = speed > 1024
              ? '${'speed'.tr()}: ${(speed / 1024).toStringAsFixed(1)} MB/s'
              : '${'speed'.tr()}: ${speed.toStringAsFixed(0)} KB/s';

          if (total > 0 && speed > 0) {
            final remaining = (total - received) / 1024 / speed;
            remainingNotifier.value =
                '${'remaining'.tr()}: ${remaining.toStringAsFixed(0)} ${'seconds'.tr()}';
          }
        }
      }).asFuture();

      await sink.close();
      onComplete(filePath);
    } catch (e) {
      onError(e);
    }
 , }
}