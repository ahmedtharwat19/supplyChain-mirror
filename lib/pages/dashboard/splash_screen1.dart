/* /* // lib/pages/splash_screen.dart - النسخة الكاملة مع easy_localization
import 'dart:async';
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
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
import 'package:url_launcher/url_launcher_string.dart';
import 'package:puresip_purchasing/services/version_checker.dart';
import 'package:puresip_purchasing/widgets/force_update_dialog.dart';
import 'package:puresip_purchasing/services/auto_license_service.dart';
import 'dart:io' show Platform;
import 'package:pub_semver/pub_semver.dart';

enum _UpdateStatus { none, optional, forced }

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _loadingMessage = "loading_local_data".tr();
  bool _isOffline = false;
  String _appVersion = "";
  _UpdateStatus _updateStatus = _UpdateStatus.none;
  final SyncService _syncService = SyncService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // مفاتيح التخزين
  static const String _keyLicenseKey = 'license_key';
  static const String _keySubscriptionStatus = 'subscription_status';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _initializeApp();
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _appVersion = info.version);
  }

  /// ✅ حفظ الترخيص في SecureStorage
  Future<void> _saveLicenseToSecureStorage(String licenseKey) async {
    await _secureStorage.write(key: _keyLicenseKey, value: licenseKey);
    safeDebugPrint('✅ License saved to SecureStorage: $licenseKey');
  }

  /// ✅ قراءة الترخيص من SecureStorage
  Future<String?> _getLicenseFromSecureStorage() async {
    return await _secureStorage.read(key: _keyLicenseKey);
  }

  /// ✅ جلب حالة الترخيص من Firestore مباشرة
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
          final now = DateTime.now();
          final difference = expiry.difference(now);
          final daysLeft = difference.inDays;

          // ✅ حفظ الترخيص في SecureStorage
          await _saveLicenseToSecureStorage(doc.id);

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
      safeDebugPrint('❌ Error getting license from Firestore: $e');
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

  /// ✅ حفظ حالة الترخيص في SharedPreferences
  Future<void> _cacheLicenseStatus(Map<String, dynamic> status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keySubscriptionStatus, json.encode(status));
      safeDebugPrint('✅ License status cached');
    } catch (e) {
      safeDebugPrint('❌ Error caching license status: $e');
    }
  }

  Future<void> _initializeApp() async {
    // 🔥 فحص التحديث الإجباري
    final updateStatus = await _checkForUpdatesWithTimeout();
    if (updateStatus == _UpdateStatus.forced) {
      return;
    }
    _updateStatus = updateStatus;

    // ✅ التحقق من وجود مستخدم
    final user = FirebaseAuth.instance.currentUser;

    // إذا لم يكن هناك مستخدم، اذهب إلى Login
    if (user == null) {
      if (mounted) {
        context.go('/login');
      }
      return;
    }

    // ✅ التحقق من الاتصال بالإنترنت
    final hasInternet = await _checkInternetConnection();

    if (!hasInternet) {
      // وضع عدم الاتصال - حاول استخدام الترخيص المخزن في SecureStorage
      final cachedLicenseKey = await _getLicenseFromSecureStorage();
      if (cachedLicenseKey != null) {
        if (mounted) {
          context.go('/dashboard');
        }
        return;
      }

      if (mounted) {
        setState(() {
          _loadingMessage = "offline_mode".tr();
          _isOffline = true;
        });
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) context.go('/login');
      }
      return;
    }

    // ✅ مع وجود إنترنت - جلب البيانات من Firestore
    try {
      setState(() => _loadingMessage = "checking_subscription".tr());

      // جلب حالة الترخيص من Firestore مباشرة
      final licenseStatus = await _getLicenseStatusFromFirestore(user.uid);

      if (licenseStatus['isValid'] == true) {
        // ✅ ترخيص صالح - حفظ في الكاش والانتقال إلى Dashboard
        await _cacheLicenseStatus(licenseStatus);

        setState(() => _loadingMessage = "syncing_data".tr());
        await _syncService.syncUserData();
        await _syncService.syncDashboardCounts();

        if (mounted) {
          unawaited(NavigationService().preloadPages(context));
        }

        if (mounted) {
          context.go('/dashboard');
          if (_updateStatus == _UpdateStatus.optional) {
            _showOptionalUpdateDialog();
          }
        }
      } else {
        // ❌ لا يوجد ترخيص صالح - محاولة إنشاء ترخيص تلقائي
        setState(() => _loadingMessage = "creating_license".tr());

        final autoLicenseService = AutoLicenseService();
        final newLicense =
            await autoLicenseService.createAutoLicenseForNewUser(user.uid);

        if (newLicense != null) {
          safeDebugPrint('✅ Auto-license created: $newLicense');
          // حفظ الترخيص في SecureStorage
          await _saveLicenseToSecureStorage(newLicense);

          // جلب حالة الترخيص مرة أخرى بعد الإنشاء
          final newStatus = await _getLicenseStatusFromFirestore(user.uid);
          await _cacheLicenseStatus(newStatus);

          if (mounted) {
            context.go('/dashboard');
          }
        } else {
          await _showMessageDialog('license_expired'.tr());
          if (mounted) context.go('/license/request');
        }
      }
    } catch (e) {
      safeDebugPrint('❌ Init error: $e');
      if (mounted) {
        setState(() => _loadingMessage = "initialization_failed".tr());
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) context.go('/login');
      }
    }
  }

  Future<_UpdateStatus> _checkForUpdatesWithTimeout() async {
    try {
      final result = await Future.any([
        _checkForUpdates(),
        Future.delayed(const Duration(seconds: 2), () => _UpdateStatus.none),
      ]);
      return result;
    } catch (e) {
      return _UpdateStatus.none;
    }
  }

  Future<_UpdateStatus> _checkForUpdates() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;
      final minVersion = VersionChecker.getMinVersion();
      final latestVersion = VersionChecker.getLatestVersion();

      safeDebugPrint(
          '📱 Current: $currentVersion, Min: $minVersion, Latest: $latestVersion');

      if (_isVersionLessThan(currentVersion, minVersion)) {
        final message = VersionChecker.getForceUpdateMessage();
        if (mounted) {
          await showForceUpdateDialog(context, message: message);
        }
        return _UpdateStatus.forced;
      } else if (_isVersionLessThan(currentVersion, latestVersion)) {
        return _UpdateStatus.optional;
      }
    } catch (e) {
      safeDebugPrint('⚠️ Version check error: $e');
    }
    return _UpdateStatus.none;
  }

  bool _isVersionLessThan(String current, String required) {
    if (required.isEmpty) return false;
    try {
      final Version currentVersion = Version.parse(current);
      final Version requiredVersion = Version.parse(required);
      return currentVersion < requiredVersion;
    } catch (e) {
      safeDebugPrint('⚠️ Version parse error: $e');
      return false;
    }
  }

  void _showOptionalUpdateDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('update_available')),
        content: Text(tr('optional_update_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('later')),
          ),
          TextButton(
            onPressed: () async {
              final url = Platform.isAndroid
                  ? 'https://play.google.com/store/apps/details?id=com.puresip.purchasing'
                  : 'https://apps.apple.com/app/idYOUR_APP_ID';
              if (await canLaunchUrlString(url)) {
                await launchUrlString(url);
              }
            },
            child: Text(tr('update_now')),
          ),
        ],
      ),
    );
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (e) {
      safeDebugPrint('❌ Connectivity check error: $e');
      return false;
    }
  }

  Future<void> _showMessageDialog(String message) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(tr('notice')),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr('ok')),
          ),
        ],
      ),
    );
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
                      style:
                          const TextStyle(fontSize: 14, color: Colors.orange),
                      textAlign: TextAlign.center,
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
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
 */



/* 
// lib/pages/splash_screen.dart - نسخة سريعة
import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:puresip_purchasing/services/navigation_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:puresip_purchasing/services/sync_service.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:puresip_purchasing/services/version_checker.dart';
import 'package:puresip_purchasing/widgets/force_update_dialog.dart';
import 'package:puresip_purchasing/services/auto_license_service.dart';
import 'package:pub_semver/pub_semver.dart';

enum _UpdateStatus { none, optional, forced }

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final String _loadingMessage = "loading_local_data".tr();
  final bool _isOffline = false;
  String _appVersion = "";
  final SyncService _syncService = SyncService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _keyLicenseKey = 'license_key';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _initializeApp();
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _appVersion = info.version);
  }

  Future<void> _initializeApp() async {
    // ✅ فحص التحديث الإجباري (سريع)
    final updateStatus = await _checkForUpdatesWithTimeout();
    if (updateStatus == _UpdateStatus.forced) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    // ✅ لا يوجد مستخدم -> اذهب إلى Login
    if (user == null) {
      if (mounted) {
        context.go('/login');
      }
      return;
    }

    // ✅ تحقق سريع: هل هو Admin؟
    final isAdmin = await _isAdminUser(user.uid);

    // ✅ Admin: اذهب فوراً إلى Dashboard (بدون أي فحوصات)
    if (isAdmin) {
      if (mounted) {
        context.go('/dashboard');
      }
      // تحديث في الخلفية
      unawaited(_syncService.syncAllInBackground());
      if (mounted) {
        unawaited(NavigationService().preloadPages(context));
      }
      return;
    }

    // ✅ مستخدم عادي: تحقق سريع من الإنترنت
    final hasInternet = await _checkInternetConnection();

    if (!hasInternet) {
      // ✅ وضع عدم الاتصال: حاول استخدام الترخيص المخزن
      final cachedLicense = await _secureStorage.read(key: _keyLicenseKey);
      if (cachedLicense != null && cachedLicense.isNotEmpty) {
        if (mounted) {
          context.go('/dashboard');
        }
        return;
      }
      if (mounted) {
        context.go('/login');
      }
      return;
    }

    // ✅ مع وجود إنترنت - تحقق سريع من الترخيص (مع timeout)
    try {
      final licenseStatus = await _getLicenseStatusFromFirestore(user.uid);

      if (licenseStatus['isValid'] == true) {
        // ✅ ترخيص صالح - اذهب إلى Dashboard
        if (mounted) {
          context.go('/dashboard');
        }
        // تحديث في الخلفية
        unawaited(_syncService.syncUserData());
        unawaited(_syncService.syncDashboardCounts());
        if (mounted) {
          unawaited(NavigationService().preloadPages(context));
        }
      } else {
        // ❌ لا يوجد ترخيص - حاول إنشاء ترخيص تلقائي
        final autoLicenseService = AutoLicenseService();
        final newLicense =
            await autoLicenseService.createAutoLicenseForNewUser(user.uid);

        if (newLicense != null) {
          await _secureStorage.write(key: _keyLicenseKey, value: newLicense);
          if (mounted) {
            context.go('/dashboard');
          }
        } else {
          await _showMessageDialog('license_expired'.tr());
          if (mounted) context.go('/license/request');
        }
      }
    } catch (e) {
      safeDebugPrint('❌ Init error: $e');
      // في حالة الخطأ، نحاول الدخول إلى Dashboard
      if (mounted) {
        context.go('/dashboard');
      }
    }
  }

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
          return {
            'isValid': true,
            'isExpired': false,
            'licenseId': doc.id,
          };
        }
      }
      return {'isValid': false, 'isExpired': true};
    } catch (e) {
      return {'isValid': false, 'isExpired': true};
    }
  }

  Future<_UpdateStatus> _checkForUpdatesWithTimeout() async {
    try {
      final result = await Future.any([
        _checkForUpdates(),
        Future.delayed(const Duration(seconds: 2), () => _UpdateStatus.none),
      ]);
      return result;
    } catch (e) {
      return _UpdateStatus.none;
    }
  }

  Future<_UpdateStatus> _checkForUpdates() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version.split('+').first;
      final minVersion = VersionChecker.getMinVersion().split('+').first;
      final latestVersion = VersionChecker.getLatestVersion().split('+').first;

      if (_isVersionLessThan(currentVersion, minVersion)) {
        final message = VersionChecker.getForceUpdateMessage();
        if (mounted) {
          await showForceUpdateDialog(context, message: message);
        }
        return _UpdateStatus.forced;
      } else if (_isVersionLessThan(currentVersion, latestVersion)) {
        return _UpdateStatus.optional;
      }
    } catch (e) {
      safeDebugPrint('⚠️ Version check error: $e');
    }
    return _UpdateStatus.none;
  }

  bool _isVersionLessThan(String current, String required) {
    if (required.isEmpty) return false;
    try {
      final Version currentVersion = Version.parse(current);
      final Version requiredVersion = Version.parse(required);
      return currentVersion < requiredVersion;
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
        title: Text(tr('notice')),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr('ok')),
          ),
        ],
      ),
    );
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
                      style:
                          const TextStyle(fontSize: 14, color: Colors.orange),
                      textAlign: TextAlign.center,
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
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
 */

// lib/pages/splash_screen.dart - نسخة كاملة ومحسنة مع التخزين المحلي

import 'dart:async';
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
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
import 'package:url_launcher/url_launcher_string.dart';
import 'package:puresip_purchasing/services/version_checker.dart';
import 'package:puresip_purchasing/widgets/force_update_dialog.dart';
import 'package:puresip_purchasing/services/auto_license_service.dart';
import 'dart:io' show Platform;
import 'package:pub_semver/pub_semver.dart';

enum _UpdateStatus { none, optional, forced }

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _loadingMessage = "loading_local_data".tr();
  bool _isOffline = false;
  String _appVersion = "";
  _UpdateStatus _updateStatus = _UpdateStatus.none;
  final SyncService _syncService = SyncService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // مفاتيح التخزين
  static const String _keyLicenseKey = 'license_key';
  static const String _keyLicenseExpiry = 'license_expiry';
  static const String _keyLicenseStatus = 'license_status';
  static const String _keyCachedAt = 'license_cached_at';
  static const String _keySubscriptionStatus = 'subscription_status';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _initializeApp();
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _appVersion = info.version);
  }

  /// ✅ حفظ الترخيص في SecureStorage
  Future<void> _saveLicenseToSecureStorage(String licenseKey, DateTime expiry) async {
    await _secureStorage.write(key: _keyLicenseKey, value: licenseKey);
    await _secureStorage.write(key: _keyLicenseExpiry, value: expiry.toIso8601String());
    await _secureStorage.write(key: _keyLicenseStatus, value: 'active');
    await _secureStorage.write(key: _keyCachedAt, value: DateTime.now().toIso8601String());
    safeDebugPrint('✅ License saved to SecureStorage: $licenseKey until $expiry');
  }

  /// ✅ قراءة الترخيص من SecureStorage
  Future<Map<String, dynamic>?> _getLicenseFromSecureStorage() async {
    try {
      final licenseKey = await _secureStorage.read(key: _keyLicenseKey);
      final expiryStr = await _secureStorage.read(key: _keyLicenseExpiry);
      
      if (licenseKey == null || expiryStr == null) {
        return null;
      }
      
      final expiry = DateTime.tryParse(expiryStr);
      if (expiry == null) {
        return null;
      }
      
      return {
        'licenseKey': licenseKey,
        'expiryDate': expiry,
        'isValid': expiry.isAfter(DateTime.now()),
        'daysLeft': expiry.difference(DateTime.now()).inDays,
      };
    } catch (e) {
      safeDebugPrint('❌ Error reading license from storage: $e');
      return null;
    }
  }

  /// ✅ جلب حالة الترخيص من Firestore مباشرة
  Future<Map<String, dynamic>> _getLicenseStatusFromFirestore(String userId) async {
    try {
      final licensesSnapshot = await FirebaseFirestore.instance
          .collection('licenses')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      for (final doc in licensesSnapshot.docs) {
        final expiry = (doc.get('expiryDate') as Timestamp?)?.toDate();
        if (expiry != null && expiry.isAfter(DateTime.now())) {
          final now = DateTime.now();
          final difference = expiry.difference(now);
          final daysLeft = difference.inDays;

          // ✅ حفظ الترخيص في SecureStorage
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
      safeDebugPrint('❌ Error getting license from Firestore: $e');
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

  /// ✅ حفظ حالة الترخيص في SharedPreferences
  Future<void> _cacheLicenseStatus(Map<String, dynamic> status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keySubscriptionStatus, json.encode(status));
      safeDebugPrint('✅ License status cached in SharedPreferences');
    } catch (e) {
      safeDebugPrint('❌ Error caching license status: $e');
    }
  }

  Future<void> _initializeApp() async {
    safeDebugPrint('🎬 SplashScreen - Starting initialization...');
    
    // 🔥 فحص التحديث الإجباري
    final updateStatus = await _checkForUpdatesWithTimeout();
    if (updateStatus == _UpdateStatus.forced) {
      return;
    }
    _updateStatus = updateStatus;

    // ✅ التحقق من وجود مستخدم
    final user = FirebaseAuth.instance.currentUser;

    // إذا لم يكن هناك مستخدم، اذهب إلى Login
    if (user == null) {
      safeDebugPrint('👤 No user found, redirecting to /login');
      if (mounted) {
        context.go('/login');
      }
      return;
    }

    safeDebugPrint('👤 User found: ${user.email}');

    // ✅ أولاً: التحقق من التخزين المحلي (سريع جداً)
    setState(() => _loadingMessage = "checking_local_license".tr());
    
    final cachedLicense = await _getLicenseFromSecureStorage();
    
    if (cachedLicense != null && cachedLicense['isValid'] == true) {
      safeDebugPrint('✅ Valid CACHED license found: ${cachedLicense['licenseKey']}');
      safeDebugPrint('📅 Expires: ${cachedLicense['expiryDate']}');
      safeDebugPrint('📆 Days left: ${cachedLicense['daysLeft']}');
      
      // ✅ التوجيه مباشرة من التخزين المحلي
      if (mounted) {
        context.go('/dashboard');
      }
      
      if(!mounted) return;
      // تحديث في الخلفية (اختياري)
      unawaited(_syncService.syncAllInBackground());
      unawaited(NavigationService().preloadPages(context));
      return;
    }

    // ✅ تحقق سريع: هل هو Admin؟
    setState(() => _loadingMessage = "checking_admin".tr());
    final isAdmin = await _isAdminUser(user.uid);

    // ✅ Admin: اذهب فوراً إلى Dashboard
    if (isAdmin) {
      safeDebugPrint('👑 Admin user, redirecting to /dashboard');
      if (mounted) {
        context.go('/dashboard');
      }

      if (!mounted) return;
      unawaited(_syncService.syncAllInBackground());
      unawaited(NavigationService().preloadPages(context));
      return;
    }

    // ✅ التحقق من الاتصال بالإنترنت
    final hasInternet = await _checkInternetConnection();

    if (!hasInternet) {
      // وضع عدم الاتصال - نحاول مرة أخرى استخدام الترخيص المخزن
      setState(() => _loadingMessage = "offline_mode".tr());
      _isOffline = true;
      
      final offlineLicense = await _getLicenseFromSecureStorage();
      if (offlineLicense != null && offlineLicense['licenseKey'] != null) {
        safeDebugPrint('📱 Offline mode - using cached license');
        if (mounted) {
          context.go('/dashboard');
        }
        return;
      }

      safeDebugPrint('📱 Offline mode - no cached license, redirecting to /login');
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) context.go('/login');
      return;
    }

    // ✅ مع وجود إنترنت - جلب البيانات من Firestore
    try {
      setState(() => _loadingMessage = "checking_subscription".tr());
      _isOffline = false;

      // جلب حالة الترخيص من Firestore مباشرة
      final licenseStatus = await _getLicenseStatusFromFirestore(user.uid);

      if (licenseStatus['isValid'] == true) {
        // ✅ ترخيص صالح - حفظ في الكاش والانتقال إلى Dashboard
        safeDebugPrint('✅ Valid license from Firestore: ${licenseStatus['licenseId']}');
        await _cacheLicenseStatus(licenseStatus);

        setState(() => _loadingMessage = "syncing_data".tr());
        await _syncService.syncUserData();
        await _syncService.syncDashboardCounts();

        if (mounted) {
          unawaited(NavigationService().preloadPages(context));
        }

        if (mounted) {
          context.go('/dashboard');
          if (_updateStatus == _UpdateStatus.optional) {
            _showOptionalUpdateDialog();
          }
        }
      } else {
        // ❌ لا يوجد ترخيص صالح - محاولة إنشاء ترخيص تلقائي
        safeDebugPrint('❌ No valid license found, attempting auto-license...');
        setState(() => _loadingMessage = "creating_license".tr());

        final autoLicenseService = AutoLicenseService();
        final newLicense = await autoLicenseService.createAutoLicenseForNewUser(user.uid);

        if (newLicense != null) {
          safeDebugPrint('✅ Auto-license created: $newLicense');
          
          // جلب الترخيص الجديد للحصول على تاريخ الانتهاء
          final newStatus = await _getLicenseStatusFromFirestore(user.uid);
          await _cacheLicenseStatus(newStatus);

          if (mounted) {
            context.go('/dashboard');
          }
        } else {
          safeDebugPrint('❌ Auto-license failed, redirecting to /license/request');
          await _showMessageDialog('license_expired'.tr());
          if (mounted) context.go('/license/request');
        }
      }
    } catch (e) {
      safeDebugPrint('❌ Init error: $e');
      setState(() => _loadingMessage = "initialization_failed".tr());
      
      // في حالة الخطأ، نحاول استخدام التخزين المحلي كملاذ أخير
      final fallbackLicense = await _getLicenseFromSecureStorage();
      if (fallbackLicense != null && fallbackLicense['licenseKey'] != null) {
        safeDebugPrint('⚠️ Using cached license as fallback');
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) context.go('/dashboard');
      } else {
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) context.go('/login');
      }
    }
  }

  Future<bool> _isAdminUser(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      return userDoc.data()?['isAdmin'] == true;
    } catch (e) {
      safeDebugPrint('⚠️ Error checking admin: $e');
      return false;
    }
  }

  Future<_UpdateStatus> _checkForUpdatesWithTimeout() async {
    try {
      final result = await Future.any([
        _checkForUpdates(),
        Future.delayed(const Duration(seconds: 2), () => _UpdateStatus.none),
      ]);
      return result;
    } catch (e) {
      return _UpdateStatus.none;
    }
  }

  Future<_UpdateStatus> _checkForUpdates() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version.split('+').first;
      final minVersion = VersionChecker.getMinVersion().split('+').first;
      final latestVersion = VersionChecker.getLatestVersion().split('+').first;

      safeDebugPrint('📱 Version check - Current: $currentVersion, Min: $minVersion, Latest: $latestVersion');

      if (_isVersionLessThan(currentVersion, minVersion)) {
        final message = VersionChecker.getForceUpdateMessage();
        if (mounted) {
          await showForceUpdateDialog(context, message: message);
        }
        return _UpdateStatus.forced;
      } else if (_isVersionLessThan(currentVersion, latestVersion)) {
        return _UpdateStatus.optional;
      }
    } catch (e) {
      safeDebugPrint('⚠️ Version check error: $e');
    }
    return _UpdateStatus.none;
  }

  bool _isVersionLessThan(String current, String required) {
    if (required.isEmpty) return false;
    try {
      final Version currentVersion = Version.parse(current);
      final Version requiredVersion = Version.parse(required);
      return currentVersion < requiredVersion;
    } catch (e) {
      safeDebugPrint('⚠️ Version parse error: $e');
      return false;
    }
  }

  void _showOptionalUpdateDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('update_available')),
        content: Text(tr('optional_update_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('later')),
          ),
          TextButton(
            onPressed: () async {
              final url = Platform.isAndroid
                  ? 'https://play.google.com/store/apps/details?id=com.puresip.purchasing'
                  : 'https://apps.apple.com/app/idYOUR_APP_ID';
              if (await canLaunchUrlString(url)) {
                await launchUrlString(url);
              }
            },
            child: Text(tr('update_now')),
          ),
        ],
      ),
    );
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (e) {
      safeDebugPrint('❌ Connectivity check error: $e');
      return false;
    }
  }

  Future<void> _showMessageDialog(String message) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(tr('notice')),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr('ok')),
          ),
        ],
      ),
    );
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
} */