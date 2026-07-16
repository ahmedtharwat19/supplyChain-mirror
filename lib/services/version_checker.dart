/* // lib/services/version_checker.dart
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

class VersionChecker {
  static final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;
  
  static const String _githubApiUrl =
      'https://api.github.com/repos/ahmedtharwat19/supplychain-releases/releases/latest';

  static String _latestVersion = '';
  static String _minVersion = '';
  static String _downloadUrl = '';
  static String _forceUpdateMessage = '';

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
      
      safeDebugPrint('📡 Remote Config raw values:');
      safeDebugPrint('  latest_version: "$remoteVersion"');
      safeDebugPrint('  minimum_version: "$remoteMinVersion"');
      safeDebugPrint('  download_url_android: "$remoteDownloadUrl"');
      
      if (remoteVersion.isNotEmpty && remoteDownloadUrl.isNotEmpty) {
        _latestVersion = remoteVersion;
        _minVersion = remoteMinVersion.isNotEmpty ? remoteMinVersion : remoteVersion;
        _downloadUrl = remoteDownloadUrl;
        _forceUpdateMessage = _remoteConfig.getString('force_update_message');
        
        safeDebugPrint('✅ Version from Remote Config: $_latestVersion');
        safeDebugPrint('✅ Min Version from Remote Config: $_minVersion');
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
        safeDebugPrint('📡 GitHub Tag: $tagName');

        if (tagName.isNotEmpty) {
          if (tagName.startsWith('v')) {
            _latestVersion = tagName.substring(1);
          } else {
            _latestVersion = tagName;
          }
        }

        // ✅ جلب رابط التحميل
        final assets = data['assets'] as List? ?? [];
        for (final asset in assets) {
          final name = asset['name']?.toString() ?? '';
          if (name.endsWith('.apk')) {
            _downloadUrl = asset['browser_download_url']?.toString() ?? '';
            safeDebugPrint('📥 Found APK: $name');
            break;
          }
        }

        if (_downloadUrl.isEmpty) {
          _downloadUrl = 
              'https://github.com/ahmedtharwat19/supplychain-releases/releases/download/$tagName/app-release.apk';
          safeDebugPrint('📥 Using direct download URL: $_downloadUrl');
        }

        final body = data['body']?.toString() ?? '';
        _forceUpdateMessage = _extractForceUpdateMessage(body);
        _minVersion = _extractMinVersion(body) ?? _latestVersion;

        safeDebugPrint('✅ Latest version: $_latestVersion');
        safeDebugPrint('✅ Min version: $_minVersion');
        safeDebugPrint('✅ Download URL: $_downloadUrl');
      } else {
        safeDebugPrint('⚠️ Failed to fetch version: ${response.statusCode}');
      }
    } catch (e) {
      safeDebugPrint('❌ Error fetching version: $e');
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

  static String getLatestVersion() {
    // ✅ محاولة من Remote Config أولاً
    final remoteVersion = _remoteConfig.getString('latest_version');
    if (remoteVersion.isNotEmpty) {
      return remoteVersion;
    }

    // ✅ ثم من القيمة المخزنة (يجب أن تكون اتحمّلت فعلاً عبر fetchLatestVersion المنتظرة بـ await)
    return _latestVersion;
  }

  /// ✅ true فقط إذا فعلاً نجحنا نجيب بيانات إصدار صالحة (من Remote Config أو GitHub)
  static bool get hasFetchedVersionData =>
      _latestVersion.isNotEmpty ||
      _remoteConfig.getString('latest_version').isNotEmpty;

  static String getMinVersion() {
    // ✅ محاولة من Remote Config أولاً
    final remoteMinVersion = _remoteConfig.getString('minimum_version');
    if (remoteMinVersion.isNotEmpty) {
      return remoteMinVersion;
    }
    
    // ✅ ثم من القيمة المخزنة
    if (_minVersion.isNotEmpty) {
      return _minVersion;
    }
    
    // ✅ في النهاية: استخدم latestVersion كقيمة افتراضية
    return getLatestVersion();
  }

  static String getDownloadUrl() {
    // ✅ محاولة من Remote Config أولاً
    final remoteUrl = _remoteConfig.getString('download_url_android');
    if (remoteUrl.isNotEmpty) {
      return remoteUrl;
    }
    
    // ✅ ثم من القيمة المخزنة
    if (_downloadUrl.isNotEmpty) {
      return _downloadUrl;
    }
    
    // ✅ في النهاية: إنشاء رابط من الإصدار الحالي
    final version = getLatestVersion();
    return 'https://github.com/ahmedtharwat19/supplychain-releases/releases/download/v$version/app-release.apk';
  }

  static String getDownloadUrlAndroid() {
    return getDownloadUrl();
  }

  static String getDownloadUrlWindows() {
    final url = getDownloadUrl();
    return url.isNotEmpty ? url : 'https://github.com/ahmedtharwat19/supplychain-releases/releases/latest';
  }

  static String getForceUpdateMessage() {
    // ✅ محاولة من Remote Config أولاً
    final remoteMsg = _remoteConfig.getString('force_update_message');
    if (remoteMsg.isNotEmpty) {
      return remoteMsg;
    }
    
    // ✅ ثم من القيمة المخزنة
    if (_forceUpdateMessage.isNotEmpty) {
      return _forceUpdateMessage;
    }
    
    return 'update_now_to_continue'.tr();
  }

  static Future<bool> isUpdateAvailable() async {
    try {
      final currentVersion = await getCurrentVersion();

      if (!hasFetchedVersionData) {
        await fetchLatestVersion();
      }

      final result = _isVersionLessThan(currentVersion, getLatestVersion());
      safeDebugPrint('📊 isUpdateAvailable: $currentVersion < ${getLatestVersion()} = $result');
      return result;
    } catch (e) {
      safeDebugPrint('⚠️ Error checking update: $e');
      return false;
    }
  }

  static Future<bool> isForceUpdateRequired() async {
    try {
      final currentVersion = await getCurrentVersion();

      if (!hasFetchedVersionData) {
        await fetchLatestVersion();
      }

      final result = _isVersionLessThan(currentVersion, getMinVersion());
      safeDebugPrint('📊 isForceUpdateRequired: $currentVersion < ${getMinVersion()} = $result');
      return result;
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
    final latest = getLatestVersion();
    if (latest.isEmpty) {
      return 'update_available'.tr();
    }
    return '${'new_version_available'.tr()}: v$latest';
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
      'https://api.github.com/repos/ahmedtharwat19/supplychain-releases/releases/latest';

  static String _latestVersion = '';
  static String _minVersion = '';
  static String _downloadUrl = '';
  static String _forceUpdateMessage = '';
  
  // ✅ متغير لتتبع ما إذا تم التهيئة بنجاح
  static bool _isInitialized = false;

  /// ✅ تهيئة Remote Config وجلب الإصدارات
  static Future<void> init() async {
    if (_isInitialized) {
      safeDebugPrint('✅ VersionChecker already initialized');
       await fetchLatestVersion();
      return;
    }
    
    safeDebugPrint('🔄 VersionChecker - Starting initialization...');
    
    // ✅ تهيئة Remote Config
    try {
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );
      
      // ✅ جلب البيانات من Remote Config
      await _remoteConfig.fetchAndActivate();
      
      // ✅ قراءة جميع القيم من Remote Config
      final allKeys = _remoteConfig.getAll();
      safeDebugPrint('📡 Remote Config keys: ${allKeys.keys}');
      
      for (final key in allKeys.keys) {
        final value = _remoteConfig.getString(key);
        safeDebugPrint('  📡 $key = "$value"');
      }
      
      safeDebugPrint('✅ Remote Config initialized');
    } catch (e) {
      safeDebugPrint('❌ Remote Config error: $e');
    }
    
    // ✅ جلب الإصدارات
    await fetchLatestVersion();
    _isInitialized = true;
    safeDebugPrint('✅ VersionChecker initialization complete');
  }

  /// جلب أحدث إصدار من GitHub أو Remote Config
  static Future<void> fetchLatestVersion() async {
    safeDebugPrint('📡 fetchLatestVersion - Starting...');
    
    try {
      // ✅ أولاً: محاولة جلب من Remote Config
      final remoteVersion = _remoteConfig.getString('latest_version');
      final remoteMinVersion = _remoteConfig.getString('minimum_version');
      final remoteDownloadUrl = _remoteConfig.getString('download_url_android');
      
      safeDebugPrint('📡 Remote Config raw values:');
      safeDebugPrint('  latest_version: "$remoteVersion"');
      safeDebugPrint('  minimum_version: "$remoteMinVersion"');
      safeDebugPrint('  download_url_android: "$remoteDownloadUrl"');
      
      // ✅ التحقق من أن القيم غير فارغة
      if (remoteVersion.isNotEmpty) {
        _latestVersion = remoteVersion;
        _minVersion = remoteMinVersion.isNotEmpty ? remoteMinVersion : remoteVersion;
        _downloadUrl = remoteDownloadUrl.isNotEmpty ? remoteDownloadUrl : _downloadUrl;
        _forceUpdateMessage = _remoteConfig.getString('force_update_message');
        
        safeDebugPrint('✅ Version from Remote Config: $_latestVersion');
        safeDebugPrint('✅ Min Version from Remote Config: $_minVersion');
        safeDebugPrint('✅ Download URL from Remote Config: $_downloadUrl');
        return;
      } else {
        safeDebugPrint('⚠️ Remote Config latest_version is empty, trying GitHub...');
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
        safeDebugPrint('📡 GitHub Tag: $tagName');

        if (tagName.isNotEmpty) {
          if (tagName.startsWith('v')) {
            _latestVersion = tagName.substring(1);
          } else {
            _latestVersion = tagName;
          }
        }

        // ✅ جلب رابط التحميل
        final assets = data['assets'] as List? ?? [];
        for (final asset in assets) {
          final name = asset['name']?.toString() ?? '';
          if (name.endsWith('.apk')) {
            _downloadUrl = asset['browser_download_url']?.toString() ?? '';
            safeDebugPrint('📥 Found APK: $name');
            break;
          }
        }

        if (_downloadUrl.isEmpty) {
          // ✅ استخدام الاسم الصحيح للملف في Fallback
          final cleanVersion = _latestVersion.replaceAll('+', '-');
          _downloadUrl = 
              'https://github.com/ahmedtharwat19/supplychain-releases/releases/download/v$_latestVersion/PureSip_Purchasing_v$cleanVersion.apk';
          safeDebugPrint('📥 Using fallback download URL: $_downloadUrl');
        }

        final body = data['body']?.toString() ?? '';
        _forceUpdateMessage = _extractForceUpdateMessage(body);
        _minVersion = _extractMinVersion(body) ?? _latestVersion;

        safeDebugPrint('✅ Latest version: $_latestVersion');
        safeDebugPrint('✅ Min version: $_minVersion');
        safeDebugPrint('✅ Download URL: $_downloadUrl');
      } else {
        safeDebugPrint('⚠️ Failed to fetch version: ${response.statusCode}');
        safeDebugPrint('⚠️ Response body: ${response.body}');
      }
    } catch (e) {
      safeDebugPrint('❌ Error fetching version: $e');
    }
    
    safeDebugPrint('📡 fetchLatestVersion - Finished. _latestVersion = "$_latestVersion"');
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

  static String getLatestVersion() {
    // ✅ محاولة من Remote Config أولاً
    final remoteVersion = _remoteConfig.getString('latest_version');
    safeDebugPrint('📡 getLatestVersion - Remote Config: "$remoteVersion"');
    
    if (remoteVersion.isNotEmpty) {
      return remoteVersion;
    }

    // ✅ ثم من القيمة المخزنة
    safeDebugPrint('📡 getLatestVersion - Cached: "$_latestVersion"');
    return _latestVersion;
  }

  static bool get hasFetchedVersionData {
    final remoteVersion = _remoteConfig.getString('latest_version');
    final hasData = _latestVersion.isNotEmpty || remoteVersion.isNotEmpty;
    safeDebugPrint('📡 hasFetchedVersionData: $hasData (_latestVersion: "$_latestVersion", remoteVersion: "$remoteVersion")');
    return hasData;
  }

  static String getMinVersion() {
    // ✅ محاولة من Remote Config أولاً
    final remoteMinVersion = _remoteConfig.getString('minimum_version');
    if (remoteMinVersion.isNotEmpty) {
      safeDebugPrint('📡 getMinVersion - Remote Config: "$remoteMinVersion"');
      return remoteMinVersion;
    }
    
    // ✅ ثم من القيمة المخزنة
    if (_minVersion.isNotEmpty) {
      return _minVersion;
    }
    
    // ✅ في النهاية: استخدم latestVersion كقيمة افتراضية
    return getLatestVersion();
  }

  static String getDownloadUrl() {
    // ✅ محاولة من Remote Config أولاً
    final remoteUrl = _remoteConfig.getString('download_url_android');
    if (remoteUrl.isNotEmpty) {
      safeDebugPrint('📡 getDownloadUrl - Remote Config: "$remoteUrl"');
      return remoteUrl;
    }
    
    // ✅ ثم من القيمة المخزنة
    if (_downloadUrl.isNotEmpty) {
      safeDebugPrint('📡 getDownloadUrl - Cached: "$_downloadUrl"');
      return _downloadUrl;
    }
    
    // ✅ في النهاية: إنشاء رابط من الإصدار الحالي مع الاسم الصحيح
    final version = getLatestVersion();
    if (version.isEmpty) {
      safeDebugPrint('⚠️ No version available, returning empty URL');
      return '';
    }
    
    // ✅ استخدام اسم الملف الصحيح
    final cleanVersion = version.replaceAll('+', '-');
    final url = 'https://github.com/ahmedtharwat19/supplychain-releases/releases/download/v$version/PureSip_Purchasing_v$cleanVersion.apk';
    safeDebugPrint('📡 getDownloadUrl - Fallback URL: "$url"');
    return url;
  }

  static String getDownloadUrlAndroid() {
    return getDownloadUrl();
  }

  static String getDownloadUrlWindows() {
    final url = getDownloadUrl();
    return url.isNotEmpty ? url : 'https://github.com/ahmedtharwat19/supplychain-releases/releases/latest';
  }

  static String getForceUpdateMessage() {
    // ✅ محاولة من Remote Config أولاً
    final remoteMsg = _remoteConfig.getString('force_update_message');
    if (remoteMsg.isNotEmpty) {
      return remoteMsg;
    }
    
    // ✅ ثم من القيمة المخزنة
    if (_forceUpdateMessage.isNotEmpty) {
      return _forceUpdateMessage;
    }
    
    return 'update_now_to_continue'.tr();
  }

  static Future<bool> isUpdateAvailable() async {
    try {
      final currentVersion = await getCurrentVersion();
      safeDebugPrint('📊 isUpdateAvailable - Current version: "$currentVersion"');

      if (!hasFetchedVersionData) {
        safeDebugPrint('📊 No version data, fetching...');
        await fetchLatestVersion();
      }

      final latest = getLatestVersion();
      final result = _isVersionLessThan(currentVersion, latest);
      safeDebugPrint('📊 isUpdateAvailable: $currentVersion < $latest = $result');
      return result;
    } catch (e) {
      safeDebugPrint('⚠️ Error checking update: $e');
      return false;
    }
  }

  static Future<bool> isForceUpdateRequired() async {
    try {
      final currentVersion = await getCurrentVersion();
      safeDebugPrint('📊 isForceUpdateRequired - Current version: "$currentVersion"');

      if (!hasFetchedVersionData) {
        safeDebugPrint('📊 No version data, fetching...');
        await fetchLatestVersion();
      }

      final minVersion = getMinVersion();
      final result = _isVersionLessThan(currentVersion, minVersion);
      safeDebugPrint('📊 isForceUpdateRequired: $currentVersion < $minVersion = $result');
      return result;
    } catch (e) {
      safeDebugPrint('⚠️ Error checking force update: $e');
      return false;
    }
  }

  static bool _isVersionLessThan(String current, String required) {
    safeDebugPrint('📊 _isVersionLessThan: comparing "$current" < "$required"');
    
    if (required.isEmpty) {
      safeDebugPrint('📊 required is empty, returning false');
      return false;
    }
    
    try {
      final currentParts = _parseVersionParts(current);
      final requiredParts = _parseVersionParts(required);
      
      safeDebugPrint('📊 Current parts: $currentParts');
      safeDebugPrint('📊 Required parts: $requiredParts');

      for (var i = 0; i < 4; i++) {
        if (currentParts[i] != requiredParts[i]) {
          final result = currentParts[i] < requiredParts[i];
          safeDebugPrint('📊 At position $i: ${currentParts[i]} < ${requiredParts[i]} = $result');
          return result;
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
      final version = info.buildNumber.isNotEmpty
          ? '${info.version}+${info.buildNumber}'
          : info.version;
      safeDebugPrint('📱 getCurrentVersion: "$version"');
      return version;
    } catch (e) {
      safeDebugPrint('⚠️ Error getting current version: $e');
      return '1.0.0';
    }
  }

  static String getUpdateMessage() {
    final latest = getLatestVersion();
    if (latest.isEmpty) {
      return 'update_available'.tr();
    }
    return '${'new_version_available'.tr()}: v$latest';
  }
}