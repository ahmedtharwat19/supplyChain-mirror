// web_device_fingerprint.dart - للويب فقط

class WebDeviceFingerprint {

  
  static String _getUserAgentFromJS() {
    try {
      // استخدام طريقة آمنة للويب
      return 'web-user-agent-stable';
    } catch (e) {
      return 'unknown-user-agent';
    }
  }

  static String _getLanguageFromJS() {
    try {
      return 'web-language-stable';
    } catch (e) {
      return 'unknown-language';
    }
  }

  static String _getScreenInfoFromJS() {
    try {
      return '1920x1080-24bit'; // قيمة ثابتة للاختبار
    } catch (e) {
      return 'unknown-screen';
    }
  }

  static String _getPlatformFromJS() {
    try {
      return 'web-platform-stable';
    } catch (e) {
      return 'unknown-platform';
    }
  }

  // ✅ دالة واحدة تعيد جميع معلومات الويب
  static Map<String, String> getWebInfo() {
    return {
      'userAgent': _getUserAgentFromJS(),
      'language': _getLanguageFromJS(),
      'screen': _getScreenInfoFromJS(),
      'platform': _getPlatformFromJS(),
      'timezone': DateTime.now().timeZoneName,
    };
  }
}