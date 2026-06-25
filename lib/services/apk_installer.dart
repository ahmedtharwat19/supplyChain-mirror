// lib/services/apk_installer.dart

import 'package:android_package_installer/android_package_installer.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class ApkInstaller {
  static Future<void> install(String filePath, BuildContext context) async {
    try {
      // ✅ الـ API بترجع int? مش enum
      final int? statusCode = await AndroidPackageInstaller.installApk(
        apkFilePath: filePath,
      );

      safeDebugPrint('📦 Install status code: $statusCode');

      // 🔴 Check mounted right after the async gap
      if (!context.mounted) return;

      // 0 = success, 1 = failure, -1 = unknown
      if (statusCode == null || statusCode != 0) {
        final msg = _statusMessage(statusCode);
        _showInstallError(context, msg);
      } else {
        // ✅ نجاح التثبيت
        _showInstallSuccess(context);
      }
    } catch (e) {
      safeDebugPrint('❌ Installer error: $e');
      if (context.mounted) {
        _showInstallError(context, e.toString());
      }
    }
  }

  static String _statusMessage(int? code) {
    switch (code) {
      case 1:
        return 'install_failed_unknown_sources'.tr();
      case -1:
        return 'install_status_unknown'.tr();
      default:
        return 'install_failed_code'.tr(args: [code?.toString() ?? 'unknown']);
    }
  }

  static void _showInstallError(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog( // ✅ Use dialogContext here
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700),
            const SizedBox(width: 8),
            Text('install_error_title'.tr()),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            // ✅ Safely pop using the inner dialogContext to eliminate the lint warning
            onPressed: () => Navigator.pop(dialogContext), 
            child: Text('ok'.tr()),
          ),
        ],
      ),
    );
  }

  static void _showInstallSuccess(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog( // ✅ Use dialogContext here
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade700),
            const SizedBox(width: 8),
            Text('install_success_title'.tr()),
          ],
        ),
        content: Text('install_success_message'.tr()),
        actions: [
          TextButton(
            // ✅ Safely pop using the inner dialogContext to eliminate the lint warning
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('ok'.tr()),
          ),
        ],
      ),
    );
  }
}
