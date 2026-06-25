// lib/pages/dashboard/splash_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:puresip_purchasing/services/navigation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:puresip_purchasing/services/sync_service.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:puresip_purchasing/services/version_checker.dart';
import 'package:puresip_purchasing/services/update_service.dart';
import 'package:puresip_purchasing/services/auto_license_service.dart';

enum _UpdateStatus { none, optional, forced }

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _loadingMessage = "";
  bool _isOffline = false;
  String _appVersion = "";
  String _latestVersion = "";
  final SyncService _syncService = SyncService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool _isInitialized = false;
  bool _isNavigating = false;
  bool _isForceUpdateShowing = false; // ✅ منع ظهور Dialog مرتين

  static const String _keyLicenseKey = 'license_key';
  static const String _keyLicenseExpiry = 'license_expiry';
  static const String _keyLicenseStatus = 'license_status';
  static const String _keyCachedAt = 'license_cached_at';
  static const String _keySubscriptionStatus = 'subscription_status';

  @override
  void initState() {
    super.initState();
    _loadingMessage = "loading".tr();
    _loadAppVersion();
    _initializeApp();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final fullVersion = info.buildNumber.isNotEmpty
          ? '${info.version}+${info.buildNumber}'
          : info.version;
      if (mounted && _appVersion != fullVersion) {
        setState(() => _appVersion = fullVersion);
      }
      safeDebugPrint('📱 Current app version: $fullVersion');
    } catch (e) {
      safeDebugPrint('⚠️ Error loading app version: $e');
    }
  }

  Future<void> _saveLicenseToSecureStorage(
      String licenseKey, DateTime expiry) async {
    await _secureStorage.write(key: _keyLicenseKey, value: licenseKey);
    await _secureStorage.write(
        key: _keyLicenseExpiry, value: expiry.toIso8601String());
    await _secureStorage.write(key: _keyLicenseStatus, value: 'active');
    await _secureStorage.write(
        key: _keyCachedAt, value: DateTime.now().toIso8601String());
    safeDebugPrint('✅ License saved to SecureStorage: $licenseKey');
  }

  Future<Map<String, dynamic>?> _getLicenseFromSecureStorage() async {
    try {
      final licenseKey = await _secureStorage.read(key: _keyLicenseKey);
      final expiryStr = await _secureStorage.read(key: _keyLicenseExpiry);

      if (licenseKey == null || expiryStr == null) return null;

      final expiry = DateTime.tryParse(expiryStr);
      if (expiry == null) return null;

      return {
        'licenseKey': licenseKey,
        'expiryDate': expiry,
        'isValid': expiry.isAfter(DateTime.now()),
        'daysLeft': expiry.difference(DateTime.now()).inDays,
      };
    } catch (e) {
      safeDebugPrint('❌ Error reading license: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> _getLicenseStatusFromFirestore(
      String userId) async {
    try {
      final licensesSnapshot = await FirebaseFirestore.instance
          .collection('licenses')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      for (final doc in licensesSnapshot.docs) {
        final expiry = (doc.get('expiryDate') as Timestamp?)?.toDate();
        if (expiry != null && expiry.isAfter(DateTime.now())) {
          final difference = expiry.difference(DateTime.now());
          final daysLeft = difference.inDays;

          await _saveLicenseToSecureStorage(doc.id, expiry);

          return {
            'isValid': true,
            'isExpired': false,
            'isExpiringSoon': daysLeft <= 7,
            'expiryDate': expiry.toIso8601String(),
            'daysLeft': daysLeft,
            'timeLeftFormatted': _formatTimeLeft(difference),
            'licenseId': doc.id,
          };
        }
      }

      return {'isValid': false, 'isExpired': true};
    } catch (e) {
      safeDebugPrint('❌ Error getting license: $e');
      return {'isValid': false, 'isExpired': true};
    }
  }

  String _formatTimeLeft(Duration difference) {
    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;

    if (days > 0) {
      return '$days ${'days'.tr()} $hours ${'hours'.tr()}';
    } else if (hours > 0) {
      return '$hours ${'hours'.tr()} $minutes ${'minutes'.tr()}';
    } else {
      return '$minutes ${'minutes'.tr()}';
    }
  }

  Future<void> _cacheLicenseStatus(Map<String, dynamic> status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keySubscriptionStatus, json.encode(status));
      safeDebugPrint('✅ License status cached');
    } catch (e) {
      safeDebugPrint('❌ Error caching license: $e');
    }
  }

  void _navigateTo(String route) {
    if (_isNavigating) return;
    _isNavigating = true;

    safeDebugPrint('🚀 Navigating to: $route');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.go(route);
      }
    });
  }

  // ============================================================
  // ✅ دالة showForceUpdateDialog - عرض حوار التحديث الإجباري
  // ============================================================
// lib/pages/dashboard/splash_screen.dart - الجزء المهم

// ============================================================
// ✅ دالة showForceUpdateDialog - عرض حوار التحديث الإجباري
// ============================================================
void _showForceUpdateDialog(String message, String version) {
  if (_isForceUpdateShowing) return;
  _isForceUpdateShowing = true;

  if (!mounted) return;

  // ✅ جلب رابط التحميل من VersionChecker
  final downloadUrl = VersionChecker.getDownloadUrlAndroid();
  
  safeDebugPrint('📥 Force update - Download URL: $downloadUrl');

  // 🟢 نحتفظ بـ context الشاشة الأصلية (يبقى صالح بعد إقفال أي dialog)
  final rootContext = context;

  showDialog(
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
            message,
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
                    '${'new_version_available'.tr()}: v$version',
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
            safeDebugPrint('🟢 UPDATE BUTTON PRESSED!');

            // إغلاق Dialog
            Navigator.of(dialogContext).pop();

            // ✅ بدء التحميل (نستخدم rootContext لأن context الخاص بالـ dialog
            // يصبح غير صالح بعد popping)
            if (rootContext.mounted) {
              await UpdateService.downloadAndInstall(
                context: rootContext,
                url: downloadUrl,
              );
            }
             _continueInitialization();
          },
          icon: const Icon(Icons.download),
          label: Text('update_now'.tr()),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    ),
  );
}
  // ============================================================
  // ✅ دالة _showOptionalUpdateDialog - عرض حوار التحديث الاختياري
  // ============================================================
  void _showOptionalUpdateDialog() {
    if (!mounted) return;
    final latestVersion = VersionChecker.getLatestVersion();
    final downloadUrl = VersionChecker.getDownloadUrlAndroid();

    // 🟢 نحتفظ بـ context الشاشة الأصلية (يبقى صالح بعد إقفال الـ dialog)
    final rootContext = context;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text('update_available'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('optional_update_message'.tr()),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              // ✅ بعد إغلاق Dialog، نكمل التهيئة
              _continueInitialization();
            },
            child: Text('later'.tr()),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              safeDebugPrint('🚀 Starting optional download from: $downloadUrl');

              if (rootContext.mounted) {
                await UpdateService.downloadAndInstall(
                  context: rootContext,
                  url: downloadUrl,
                );
              }
            },
            child: Text('update_now'.tr()),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ✅ دالة _continueInitialization - استكمال التهيئة بعد التحديث الاختياري
  // ============================================================
  void _continueInitialization() {
    safeDebugPrint('➡️ Continuing initialization after optional update');
    _completeInitialization();
  }

  // ============================================================
  // ✅ دالة _checkForUpdates - فحص التحديثات
  // ============================================================
  Future<_UpdateStatus> _checkForUpdates() async {
    // ✅ على الويب، فكرة "تحديث الإصدار" غير منطقية: نسخة الويب نفسها
    // هي أحدث نسخة بمجرد نشرها (deploy)، ومفيش تطبيق مثبّت يحتاج تحديث
    // يدوي أو تحميل APK. نتجاوز الفحص بالكامل ونكمل التهيئة مباشرة.
    if (kIsWeb) {
      safeDebugPrint('ℹ️ Version check skipped on Web.');
      return _UpdateStatus.none;
    }

    try {
      final currentVersion = await VersionChecker.getCurrentVersion();
      final minVersion = VersionChecker.getMinVersion();
      final latestVersion = VersionChecker.getLatestVersion();

      safeDebugPrint(
          '📱 Version check - Current: $currentVersion, Min: $minVersion, Latest: $latestVersion');

      if (mounted) {
        setState(() {
          _latestVersion = latestVersion;
        });
      }

      // ✅ إذا كان هناك تحديث إجباري
      if (_isVersionLessThan(currentVersion, minVersion)) {
        final message = VersionChecker.getForceUpdateMessage();
        if (mounted) {
          // ✅ عرض Dialog مع زر التحميل - يمنع استكمال التهيئة
          _showForceUpdateDialog(message, latestVersion);
        }
        // ✅ إرجاع forced لمنع استكمال التهيئة
        return _UpdateStatus.forced;
      }
      // ✅ إذا كان هناك تحديث اختياري
      else if (_isVersionLessThan(currentVersion, latestVersion)) {
        return _UpdateStatus.optional;
      }
    } catch (e) {
      safeDebugPrint('⚠️ Version check error: $e');
    }
    return _UpdateStatus.none;
  }

  // ============================================================
  // ✅ دالة _checkForUpdatesWithTimeout - فحص التحديثات مع timeout
  // ============================================================
  Future<_UpdateStatus> _checkForUpdatesWithTimeout() async {
    try {
      final result = await Future.any([
        _checkForUpdates(),
        Future.delayed(const Duration(seconds: 5), () => _UpdateStatus.none),
      ]);
      return result;
    } catch (e) {
      return _UpdateStatus.none;
    }
  }

  // ============================================================
  // ✅ دوال مقارنة الإصدارات
  // ============================================================
  List<int> _parseVersionParts(String version) {
    final mainAndBuild = version.split('+');
    final mainParts = mainAndBuild[0].split('.');
    final build = mainAndBuild.length > 1
        ? int.tryParse(mainAndBuild[1]) ?? 0
        : 0;

    int part(int index) =>
        index < mainParts.length ? (int.tryParse(mainParts[index]) ?? 0) : 0;

    return [part(0), part(1), part(2), build];
  }

  bool _isVersionLessThan(String current, String required) {
    if (required.isEmpty) return false;
    try {
      final currentParts = _parseVersionParts(current);
      final requiredParts = _parseVersionParts(required);

      for (var i = 0; i < 4; i++) {
        if (currentParts[i] != requiredParts[i]) {
          return currentParts[i] < requiredParts[i];
        }
      }
      return false;
    } catch (e) {
      safeDebugPrint('⚠️ Version parse error: $e');
      return false;
    }
  }

  // ============================================================
  // ✅ دوال أخرى
  // ============================================================
  Future<bool> _isAdminUser(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      return userDoc.data()?['isAdmin'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (e) {
      return false;
    }
  }

  Future<void> _showMessageDialog(String message) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('notice'.tr()),
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

  void _safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  // ============================================================
  // ✅ دالة _completeInitialization - استكمال التهيئة
  // ============================================================
  Future<void> _completeInitialization() async {
    safeDebugPrint('🎯 Completing initialization...');

    // ✅ التحقق من وجود مستخدم
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      safeDebugPrint('👤 No user found, redirecting to /login');
      if (mounted) {
        _navigateTo('/login');
      }
      return;
    }

    safeDebugPrint('👤 User found: ${user.email}');

    // ✅ التحقق من التخزين المحلي
    _safeSetState(() => _loadingMessage = "checking_local_license".tr());

    final cachedLicense = await _getLicenseFromSecureStorage();

    if (cachedLicense != null && cachedLicense['isValid'] == true) {
      safeDebugPrint('✅ Valid CACHED license found');

      if (mounted) {
        _navigateTo('/dashboard');
      }

      unawaited(_syncService.syncAllInBackground());
      if (mounted){
      unawaited(NavigationService().preloadPages(context));}
      return;
    }

    // ✅ التحقق من Admin
    _safeSetState(() => _loadingMessage = "checking_admin".tr());
    final isAdmin = await _isAdminUser(user.uid);

    if (isAdmin) {
      safeDebugPrint('👑 Admin user, redirecting to /dashboard');
      if (mounted) {
        _navigateTo('/dashboard');
      }
      unawaited(_syncService.syncAllInBackground());
      if (!mounted) return;
      unawaited(NavigationService().preloadPages(context));
      return;
    }

    // ✅ التحقق من الاتصال بالإنترنت
    final hasInternet = await _checkInternetConnection();

    if (!hasInternet) {
      _safeSetState(() {
        _loadingMessage = "offline_mode".tr();
        _isOffline = true;
      });

      final offlineLicense = await _getLicenseFromSecureStorage();
      if (offlineLicense != null && offlineLicense['licenseKey'] != null) {
        safeDebugPrint('📱 Offline mode - using cached license');
        if (mounted) {
          _navigateTo('/dashboard');
        }
        return;
      }

      safeDebugPrint('📱 Offline mode - no cached license');
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) _navigateTo('/login');
      return;
    }

    // ✅ مع وجود إنترنت - جلب البيانات من Firestore
    try {
      _safeSetState(() {
        _loadingMessage = "checking_subscription".tr();
        _isOffline = false;
      });

      final licenseStatus = await _getLicenseStatusFromFirestore(user.uid);

      if (licenseStatus['isValid'] == true) {
        safeDebugPrint('✅ Valid license from Firestore');
        await _cacheLicenseStatus(licenseStatus);

        _safeSetState(() => _loadingMessage = "syncing_data".tr());
        await _syncService.syncUserData();
        await _syncService.syncDashboardCounts();
   if (!mounted) return;
        unawaited(NavigationService().preloadPages(context));

        if (mounted) {
          _navigateTo('/dashboard');
        }
      } else {
        safeDebugPrint('❌ No valid license, attempting auto-license...');
        _safeSetState(() => _loadingMessage = "creating_license".tr());

        final autoLicenseService = AutoLicenseService();
        final newLicense =
            await autoLicenseService.createAutoLicenseForNewUser(user.uid);

        if (newLicense != null) {
          safeDebugPrint('✅ Auto-license created: $newLicense');
          final newStatus = await _getLicenseStatusFromFirestore(user.uid);
          await _cacheLicenseStatus(newStatus);

          if (mounted) {
            _navigateTo('/dashboard');
          }
        } else {
          safeDebugPrint('❌ Auto-license failed');
          await _showMessageDialog('license_expired'.tr());
          if (mounted) _navigateTo('/license/request');
        }
      }
    } catch (e) {
      safeDebugPrint('❌ Init error: $e');
      _safeSetState(() => _loadingMessage = "initialization_failed".tr());

      final fallbackLicense = await _getLicenseFromSecureStorage();
      if (fallbackLicense != null && fallbackLicense['licenseKey'] != null) {
        safeDebugPrint('⚠️ Using cached license as fallback');
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) _navigateTo('/dashboard');
      } else {
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) _navigateTo('/login');
      }
    }
  }

  // ============================================================
  // ✅ الدالة الرئيسية _initializeApp
  // ============================================================
  Future<void> _initializeApp() async {
    if (_isInitialized) return;
    _isInitialized = true;

    safeDebugPrint('🎬 SplashScreen - Starting initialization...');

    // ✅ فحص التحديث الإجباري/الاختياري (المصدر الوحيد للحقيقة: Remote Config)
    _safeSetState(() => _loadingMessage = "checking_updates".tr());
    final updateStatus = await _checkForUpdatesWithTimeout();
    
    // ✅ إذا كان هناك تحديث إجباري، نوقف التهيئة هنا
    if (updateStatus == _UpdateStatus.forced) {
      safeDebugPrint('🔒 Force update required - Stopping initialization');
      return;
    }

    // ✅ إذا كان هناك تحديث اختياري، نعرض Dialog ونكمل بعد إغلاقه
    if (updateStatus == _UpdateStatus.optional && mounted) {
      _showOptionalUpdateDialog();
      // ✅ نكمل التهيئة بعد إغلاق Dialog (من خلال _continueInitialization)
      return;
    }

    // ✅ لا يوجد تحديث، نكمل التهيئة مباشرة
    await _completeInitialization();
  }

  @override
  void dispose() {
    _syncService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.green[50],
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _isOffline ? Colors.orange : Colors.green,
                    ),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 24),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _loadingMessage,
                    key: ValueKey(_loadingMessage),
                    style: TextStyle(
                      fontSize: 16,
                      color: _isOffline ? Colors.orange : Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (_isOffline)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      "offline_mode_notice".tr(),
                      style: const TextStyle(fontSize: 14, color: Colors.orange),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _latestVersion.isNotEmpty && _latestVersion != _appVersion
                        ? Colors.orange.shade50
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _latestVersion.isNotEmpty && _latestVersion != _appVersion
                          ? Colors.orange.shade300
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 14,
                            color: _latestVersion.isNotEmpty && _latestVersion != _appVersion
                                ? Colors.orange
                                : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${'current_version'.tr()}: v$_appVersion',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      if (_latestVersion.isNotEmpty && _latestVersion != _appVersion) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.system_update,
                              size: 14,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${'latest_version'.tr()}: v$_latestVersion ${'available'.tr()}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Text('Ahmed Tharwat tech.',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text('© $currentYear ALL RIGHTS ARE RESERVED',
                    style: const TextStyle(
                        fontSize: 12, letterSpacing: 1.2, color: Colors.grey)),
                if (_appVersion.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text("v$_appVersion",
                      style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}