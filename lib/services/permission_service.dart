/* // lib/services/permission_service.dart

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class PermissionService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// ✅ طلب الأذونات مع Dialog مخصص
  static Future<bool> requestPermissionsWithDialog(
    BuildContext context, {
    required VoidCallback onGranted,
    VoidCallback? onDenied,
  }) async {
    if (kIsWeb) return true;

    try {
      final permissions = await _getRequiredPermissions();
      if (permissions.isEmpty) {
        onGranted();
        return true;
      }

      // ✅ عرض Dialog لطلب الأذونات
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.security, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'permission_required'.tr(),
                  style: TextStyle(color: Colors.blue.shade700),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('storage_permission_required'.tr()),
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
                        'permission_explanation'.tr(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx, false);
                onDenied?.call();
              },
              child: Text('cancel'.tr()),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx, true);
                
                // ✅ طلب الأذونات
                final statuses = await permissions.request();
                final allGranted = statuses.values.every((s) => s.isGranted);
                
                if (allGranted) {
                  safeDebugPrint('✅ All permissions granted');
                  onGranted();
                } else {
                  safeDebugPrint('❌ Some permissions denied');
                  
                  // ✅ التحقق من الأذونات المرفوضة بشكل دائم
                  final permanentlyDenied = statuses.entries
                      .where((e) => e.value.isPermanentlyDenied)
                      .map((e) => e.key)
                      .toList();
                  
                  if (permanentlyDenied.isNotEmpty && context.mounted) {
                    await _showOpenSettingsDialog(context);
                  }
                  onDenied?.call();
                }
              },
              icon: const Icon(Icons.check),
              label: Text('allow'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );

      return result ?? false;
    } catch (e) {
      safeDebugPrint('❌ Permission dialog error: $e');
      return false;
    }
  }

  /// ✅ الحصول على الأذونات المطلوبة حسب الإصدار
  static Future<List<Permission>> _getRequiredPermissions() async {
    final List<Permission> permissions = [];

    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      final isAndroid13 = androidInfo.version.sdkInt >= 33;

      // ✅ أذونات التخزين
      if (isAndroid13) {
        if (!await Permission.photos.isGranted) {
          permissions.add(Permission.photos);
        }
        if (!await Permission.notification.isGranted) {
          permissions.add(Permission.notification);
        }
      } else {
        if (!await Permission.storage.isGranted) {
          permissions.add(Permission.storage);
        }
      }

      // ✅ صلاحية تثبيت التطبيقات
      if (!await Permission.requestInstallPackages.isGranted) {
        permissions.add(Permission.requestInstallPackages);
      }
    }

    return permissions;
  }

  /// ✅ عرض Dialog فتح الإعدادات
  static Future<void> _showOpenSettingsDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.settings, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'permission_required'.tr(),
                style: TextStyle(color: Colors.orange.shade700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('permission_permanently_denied'.tr()),
            const SizedBox(height: 8),
            Text(
              'go_to_settings_message'.tr(),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await openAppSettings();
            },
            icon: const Icon(Icons.settings),
            label: Text('open_settings'.tr()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ طلب الأذونات بصمت (للخلفية)
  static Future<bool> requestPermissionsSilently() async {
    try {
      final permissions = await _getRequiredPermissions();
      if (permissions.isEmpty) return true;

      final statuses = await permissions.request();
      return statuses.values.every((s) => s.isGranted);
    } catch (e) {
      safeDebugPrint('❌ Silent permission error: $e');
      return false;
    }
  }
} */