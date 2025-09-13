/* import 'dart:io';
import 'package:universal_io/io.dart' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class DeviceFingerprint {

    static final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

  static Future<Map<String, String>> getDeviceInfo() async {
    try {
      final Map<String, String> info = {};
      
      if (io.Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        info['deviceName'] = 'Android Device';
        info['platform'] = 'Android';
        info['model'] = androidInfo.model;
        info['os'] = 'Android ${androidInfo.version.release}';
        info['browser'] = 'N/A';
      } 
      else if (io.Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        info['deviceName'] = 'iOS Device';
        info['platform'] = 'iOS';
        info['model'] = iosInfo.model;
        info['os'] = 'iOS ${iosInfo.systemVersion}';
        info['browser'] = 'N/A';
      }
      else if (io.Platform.isWindows) {
        info['deviceName'] = 'Windows PC';
        info['platform'] = 'Windows';
        info['model'] = 'Windows Device';
        info['os'] = 'Windows';
        info['browser'] = _getBrowserInfo();
      }
      else if (io.Platform.isMacOS) {
        info['deviceName'] = 'Mac Computer';
        info['platform'] = 'macOS';
        info['model'] = 'Mac Device';
        info['os'] = 'macOS';
        info['browser'] = _getBrowserInfo();
      }
      else if (io.Platform.isLinux) {
        info['deviceName'] = 'Linux Computer';
        info['platform'] = 'Linux';
        info['model'] = 'Linux Device';
        info['os'] = 'Linux';
        info['browser'] = _getBrowserInfo();
      }
      else {
        info['deviceName'] = 'Unknown Device';
        info['platform'] = 'Unknown';
        info['model'] = 'Unknown';
        info['os'] = 'Unknown';
        info['browser'] = _getBrowserInfo();
      }

      return info;
    } catch (e) {
      return {
        'deviceName': 'Unknown Device',
        'platform': 'Unknown',
        'model': 'Unknown',
        'os': 'Unknown',
        'browser': 'Unknown',
      };
    }
  }

  static String _getBrowserInfo() {
    // يمكن إضافة كشف المتصفح هنا
    return 'Web Browser';
  }

  static Future<String> generate() async {
    String rawId = "";

    if (kIsWeb) {
      // للويب - استخدم معلومات المتصفح المتاحة
      rawId = _getWebFingerprint();
    } else {
      // للجوال والمنصات الأخرى
      rawId = await _getDeviceFingerprint();
    }

    // نحولها إلى بصمة ثابتة عبر SHA256
    final bytes = utf8.encode(rawId);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static Future<String> _getDeviceFingerprint() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      String rawId = "";

      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        rawId = "${info.id}-${info.manufacturer}-${info.model}-${info.hardware}";
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        rawId = "${info.identifierForVendor}-${info.name}-${info.systemName}";
      } else if (Platform.isWindows) {
        final info = await deviceInfo.windowsInfo;
        rawId = "${info.deviceId}-${info.computerName}";
      } else if (Platform.isLinux) {
        final info = await deviceInfo.linuxInfo;
        rawId = "${info.machineId}-${info.prettyName}";
      } else if (Platform.isMacOS) {
        final info = await deviceInfo.macOsInfo;
        rawId = "${info.systemGUID}-${info.computerName}";
      } else {
        rawId = DateTime.now().millisecondsSinceEpoch.toString();
      }

      return rawId;
    } catch (e) {
      // في حالة الخطأ، نرجع معرفًا فريدًا يعتمد على الوقت
      return "fallback-${DateTime.now().millisecondsSinceEpoch}";
    }
  }

  static String _getWebFingerprint() {
    try {
      // للويب - استخدم معلومات المتصفح المتاحة
      // ملاحظة: في الويب، بعض هذه الخصائص قد لا تكون متاحة في جميع المتصفحات
      final userAgent = _getUserAgent();
      final language = _getLanguage();
      final timezone = DateTime.now().timeZoneName;
      
      return "web-$userAgent-$language-$timezone-${DateTime.now().millisecondsSinceEpoch}";
    } catch (e) {
      return "web-fallback-${DateTime.now().millisecondsSinceEpoch}";
    }
  }

  static String _getUserAgent() {
    try {
      if (kIsWeb) {
        return _getWebUserAgent();
      }
      return "unknown-user-agent";
    } catch (e) {
      return "error-user-agent";
    }
  }

  static String _getLanguage() {
    try {
      if (kIsWeb) {
        return _getWebLanguage();
      }
      return "unknown-language";
    } catch (e) {
      return "error-language";
    }
  }

  // دوال مساعدة للويب (سيتم تعريفها بشكل منفصل للويب)
  static String _getWebUserAgent() {
    try {
      return 'web-user-agent'; // سيتم استبدالها في ملف منفصل للويب
    } catch (e) {
      return 'web-user-agent-fallback';
    }
  }

  static String _getWebLanguage() {
    try {
      return 'web-language'; // سيتم استبدالها في ملف منفصل للويب
    } catch (e) {
      return 'web-language-fallback';
    }
  }

  static Future<String> getFingerprint() => generate();
} */

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:universal_io/io.dart' as io;

class DeviceFingerprint {
  static final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

  static Future<Map<String, String>> getDeviceInfo() async {
    try {
      final Map<String, String> info = {};
      
      if (io.Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        info['deviceName'] = 'Android Device';
        info['platform'] = 'Android';
        info['model'] = androidInfo.model;
        info['os'] = 'Android ${androidInfo.version.release}';
        info['browser'] = 'N/A';
      } 
      else if (io.Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        info['deviceName'] = 'iOS Device';
        info['platform'] = 'iOS';
        info['model'] = iosInfo.model;
        info['os'] = 'iOS ${iosInfo.systemVersion}';
        info['browser'] = 'N/A';
      }
      else if (io.Platform.isWindows) {
        info['deviceName'] = 'Windows PC';
        info['platform'] = 'Windows';
        info['model'] = 'Windows Device';
        info['os'] = 'Windows';
        info['browser'] = _getBrowserInfo();
      }
      else if (io.Platform.isMacOS) {
        info['deviceName'] = 'Mac Computer';
        info['platform'] = 'macOS';
        info['model'] = 'Mac Device';
        info['os'] = 'macOS';
        info['browser'] = _getBrowserInfo();
      }
      else if (io.Platform.isLinux) {
        info['deviceName'] = 'Linux Computer';
        info['platform'] = 'Linux';
        info['model'] = 'Linux Device';
        info['os'] = 'Linux';
        info['browser'] = _getBrowserInfo();
      }
      else {
        info['deviceName'] = 'Unknown Device';
        info['platform'] = 'Unknown';
        info['model'] = 'Unknown';
        info['os'] = 'Unknown';
        info['browser'] = _getBrowserInfo();
      }

      return info;
    } catch (e) {
      return {
        'deviceName': 'Unknown Device',
        'platform': 'Unknown',
        'model': 'Unknown',
        'os': 'Unknown',
        'browser': 'Unknown',
      };
    }
  }

  static String _getBrowserInfo() {
    if (kIsWeb) {
      return _getWebBrowserInfo();
    }
    return 'App';
  }

  // دالة مكتملة للحصول على معلومات المتصفح في الويب
  static String _getWebBrowserInfo() {
    try {
      final userAgent = _getWebUserAgent();
      if (userAgent.contains('Chrome')) return 'Chrome';
      if (userAgent.contains('Firefox')) return 'Firefox';
      if (userAgent.contains('Safari') && !userAgent.contains('Chrome')) return 'Safari';
      if (userAgent.contains('Edge')) return 'Edge';
      if (userAgent.contains('Opera')) return 'Opera';
      return 'Unknown Browser';
    } catch (e) {
      return 'Unknown Browser';
    }
  }

  static Future<String> generate() async {
    String rawId = "";

    if (kIsWeb) {
      rawId = _getWebFingerprint();
    } else {
      rawId = await _getDeviceFingerprint();
    }

    final bytes = utf8.encode(rawId);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static Future<String> _getDeviceFingerprint() async {
    try {
      String rawId = "";

      if (io.Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        rawId = "${info.id}-${info.manufacturer}-${info.model}-${info.hardware}";
      } else if (io.Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        rawId = "${info.identifierForVendor}-${info.name}-${info.systemName}";
      } else if (io.Platform.isWindows) {
        final info = await deviceInfo.windowsInfo;
        rawId = "${info.deviceId}-${info.computerName}";
      } else if (io.Platform.isLinux) {
        final info = await deviceInfo.linuxInfo;
        rawId = "${info.machineId}-${info.prettyName}";
      } else if (io.Platform.isMacOS) {
        final info = await deviceInfo.macOsInfo;
        rawId = "${info.systemGUID}-${info.computerName}";
      } else {
        rawId = DateTime.now().millisecondsSinceEpoch.toString();
      }

      return rawId;
    } catch (e) {
      return "fallback-${DateTime.now().millisecondsSinceEpoch}";
    }
  }

  static String _getWebFingerprint() {
    try {
      final userAgent = _getWebUserAgent();
      final language = _getWebLanguage();
      final timezone = DateTime.now().timeZoneName;
      final screen = _getWebScreenInfo();
      
      return "web-$userAgent-$language-$timezone-$screen-${DateTime.now().millisecondsSinceEpoch}";
    } catch (e) {
      return "web-fallback-${DateTime.now().millisecondsSinceEpoch}";
    }
  }

  // ======= دوال الويب المكتملة =======

  static String _getWebUserAgent() {
    try {
      if (kIsWeb) {
        // للويب - استخدام dart:js أو window.navigator.userAgent
        return _getUserAgentFromJS();
      }
      return "unknown-user-agent";
    } catch (e) {
      return "error-user-agent";
    }
  }

  static String _getWebLanguage() {
    try {
      if (kIsWeb) {
        // للويب - استخدام dart:js أو window.navigator.language
        return _getLanguageFromJS();
      }
      return "unknown-language";
    } catch (e) {
      return "error-language";
    }
  }

  static String _getWebScreenInfo() {
    try {
      if (kIsWeb) {
        // للويب - معلومات الشاشة
        return _getScreenInfoFromJS();
      }
      return "unknown-screen";
    } catch (e) {
      return "error-screen";
    }
  }

  // ======= التطبيقات الفعلية للدوال (سيتم تعريفها في ملف منفصل) =======

  static String _getUserAgentFromJS() {
    // سيتم تنفيذ هذا في ملف منفصل للويب
    return 'web-user-agent-placeholder';
  }

  static String _getLanguageFromJS() {
    // سيتم تنفيذ هذا في ملف منفصل للويب
    return 'web-language-placeholder';
  }

  static String _getScreenInfoFromJS() {
    // سيتم تنفيذ هذا في ملف منفصل للويب
    return 'web-screen-placeholder';
  }

  static Future<String> getFingerprint() => generate();
}