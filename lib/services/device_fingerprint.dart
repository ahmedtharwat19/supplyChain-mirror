import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:universal_html/html.dart' as html;

class DeviceFingerprint {
  static final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  static String? _cachedFingerprint;

  static Future<Map<String, String>> getDeviceInfo() async {
    try {
      final Map<String, String> info = {};

      if (io.Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        info['platform']       = 'Android';
        info['brand']          = androidInfo.brand;
        info['model']          = androidInfo.model;
        info['manufacturer']   = androidInfo.manufacturer;
        info['androidVersion'] = androidInfo.version.release;
        info['buildId']        = androidInfo.id;
        info['deviceName']     = '${androidInfo.manufacturer} ${androidInfo.model}';
        info['os']             = 'Android ${androidInfo.version.release}';
        info['browser']        = 'N/A';
      } else if (io.Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        info['platform']       = 'iOS';
        info['brand']          = 'Apple';
        info['model']          = iosInfo.model;
        info['manufacturer']   = 'Apple';
        info['androidVersion'] = '';
        info['buildId']        = iosInfo.identifierForVendor ?? '';
        info['deviceName']     = iosInfo.name;
        info['os']             = 'iOS \${iosInfo.systemVersion}';
        info['browser']        = 'N/A';
      } else if (io.Platform.isWindows) {
        final winInfo = await deviceInfo.windowsInfo;
        info['platform']       = 'Windows';
        info['brand']          = 'Windows';
        info['model']          = winInfo.computerName;
        info['manufacturer']   = 'Microsoft';
        info['androidVersion'] = '';
        info['buildId']        = winInfo.deviceId;
        info['deviceName']     = winInfo.computerName;
        info['os']             = 'Windows';
        info['browser']        = _getBrowserInfo();
      } else if (io.Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        info['platform']       = 'macOS';
        info['brand']          = 'Apple';
        info['model']          = macInfo.model;
        info['manufacturer']   = 'Apple';
        info['androidVersion'] = '';
        info['buildId']        = macInfo.systemGUID ?? '';
        info['deviceName']     = macInfo.computerName;
        info['os']             = 'macOS \${macInfo.osRelease}';
        info['browser']        = _getBrowserInfo();
      } else if (io.Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        info['platform']       = 'Linux';
        info['brand']          = 'Linux';
        info['model']          = linuxInfo.prettyName;
        info['manufacturer']   = 'Linux';
        info['androidVersion'] = '';
        info['buildId']        = linuxInfo.machineId ?? '';
        info['deviceName']     = linuxInfo.prettyName;
        info['os']             = linuxInfo.prettyName;
        info['browser']        = _getBrowserInfo();
      } else {
        info['platform']       = 'Unknown';
        info['brand']          = '';
        info['model']          = 'Unknown';
        info['manufacturer']   = '';
        info['androidVersion'] = '';
        info['buildId']        = '';
        info['deviceName']     = 'Unknown Device';
        info['os']             = 'Unknown';
        info['browser']        = _getBrowserInfo();
      }

      return info;
    } catch (e) {
      safeDebugPrint('getDeviceInfo error: $e');
      return {
        'platform':       'Unknown',
        'brand':          '',
        'model':          'Unknown',
        'manufacturer':   '',
        'androidVersion': '',
        'buildId':        '',
        'deviceName':     'Unknown Device',
        'os':             'Unknown',
        'browser':        'Unknown',
      };
    }
  }

  static String _getBrowserInfo() {
    if (kIsWeb) {
      return _getWebBrowserInfo();
    }
    return 'App';
  }


 static String _getWebBrowserInfo() {
  try {
    final userAgent = _getWebUserAgent();

    if (userAgent.contains('Chrome') && !userAgent.contains('Edg/') && !userAgent.contains('OPR/')) {
      return 'Chrome';
    }
    if (userAgent.contains('Firefox')) return 'Firefox';
    if (userAgent.contains('Safari') && !userAgent.contains('Chrome')) return 'Safari';
    if (userAgent.contains('Edg/')) return 'Edge'; // Microsoft Edge
    if (userAgent.contains('OPR/') || userAgent.contains('Opera')) return 'Opera';

    return 'Unknown Browser';
  } catch (e) {
    return 'Unknown Browser';
  }
}


  static Future<String> generate() async {
    // ✅ إرجاع البصمة المخزنة إذا كانت موجودة
    if (_cachedFingerprint != null) {
      safeDebugPrint('🔍 Using cached fingerprint: $_cachedFingerprint');
      return _cachedFingerprint!;
    }

    String rawId = "";

    if (kIsWeb) {
      rawId = await _getWebFingerprint();
    } else {
      rawId = await _getDeviceFingerprint();
    }

    final bytes = utf8.encode(rawId);
    final digest = sha256.convert(bytes);

    _cachedFingerprint = digest.toString();

    safeDebugPrint('🔍 Generated new fingerprint: $_cachedFingerprint');
    safeDebugPrint('🔍 From raw data: $rawId');

    return _cachedFingerprint!;
  }
 
    static Future<String> _getDeviceFingerprint() async {
    try {
      String rawId = "";

      if (io.Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        
        // 1. جلب المعرف الأساسي وحمايته من الـ Null
        String id = info.id;
        if (id.isEmpty || id == 'null') {
          id = info.hardware.hashCode.toString();
        }
        
        // 2. جلب الشركة والموديل وتحويلهم لحروف كبيرة
        final String manufacturer = (info.manufacturer).toUpperCase().trim();
        final String model = (info.model).toUpperCase().trim();
        final String hardware = (info.hardware).toUpperCase().trim();
        
        // 3. الدمج الاحترافي ليكون مطابقاً 100% لنظام قراءة الأجهزة الجديد
        rawId = "$manufacturer-$model-$id-$hardware";
        
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
        rawId = "fallback-${io.Platform.operatingSystem}-${io.Platform.localHostname}";
      }

      return rawId;
    } catch (e) {
      safeDebugPrint('⚠️ Error building raw device info: $e');
      return "fallback-android-device-${DateTime.now().millisecondsSinceEpoch}";
    }
  }

  
  static Future<String> _getWebFingerprint() async {
    try {
      final userAgent = _getWebUserAgent();
      final language = _getWebLanguage();
      final timezone = DateTime.now().timeZoneName;
      final screen = _getWebScreenInfo();

      // ✅ إزالة الطابع الزمني لجعل البصمة ثابتة
      return "web-$userAgent-$language-$timezone-$screen";
    } catch (e) {
      // ✅ fallback ثابت للويب
      return "web-fallback-${_getWebUserAgent()}-${_getWebLanguage()}";
    }
  }

  // ✅ دوال الويب المحدثة
// استبدل دوال الويب بهذا الكود:

  static String _getWebUserAgent() {
    try {
      if (kIsWeb) {
        // محاولة الحصول على userAgent من المتصفح
        return _getRealUserAgent();
      }
      return "unknown-user-agent";
    } catch (e) {
      return "error-user-agent";
    }
  }

  static String _getWebLanguage() {
    try {
      if (kIsWeb) {
        // محاولة الحصول على اللغة من المتصفح
        return _getRealLanguage();
      }
      return "unknown-language";
    } catch (e) {
      return "error-language";
    }
  }

  static String _getWebScreenInfo() {
    try {
      if (kIsWeb) {
        // محاولة الحصول على معلومات الشاشة
        return _getRealScreenInfo();
      }
      return "unknown-screen";
    } catch (e) {
      return "error-screen";
    }
  }

// ✅ دوال حقيقية للويب
  static String _getRealUserAgent() {
    try {
      if (kIsWeb) {
        // طريقة بسيطة للحصول على userAgent
        return html.window.navigator.userAgent;
      }
      return 'non-web-user-agent';
    } catch (e) {
      return 'default-user-agent';
    }
  }

  static String _getRealLanguage() {
    try {
      if (kIsWeb) {
        return 'en-US'; // لغة افتراضية
      }
      return 'non-web-language';
    } catch (e) {
      return 'en';
    }
  }

  static String _getRealScreenInfo() {
    try {
      if (kIsWeb) {
        return '1920x1080-24bit';
      }
      return 'non-web-screen';
    } catch (e) {
      return '1024x768-24bit';
    }
  }

  // ✅ دالة لمسح الذاكرة المؤقتة
  static void clearCache() {
    _cachedFingerprint = null;
    safeDebugPrint('🔍 Cleared fingerprint cache');
  }

  // ✅ دالة للحصول على البصمة مع التأكد من الثبات
  static Future<String> getStableFingerprint() async {
    return await generate();
  }

  // ✅ دالة getFingerprint للتوافق مع الكود القديم
  static Future<String> getFingerprint() async {
    return await generate();
  }
}
