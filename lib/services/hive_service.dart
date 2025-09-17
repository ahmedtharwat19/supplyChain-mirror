// services/hive_service.dart
import 'package:hive/hive.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_page.dart';

class HiveService {
  // أسماء الصناديق
  static const String _licenseBox = "licenseBox";
  static const String _authBox = "authBox";
  static const String _userBox = "userBox";
  static const String _settingsBox = "settingsBox";
  static const String _cacheBox = "cacheBox";

  // مفاتيح التخزين
  static const String _keyLicense = "licenseKey";
  static const String _keyUser = "userData";
  static const String _keyAuth = "authData";

  // صناديق Hive المفتوحة
  static Box? _licenseHive;
  static Box? _authHive;
  static Box? _userHive;
  static Box? _settingsHive;
  static Box? _cacheHive;

  // Singleton (إن أردت استعمال نسخة كائن أيضاً متاح)
  static final HiveService _instance = HiveService._internal();

  factory HiveService() {
    return _instance;
  }

  HiveService._internal();

  // ══════════════ Initialization ══════════════
  /// يجب استدعاء هذه الدالة مرة واحدة عند بدء التطبيق (قبل استخدام أي دوال)
  static Future<void> init() async {
    try {
      _licenseHive = await Hive.openBox(_licenseBox);
      _authHive = await Hive.openBox(_authBox);
      _userHive = await Hive.openBox(_userBox);
      _settingsHive = await Hive.openBox(_settingsBox);
      _cacheHive = await Hive.openBox(_cacheBox);
      safeDebugPrint('✅ All Hive boxes initialized successfully');
    } catch (e) {
      safeDebugPrint('❌ Hive initialization error: $e');
    }
  }

  // ══════════════ Card Count (عدد الكروت) Methods ══════════════
  /// حفظ عدد الكروت في صندوق الإعدادات
  static Future<void> saveCardCount(int count) async {
    await _settingsHive?.put('cardCount', count);
    safeDebugPrint('💾 Saved card count: $count');
  }

  /// قراءة عدد الكروت من صندوق الإعدادات
  static Future<int?> getCardCount() async {
    try {
      final raw = _settingsHive?.get('cardCount');
      if (raw == null) return null;
      if (raw is int) return raw;
      // حاول تحويل القيمة إن كانت مخزنة كنص
      if (raw is String) {
        return int.tryParse(raw);
      }
      return null;
    } catch (e) {
      safeDebugPrint('❌ Error getting card count: $e');
      return null;
    }
  }

  static Future<void> saveCardLayout(List<String> cardLayout) async {
    await _settingsHive?.put('card_layout', cardLayout);
    safeDebugPrint('💾 Saved card layout: $cardLayout');
  }

  static Future<List<String>> getCardLayout() async {
    try {
      final layout = _settingsHive?.get('card_layout');
      if (layout is List<dynamic>) {
        final stringLayout = layout.whereType<String>().toList();
        safeDebugPrint('🔍 Retrieved card layout from Hive: $stringLayout');
        return stringLayout;
      }
      safeDebugPrint('🔍 No card layout found in Hive, returning empty list');
      return [];
    } catch (e) {
      safeDebugPrint('❌ Error getting card layout: $e');
      return [];
    }
  }

  // ══════════════ License Methods ══════════════
  static Future<void> saveLicense(String license) async {
    await _licenseHive?.put(_keyLicense, license);
  }

  static Future<String?> getLicense() async {
    return _licenseHive?.get(_keyLicense) as String?;
  }

  static Future<void> clearLicense() async {
    await _licenseHive?.delete(_keyLicense);
  }

  // ══════════════ Authentication Methods ══════════════
  static Future<void> saveAuthData(Map<String, dynamic> data) async {
    await _authHive?.put(_keyAuth, data);
  }

  static Future<Map<String, dynamic>?> getAuthData() async {
    final raw = _authHive?.get(_keyAuth);
    if (raw == null) return null;
    if (raw is Map) {
      try {
        return Map<String, dynamic>.from(raw);
      } catch (e) {
        safeDebugPrint('❌ Error casting auth data: $e');
      }
    }
    return null;
  }

  static Future<bool> hasAuthData() async {
    return _authHive?.containsKey(_keyAuth) ?? false;
  }

  static Future<void> clearAuthData() async {
    await _authHive?.delete(_keyAuth);
  }

  // ══════════════ User Data Methods ══════════════
  static Future<void> saveUserData(Map<String, dynamic> userData) async {
    await _userHive?.put(_keyUser, userData);
  }

  static Future<Map<String, dynamic>?> getUserData() async {
    final raw = _userHive?.get(_keyUser);
    if (raw == null) return null;
    if (raw is Map) {
      try {
        return Map<String, dynamic>.from(raw);
      } catch (e) {
        safeDebugPrint('❌ Error casting user data: $e');
      }
    }
    return null;
  }

  static Future<void> updateUserData(String key, dynamic value) async {
    final currentData = await getUserData() ?? {};
    currentData[key] = value;
    await _userHive?.put(_keyUser, currentData);
  }

  static Future<void> clearUserData() async {
    await _userHive?.delete(_keyUser);
  }

  // ══════════════ Settings Methods ══════════════
  static Future<void> saveSetting(String key, dynamic value) async {
    await _settingsHive?.put(key, value);
  }

  static Future<T?> getSetting<T>(String key, {T? defaultValue}) async {
    final value = _settingsHive?.get(key);
    if (value == null) return defaultValue;
    try {
      return value as T;
    } catch (e) {
      safeDebugPrint('❌ Error casting setting $key: $e');
      return defaultValue;
    }
  }

  static Future<void> clearSettings() async {
    await _settingsHive?.clear();
  }

  // ══════════════ Cache Methods ══════════════
  static Future<void> cacheData(String key, dynamic data,
      {Duration? expiry}) async {
    final cacheItem = {
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'expiry': expiry?.inMilliseconds
    };
    await _cacheHive?.put(key, cacheItem);
  }

  static Future<dynamic> getCachedData(String key) async {
    final cacheItem = _cacheHive?.get(key);

    if (cacheItem == null) return null;

    final timestamp = cacheItem['timestamp'];
    final expiry = cacheItem['expiry'];

    if (expiry != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - timestamp > expiry) {
        await _cacheHive?.delete(key);
        return null;
      }
    }

    return cacheItem['data'];
  }

  static Future<void> clearCache() async {
    await _cacheHive?.clear();
  }

  // ══════════════ Dashboard Settings Methods ══════════════
  static Future<void> saveDashboardView(DashboardView view) async {
    final viewString = view == DashboardView.long ? 'long' : 'short';
    await _settingsHive?.put('dashboard_view', viewString);
    safeDebugPrint('💾 Saved dashboard view: $viewString');
  }

  /* static Future<DashboardView> getDashboardView() async {
    try {
      final viewString = _settingsHive?.get('dashboard_view');
      safeDebugPrint('🔍 Retrieved dashboard view from Hive: $viewString');

      if (viewString == 'long') {
        return DashboardView.long;
      }
      // القيمة الافتراضية هي short
      return DashboardView.short;
    } catch (e) {
      safeDebugPrint('❌ Error getting dashboard view: $e');
      return DashboardView.short;
    }
  } */

// في HiveService.dart
  static Future<DashboardView> getDashboardView() async {
    try {
      final viewString = await getSetting<String>('dashboard_view');
      safeDebugPrint('🔍 Raw dashboard_view from Hive: $viewString');

      if (viewString == 'long') {
        return DashboardView.long;
      } else if (viewString == 'short') {
        return DashboardView.short;
      } else if (viewString == 'DashboardView.long') {
        return DashboardView.long;
      } else if (viewString == 'DashboardView.short') {
        return DashboardView.short;
      }

      // القيمة الافتراضية
      return DashboardView.short;
    } catch (e) {
      safeDebugPrint('❌ Error getting dashboard view: $e');
      return DashboardView.short;
    }
  }

  static Future<Set<String>> getSelectedCards() async {
    try {
      final cards = await getSetting<List<dynamic>>('selected_cards');
      if (cards != null) {
        final cardSet = cards.map((e) => e.toString()).toSet();
        safeDebugPrint('🔍 Raw selected_cards from Hive: $cardSet');
        return cardSet;
      }
      safeDebugPrint('🔍 No selected cards found in Hive');
      return {};
    } catch (e) {
      safeDebugPrint('❌ Error getting selected cards: $e');
      return {};
    }
  }

  // ══════════════ Selected Cards Methods ══════════════

  static Future<void> saveSelectedCards(Set<String> selectedCards) async {
    await _settingsHive?.put('selected_cards', selectedCards.toList());
    safeDebugPrint('💾 Saved selected cards: ${selectedCards.toList()}');
  }

  // ══════════════ Storage Stats & Maintenance ══════════════
  static Future<Map<String, int>> getStorageStats() async {
    try {
      // هذه دالة افتراضية - يمكنك تطويرها لتحسب الأحجام الفعلية
      return {
        'cache': await _getBoxSize(_cacheHive),
        'auth': await _getBoxSize(_authHive),
        'user': await _getBoxSize(_userHive),
        'settings': await _getBoxSize(_settingsHive),
        'license': await _getBoxSize(_licenseHive),
      };
    } catch (e) {
      safeDebugPrint('Error getting storage stats: $e');
      return {};
    }
  }

  static Future<int> _getBoxSize(Box? box) async {
    if (box == null) return 0;
    // هذه دالة مبسطة - في الواقع تحتاج إلى حساب الحجم الفعلي
    return box.length * 100; // تقدير مبسط
  }

  static Future<void> compactDatabase() async {
    try {
      await _cacheHive?.compact();
      await _authHive?.compact();
      await _userHive?.compact();
      await _settingsHive?.compact();
      await _licenseHive?.compact();
      safeDebugPrint('✅ Database compacted successfully');
    } catch (e) {
      safeDebugPrint('❌ Error compacting database: $e');
    }
  }

  // ══════════════ Utility Methods ══════════════
  static Future<void> clearAllData() async {
    await clearLicense();
    await clearAuthData();
    await clearUserData();
    await clearSettings();
    await clearCache();
    safeDebugPrint('✅ All Hive data cleared successfully');
  }

  static Future<void> close() async {
    await Hive.close();
  }

  // ══════════════ Migration from SharedPreferences ══════════════
  static Future<void> migrateFromSharedPreferences() async {
    safeDebugPrint('🔄 SharedPreferences migration available if needed');
  }

  // ══════════════ Dashboard & Stats Cache ══════════════
  static Future<void> saveDashboardData(Map<String, dynamic> data) async {
    await cacheData('dashboard_data', data);
  }

  static Future<Map<String, dynamic>> getDashboardData() async {
    final raw = await getCachedData('dashboard_data');
    if (raw == null) return {};
    if (raw is Map) {
      try {
        return Map<String, dynamic>.from(raw);
      } catch (e) {
        safeDebugPrint('❌ Error casting dashboard data: $e');
      }
    }
    return {};
  }

  static Future<void> saveExtendedStats(Map<String, dynamic> stats) async {
    await cacheData('extended_stats', stats);
  }

  static Future<Map<String, dynamic>> getExtendedStats() async {
    final raw = await getCachedData('extended_stats');
    if (raw == null) return {};
    if (raw is Map) {
      try {
        return Map<String, dynamic>.from(raw);
      } catch (e) {
        safeDebugPrint('❌ Error casting extended stats: $e');
      }
    }
    return {};
  }
}
