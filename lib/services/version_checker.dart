/* /* import 'package:firebase_remote_config/firebase_remote_config.dart';
import '../debug_helper.dart';

class VersionChecker {
  static final FirebaseRemoteConfig remoteConfig = FirebaseRemoteConfig.instance;

  // الدالة اللي هنناديها مرة واحدة عند بداية التشغيل
  static Future<void> init() async {
    try {
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          minimumFetchInterval: const Duration(hours: 1), // يحدّث كل ساعة عشان ما يضغطش على ال API
        ),
      );
      await remoteConfig.fetchAndActivate();
    } catch (e) {
      safeDebugPrint("⚠️ Error initializing remote config: $e");
    }
  }

  // جلب الحد الأدنى للنسخة من Firebase
  static String getMinVersion() => remoteConfig.getString('minimum_version');
  static String getLatestVersion() => remoteConfig.getString('latest_version');
  static String getForceUpdateMessage() => remoteConfig.getString('force_update_message');
} */

import 'package:firebase_remote_config/firebase_remote_config.dart';
import '../debug_helper.dart';

class VersionChecker {
  static final FirebaseRemoteConfig remoteConfig = FirebaseRemoteConfig.instance;

  // الدالة اللي هنناديها مرة واحدة عند بداية التشغيل
  static Future<void> init() async {
    try {
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          minimumFetchInterval: const Duration(hours: 1), // يحدّث كل ساعة عشان ما يضغطش على ال API
        ),
      );
      await remoteConfig.fetchAndActivate();
    } catch (e) {
      safeDebugPrint("⚠️ Error initializing remote config: $e");
    }
  }

  // جلب الحد الأدنى للنسخة من Firebase
  static String getMinVersion() => remoteConfig.getString('minimum_version');
  static String getLatestVersion() => remoteConfig.getString('latest_version');
  static String getForceUpdateMessage() => remoteConfig.getString('force_update_message');

  // ✅ روابط التحميل التلقائي (Windows & Android فقط)
  static String getDownloadUrlWindows() =>
      remoteConfig.getString('download_url_windows');
  static String getDownloadUrlAndroid() =>
      remoteConfig.getString('download_url_android');
} */


/* 
// lib/services/version_checker.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:package_info_plus/package_info_plus.dart';

class VersionChecker {
  static const String _githubApiUrl =
      'https://api.github.com/repos/ahmedtharwat19/supplyChain/releases/latest';

  static String _latestVersion = '';
  static String _minVersion = '';
  static String _downloadUrl = '';
  static String _forceUpdateMessage = '';
  static bool _isInitialized = false;

  /// جلب أحدث إصدار من GitHub
  static Future<void> fetchLatestVersion() async {
    try {
      safeDebugPrint('📡 Fetching latest version from GitHub...');

      final response = await http.get(
        Uri.parse(_githubApiUrl),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'PureSIP-Purchasing',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tagName = data['tag_name']?.toString() ?? '';

        // استخراج الإصدار من الـ tag (مثال: v1.5.5+9 -> 1.5.5+9)
        if (tagName.startsWith('v')) {
          _latestVersion = tagName.substring(1);
        } else {
          _latestVersion = tagName;
        }

        // جلب رابط التحميل
        final assets = data['assets'] as List? ?? [];
        for (final asset in assets) {
          final name = asset['name']?.toString() ?? '';
          if (name.endsWith('.apk')) {
            _downloadUrl = asset['browser_download_url']?.toString() ?? '';
            break;
          }
        }

        // إذا لم نجد APK في الـ assets، نستخدم رابط الـ release
        if (_downloadUrl.isEmpty) {
          _downloadUrl = data['html_url']?.toString() ??
              'https://github.com/ahmedtharwat19/supplyChain/releases/latest';
        }

        // جلب رسالة التحديث الإجباري من الـ body
        final body = data['body']?.toString() ?? '';
        _forceUpdateMessage = _extractForceUpdateMessage(body);

        safeDebugPrint('✅ Latest version: $_latestVersion');
        safeDebugPrint('✅ Download URL: $_downloadUrl');

        // تعيين الحد الأدنى للإصدار (يمكن أن يكون في الـ body أو ثابت)
        _minVersion = _extractMinVersion(body) ?? _latestVersion;

        _isInitialized = true;
      } else {
        safeDebugPrint('⚠️ Failed to fetch version: ${response.statusCode}');
        _useFallbackVersions();
      }
    } catch (e) {
      safeDebugPrint('❌ Error fetching version: $e');
      _useFallbackVersions();
    }
  }

  /// استخراج رسالة التحديث الإجباري من الـ body
  static String _extractForceUpdateMessage(String body) {
    // البحث عن علامة [FORCE_UPDATE] أو [MANDATORY]
    final regex = RegExp(r'\[FORCE_UPDATE\](.*?)(?=\[|$)',
        dotAll: true, caseSensitive: false);
    final match = regex.firstMatch(body);
    if (match != null) {
      return match.group(1)?.trim() ?? '';
    }

    // بحث بديل
    final regex2 = RegExp(r'\[MANDATORY\](.*?)(?=\[|$)',
        dotAll: true, caseSensitive: false);
    final match2 = regex2.firstMatch(body);
    if (match2 != null) {
      return match2.group(1)?.trim() ?? '';
    }

    return 'يرجى تحديث التطبيق إلى أحدث إصدار.';
  }

  /// استخراج الحد الأدنى للإصدار من الـ body
  static String? _extractMinVersion(String body) {
    final regex = RegExp(r'\[MIN_VERSION\](.*?)(?=\[|$)',
        dotAll: true, caseSensitive: false);
    final match = regex.firstMatch(body);
    if (match != null) {
      return match.group(1)?.trim();
    }
    return null;
  }

  /// استخدام قيم افتراضية في حالة فشل الاتصال
  static void _useFallbackVersions() {
    _latestVersion = '1.5.5+9';
    _minVersion = '1.5.0+0';
    _downloadUrl =
        'https://github.com/ahmedtharwat19/supplyChain/releases/latest';
    _forceUpdateMessage = 'يرجى تحديث التطبيق إلى أحدث إصدار.';
    _isInitialized = true;
    safeDebugPrint('⚠️ Using fallback versions');
  }

  /// الحصول على أحدث إصدار
  static String getLatestVersion() {
    return _latestVersion.isNotEmpty ? _latestVersion : '1.5.5+9';
  }

  /// الحصول على الحد الأدنى للإصدار
  static String getMinVersion() {
    return _minVersion.isNotEmpty ? _minVersion : '1.5.0+0';
  }

  /// الحصول على رابط التحميل
  static String getDownloadUrl() {
    return _downloadUrl.isNotEmpty
        ? _downloadUrl
        : 'https://github.com/ahmedtharwat19/supplyChain/releases/latest';
  }

  /// الحصول على رابط التحميل لنظام Android
  static String getDownloadUrlAndroid() {
    return _downloadUrl.isNotEmpty
        ? _downloadUrl
        : 'https://github.com/ahmedtharwat19/supplyChain/releases/latest/download/app-release.apk';
  }

  /// الحصول على رابط التحميل لنظام Windows
  static String getDownloadUrlWindows() {
    return _downloadUrl.isNotEmpty
        ? _downloadUrl
        : 'https://github.com/ahmedtharwat19/supplyChain/releases/latest';
  }

  /// الحصول على رسالة التحديث الإجباري
  static String getForceUpdateMessage() {
    return _forceUpdateMessage.isNotEmpty
        ? _forceUpdateMessage
        : 'يرجى تحديث التطبيق إلى أحدث إصدار.';
  }

  /// التحقق مما إذا كان التحديث متاحاً
  static Future<bool> isUpdateAvailable() async {
    if (!_isInitialized) {
      await fetchLatestVersion();
    }

    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.buildNumber.isNotEmpty
          ? '${info.version}+${info.buildNumber}'
          : info.version;

      return _isVersionLessThan(currentVersion, _latestVersion);
    } catch (e) {
      safeDebugPrint('⚠️ Error checking update: $e');
      return false;
    }
  }

  /// التحقق مما إذا كان التحديث إجبارياً
  static Future<bool> isForceUpdateRequired() async {
    if (!_isInitialized) {
      await fetchLatestVersion();
    }

    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.buildNumber.isNotEmpty
          ? '${info.version}+${info.buildNumber}'
          : info.version;

      return _isVersionLessThan(currentVersion, _minVersion);
    } catch (e) {
      safeDebugPrint('⚠️ Error checking force update: $e');
      return false;
    }
  }

  /// مقارنة الإصدارات
  static bool _isVersionLessThan(String current, String required) {
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

  static List<int> _parseVersionParts(String version) {
    final mainAndBuild = version.split('+');
    final mainParts = mainAndBuild[0].split('.');
    final build = mainAndBuild.length > 1
        ? int.tryParse(mainAndBuild[1]) ?? 0
        : 0;

    int part(int index) =>
        index < mainParts.length ? (int.tryParse(mainParts[index]) ?? 0) : 0;

    return [part(0), part(1), part(2), build];
  }

  /// الحصول على الإصدار الحالي
  static Future<String> getCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.buildNumber.isNotEmpty
          ? '${info.version}+${info.buildNumber}'
          : info.version;
    } catch (e) {
      safeDebugPrint('⚠️ Error getting current version: $e');
      return '1.0.0';
    }
  }

  /// تنسيق رسالة التحديث
  static String getUpdateMessage() {
    if (_latestVersion.isEmpty) {
      return 'يوجد تحديث جديد متاح.';
    }
    return 'يتوفر إصدار جديد: v$_latestVersion\n'
        'هل ترغب في التحديث الآن؟';
  }
} */

// lib/services/version_checker.dart
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

class VersionChecker {
  static final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;
  
  static const String _githubApiUrl =
      'https://api.github.com/repos/ahmedtharwat19/supplyChain/releases/latest';

  static String _latestVersion = '';
  static String _minVersion = '';
  static String _downloadUrl = '';
  static String _forceUpdateMessage = '';
  static bool _isInitialized = false;

  /// ✅ تهيئة Remote Config وجلب الإصدارات
  static Future<void> init() async {
    // ✅ تهيئة Remote Config أولاً
    try {
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );
      await _remoteConfig.fetchAndActivate();
      safeDebugPrint('✅ Remote Config initialized');
    } catch (e) {
      safeDebugPrint('⚠️ Remote Config error: $e');
    }
    
    // ✅ ثم جلب الإصدارات
    await fetchLatestVersion();
  }

  /// جلب أحدث إصدار من GitHub أو Remote Config
  static Future<void> fetchLatestVersion() async {
    try {
      // ✅ أولاً: محاولة جلب من Remote Config (أسرع)
      final remoteVersion = _remoteConfig.getString('latest_version');
      final remoteMinVersion = _remoteConfig.getString('minimum_version');
      final remoteDownloadUrl = _remoteConfig.getString('download_url_android');
      
      if (remoteVersion.isNotEmpty && remoteDownloadUrl.isNotEmpty) {
        _latestVersion = remoteVersion;
        _minVersion = remoteMinVersion.isNotEmpty ? remoteMinVersion : remoteVersion;
        _downloadUrl = remoteDownloadUrl;
        _forceUpdateMessage = _remoteConfig.getString('force_update_message');
        _isInitialized = true;
        
        safeDebugPrint('✅ Version from Remote Config: $_latestVersion');
        safeDebugPrint('✅ Download URL from Remote Config: $_downloadUrl');
        return;
      }
      
      // ✅ ثانياً: جلب من GitHub API
      safeDebugPrint('📡 Fetching latest version from GitHub...');

      final response = await http.get(
        Uri.parse(_githubApiUrl),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'PureSIP-Purchasing',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tagName = data['tag_name']?.toString() ?? '';

        if (tagName.startsWith('v')) {
          _latestVersion = tagName.substring(1);
        } else {
          _latestVersion = tagName;
        }

        // ✅ جلب رابط التحميل الصحيح
        final assets = data['assets'] as List? ?? [];
        for (final asset in assets) {
          final name = asset['name']?.toString() ?? '';
          if (name.endsWith('.apk')) {
            _downloadUrl = asset['browser_download_url']?.toString() ?? '';
            safeDebugPrint('📥 Found APK: $name');
            break;
          }
        }

        // ✅ إذا لم نجد APK، نستخدم رابط التحميل المباشر
        if (_downloadUrl.isEmpty) {
          _downloadUrl = 
              'https://github.com/ahmedtharwat19/supplyChain/releases/download/$tagName/app-release.apk';
          safeDebugPrint('📥 Using direct download URL: $_downloadUrl');
        }

        final body = data['body']?.toString() ?? '';
        _forceUpdateMessage = _extractForceUpdateMessage(body);
        _minVersion = _extractMinVersion(body) ?? _latestVersion;

        _isInitialized = true;
        safeDebugPrint('✅ Latest version: $_latestVersion');
        safeDebugPrint('✅ Download URL: $_downloadUrl');
      } else {
        safeDebugPrint('⚠️ Failed to fetch version: ${response.statusCode}');
        _useFallbackVersions();
      }
    } catch (e) {
      safeDebugPrint('❌ Error fetching version: $e');
      _useFallbackVersions();
    }
  }

  static String _extractForceUpdateMessage(String body) {
    final regex = RegExp(r'\[FORCE_UPDATE\](.*?)(?=\[|$)',
        dotAll: true, caseSensitive: false);
    final match = regex.firstMatch(body);
    if (match != null) {
      return match.group(1)?.trim() ?? '';
    }
    return 'update_now_to_continue'.tr();
  }

  static String? _extractMinVersion(String body) {
    final regex = RegExp(r'\[MIN_VERSION\](.*?)(?=\[|$)',
        dotAll: true, caseSensitive: false);
    final match = regex.firstMatch(body);
    if (match != null) {
      return match.group(1)?.trim();
    }
    return null;
  }

  static void _useFallbackVersions() {
    _latestVersion = '1.8.5+6';
    _minVersion = '1.5.0+0';
    _downloadUrl =
        'https://github.com/ahmedtharwat19/supplyChain/releases/download/v1.8.5+6/app-release.apk';
    _forceUpdateMessage = 'update_now_to_continue'.tr();
    _isInitialized = true;
    safeDebugPrint('⚠️ Using fallback versions');
    safeDebugPrint('⚠️ Download URL: $_downloadUrl');
  }

  static String getLatestVersion() {
    return _latestVersion.isNotEmpty ? _latestVersion : '1.8.5+6';
  }

  static String getMinVersion() {
    return _minVersion.isNotEmpty ? _minVersion : '1.5.0+0';
  }

  static String getDownloadUrl() {
    if (_downloadUrl.isNotEmpty) {
      safeDebugPrint('📥 Returning download URL: $_downloadUrl');
      return _downloadUrl;
    }
    return 'https://github.com/ahmedtharwat19/supplyChain/releases/download/v1.8.5+6/app-release.apk';
  }

  static String getDownloadUrlAndroid() {
    return getDownloadUrl();
  }

  static String getDownloadUrlWindows() {
    return _downloadUrl.isNotEmpty
        ? _downloadUrl
        : 'https://github.com/ahmedtharwat19/supplyChain/releases/latest';
  }

  static String getForceUpdateMessage() {
    return _forceUpdateMessage.isNotEmpty
        ? _forceUpdateMessage
        : 'update_now_to_continue'.tr();
  }

  static Future<bool> isUpdateAvailable() async {
    if (!_isInitialized) {
      await fetchLatestVersion();
    }
    try {
      final currentVersion = await getCurrentVersion();
      return _isVersionLessThan(currentVersion, _latestVersion);
    } catch (e) {
      safeDebugPrint('⚠️ Error checking update: $e');
      return false;
    }
  }

  static Future<bool> isForceUpdateRequired() async {
    if (!_isInitialized) {
      await fetchLatestVersion();
    }
    try {
      final currentVersion = await getCurrentVersion();
      return _isVersionLessThan(currentVersion, _minVersion);
    } catch (e) {
      safeDebugPrint('⚠️ Error checking force update: $e');
      return false;
    }
  }

  static bool _isVersionLessThan(String current, String required) {
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

  static List<int> _parseVersionParts(String version) {
    final mainAndBuild = version.split('+');
    final mainParts = mainAndBuild[0].split('.');
    final build = mainAndBuild.length > 1
        ? int.tryParse(mainAndBuild[1]) ?? 0
        : 0;

    int part(int index) =>
        index < mainParts.length ? (int.tryParse(mainParts[index]) ?? 0) : 0;

    return [part(0), part(1), part(2), build];
  }

  static Future<String> getCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.buildNumber.isNotEmpty
          ? '${info.version}+${info.buildNumber}'
          : info.version;
    } catch (e) {
      safeDebugPrint('⚠️ Error getting current version: $e');
      return '1.0.0';
    }
  }

  static String getUpdateMessage() {
    if (_latestVersion.isEmpty) {
      return 'update_available'.tr();
    }
    return '${'new_version_available'.tr()}: v$_latestVersion';
  }
}