// lib/widgets/force_update_dialog.dart

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:puresip_purchasing/services/version_checker.dart';
import 'package:puresip_purchasing/services/update_service.dart';
import 'dart:io' show Platform;

/// عرض حوار التحديث الإجباري
Future<void> showForceUpdateDialog(
  BuildContext context, {
  String? message,
  String? version,
}) async {
  final latestVersion = version ?? VersionChecker.getLatestVersion();
  final downloadUrl = Platform.isAndroid
      ? VersionChecker.getDownloadUrlAndroid()
      : VersionChecker.getDownloadUrlWindows();

  // 🟢 نحتفظ بـ context الشاشة الأصلية (يبقى صالح بعد إقفال الـ dialog)
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
          // ❌ لا يتم عرض اللينك الكامل للمستخدم (لأسباب أمنية)
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

            // ✅ نستخدم rootContext (السليم) بعد إقفال هذا الـ Dialog
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